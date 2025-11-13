import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/fitstreet_api.dart';
import '../../widgets/glass_card.dart';
import '../trainers/trainer_profile_screen.dart';

class NutritionScreen extends StatefulWidget {
	const NutritionScreen({super.key});

	@override
	State<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends State<NutritionScreen> {
	bool _loading = true;
	String? _error;
	final TextEditingController _searchCtrl = TextEditingController();

	// Full list (nutritionists only) and filtered by search
	List<Map<String, dynamic>> _nutritionists = [];

	// Cache of fetched specialization proofs per-trainer
	final Map<String, List<String>> _specCache = {};

	// Track which trainers have expanded specializations
	final Set<String> _expandedTrainers = {};

	@override
	void initState() {
		super.initState();
		_searchCtrl.addListener(() => setState(() {}));
		_load();
	}

	@override
	void dispose() {
		_searchCtrl.dispose();
		super.dispose();
	}

	String _norm(String s) => s
			.toLowerCase()
			.replaceAll(RegExp(r'[_\-]+'), ' ')
			.replaceAll(RegExp(r'[^a-z0-9 ]+'), '')
			.replaceAll(RegExp(r'\s+'), ' ')
			.trim();

	List<String> _parseSpecs(dynamic v) {
		if (v == null) return const [];
		if (v is String) {
			final s = v.trim();
			if (s.isEmpty) return const [];
			return s
					.split(',')
					.map((e) => e.trim())
					.where((e) => e.isNotEmpty)
					.toList();
		}
		if (v is List) {
			return v
					.map((e) => e.toString().trim())
					.where((e) => e.isNotEmpty && e.toLowerCase() != 'null')
					.toList();
		}
		return const [];
	}

	List<String> _extractSpecs(Map<String, dynamic> t) {
		final List<String> fromStr = <String>[]
			..addAll(_parseSpecs(t['specialization']))
			..addAll(_parseSpecs(t['speciality']))
			..addAll(_parseSpecs(t['specializations']))
			..addAll(_parseSpecs(t['specializationList']));
		if (fromStr.isNotEmpty) {
			final seen = <String>{};
			return fromStr.where((e) => seen.add(e.toLowerCase())).toList();
		}
		final proofs = t['trainerSpecializationProof'] ?? t['specializationProofs'];
		final list = proofs is List ? proofs : [];
		final fromProofs = list
				.map((e) => (e is Map ? (e['specialization'] ?? e['name'] ?? '').toString() : e.toString()))
				.where((s) => s.trim().isNotEmpty)
				.map((s) => s.trim())
				.toList();
		if (fromProofs.isNotEmpty) {
			final seen = <String>{};
			return fromProofs.where((e) => seen.add(e.toLowerCase())).toList();
		}
		return const [];
	}

		bool _isNutritionSpecPresent(List<String> specs) {
		if (specs.isEmpty) return false;
		final norms = specs.map(_norm).toList();
		// Match common variants
			const keys = [
				'nutrition', 'nutritionist', 'nutritionists',
				'diet', 'dietitian', 'dietician', 'dietitians', 'dieticians',
				'diet planning', 'diet plan', 'meal plan', 'meal planning'
			];
		return norms.any((s) => keys.any((k) => s.contains(k)));
	}

		Future<List<String>> _fetchSpecsFor(String trainerId) async {
		if (trainerId.isEmpty) return const [];
		if (_specCache.containsKey(trainerId)) return _specCache[trainerId]!;
		try {
			final sp = await SharedPreferences.getInstance();
			final token = sp.getString('fitstreet_token') ?? '';
			final api = FitstreetApi('https://api.fitstreet.in', token: token);
			final resp = await api.getSpecializationProofs(trainerId);
			if (resp.statusCode == 200) {
					final body = resp.body;
					dynamic json;
					try {
						json = body.isNotEmpty ? jsonDecode(body) : null;
					} catch (_) {
						json = null;
					}
					List items;
					if (json is List) {
						items = json;
					} else if (json is Map) {
						items = (json['data'] ?? json['proofs'] ?? json['specializations'] ?? json['items'] ?? []) as List? ?? [];
					} else {
						items = const [];
					}
					final specs = items
							.map((e) => (e is Map ? (e['specialization'] ?? e['name'] ?? '').toString() : e.toString()))
							.map((s) => s.trim())
							.where((s) => s.isNotEmpty)
							.toList();
					final seen = <String>{};
					final out = specs.where((e) => seen.add(e.toLowerCase())).toList();
					_specCache[trainerId] = out;
					return out;
			}
		} catch (_) {}
		return const [];
	}

	Future<void> _load() async {
		setState(() {
			_loading = true;
			_error = null;
		});
		try {
			final sp = await SharedPreferences.getInstance();
			final token = sp.getString('fitstreet_token') ?? '';
			final api = FitstreetApi('https://api.fitstreet.in', token: token);
					final resp = await api.getAllTrainers();
					if (resp.statusCode == 200) {
						final root = resp.body;
						final data = root.isNotEmpty ? jsonDecode(root) : [];
						final list = (data is Map && data['data'] is List)
								? (data['data'] as List)
								: (data is List ? data : []);
				final base = list.whereType<Map>().map((m) => m.map((k, v) => MapEntry(k.toString(), v))).cast<Map<String, dynamic>>().toList();

						// Eligibility: KYC approved and available
						final eligible = base.where((t) {
							final isKyc = (t['isKyc'] ?? false).toString().toLowerCase() == 'true' || t['isKyc'] == true;
							final status = (t['status'] ?? '').toString().trim().toLowerCase();
							final availRaw = t['isAvailable'];
							final isAvailable = !(availRaw == false || (availRaw is String && availRaw.toLowerCase() == 'false'));
							return isKyc && status == 'approved' && isAvailable;
						}).toList();

						// First pass: payload-based detection
						final payloadMatches = eligible.where((t) => _isNutritionSpecPresent(_extractSpecs(t))).toList();
						if (mounted) setState(() => _nutritionists = payloadMatches);

						// Second pass: for those without payload specs, try proofs API and merge
						final unknown = eligible.where((t) => !_isNutritionSpecPresent(_extractSpecs(t))).toList();
						if (unknown.isNotEmpty) {
							// Process sequentially to limit load; typically a small list
							final List<Map<String, dynamic>> toAdd = [];
							for (final t in unknown) {
								final id = (t['_id'] ?? t['id'] ?? '').toString();
								if (id.isEmpty) continue;
								final specs = await _fetchSpecsFor(id);
								if (_isNutritionSpecPresent(specs)) {
									toAdd.add(t);
								}
							}
							if (toAdd.isNotEmpty && mounted) {
								setState(() => _nutritionists = [..._nutritionists, ...toAdd]);
							}
						}
			} else {
				setState(() => _error = 'Server ${resp.statusCode}');
			}
		} catch (e) {
			setState(() => _error = e.toString());
		} finally {
			if (mounted) setState(() => _loading = false);
		}
	}

	List<Map<String, dynamic>> get _filtered {
		final q = _searchCtrl.text.trim().toLowerCase();
		if (q.isEmpty) return _nutritionists;
		return _nutritionists.where((t) {
			final name = (t['fullName'] ?? t['name'] ?? '').toString().toLowerCase();
			final code = (t['trainerUniqueId'] ?? '').toString().toLowerCase();
			return name.contains(q) || code.contains(q);
		}).toList();
	}

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			extendBodyBehindAppBar: true,
			appBar: AppBar(
				title: const Text('Nutritionists'),
				backgroundColor: Colors.transparent,
				elevation: 0,
				leading: IconButton(
					icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
					onPressed: () => Navigator.pop(context),
				),
				flexibleSpace: Container(color: Colors.black.withOpacity(0.15)),
			),
			body: Container(
				decoration: const BoxDecoration(
					image: DecorationImage(
						image: AssetImage('assets/image/nutri-bg.png'),
						fit: BoxFit.cover,
						colorFilter: ColorFilter.mode(Colors.black54, BlendMode.darken),
					),
				),
				child: Stack(
					children: [
						if (_loading)
							const Center(child: CircularProgressIndicator())
						else if (_error != null)
							Center(child: Text(_error!, style: const TextStyle(color: Colors.white)))
						else
							SafeArea(
								child: Padding(
									padding: const EdgeInsets.all(16.0),
									child: Column(
										crossAxisAlignment: CrossAxisAlignment.start,
										children: [
											// Search
											Container(
												height: 44,
												padding: const EdgeInsets.symmetric(horizontal: 12),
												decoration: BoxDecoration(
													color: Colors.white.withOpacity(0.12),
													borderRadius: BorderRadius.circular(12),
													border: Border.all(color: Colors.white24),
												),
												child: Row(children: [
													const Icon(Icons.search, color: Colors.white70, size: 20),
													const SizedBox(width: 8),
													Expanded(
														child: TextField(
															controller: _searchCtrl,
															style: const TextStyle(color: Colors.white),
															decoration: const InputDecoration(
																hintText: 'Search by Name or Trainer Id',
																hintStyle: TextStyle(color: Colors.white54),
																border: InputBorder.none,
															),
														),
													),
												]),
											),
											const SizedBox(height: 12),
											Text(
												'${_filtered.length} Nutritionist${_filtered.length == 1 ? '' : 's'} available',
												style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
											),
											const SizedBox(height: 10),
											Expanded(
												child: _filtered.isEmpty
														? const Center(
																child: Text('No nutritionists found right now', style: TextStyle(color: Colors.white70)),
															)
														: RefreshIndicator(
																onRefresh: _load,
																child: ListView.builder(
																	physics: const AlwaysScrollableScrollPhysics(),
																	itemCount: _filtered.length,
																	itemBuilder: (context, index) {
																		final t = _filtered[index];
																		final name = (t['fullName'] ?? t['name'] ?? 'Nutritionist').toString();
																		final code = (t['trainerUniqueId'] ?? '').toString();
																		final city = (t['currentCity'] ?? t['city'] ?? '').toString();
																		final state = (t['currentState'] ?? t['state'] ?? '').toString();
																		final pincode = (t['currentPincode'] ?? t['pincode'] ?? '').toString();
																		final img = (t['trainerImageURL'] ?? '').toString();
																		final price1 = (t['oneSessionPrice'] ?? '').toString();
																		final priceM = (t['monthlySessionPrice'] ?? '').toString();
																		final id = (t['_id'] ?? t['id'] ?? '').toString();
																		final mode = (t['mode'] ?? '').toString();

																		return Padding(
																			padding: const EdgeInsets.only(bottom: 14),
																			child: GlassCard(
																				child: Padding(
																						padding: const EdgeInsets.all(13),
																					child: Column(
																						crossAxisAlignment: CrossAxisAlignment.start,
																						children: [
																							Row(
																								crossAxisAlignment: CrossAxisAlignment.start,
																								children: [
																									// Profile Image
																									Column(
																										children: [
																											Container(
																												width: 120,
																												height: 120,
																												decoration: const BoxDecoration(shape: BoxShape.circle),
																												clipBehavior: Clip.antiAlias,
																												child: img.isNotEmpty
																														? Image.network(
																																img,
																																fit: BoxFit.cover,
																																errorBuilder: (_, __, ___) => Image.asset('assets/image/fitstreet-bull-logo.png', fit: BoxFit.cover),
																															)
																														: Image.asset('assets/image/fitstreet-bull-logo.png', fit: BoxFit.cover),
																											),
																											const SizedBox(height: 4),
																											// View Profile Button
																											Container(
																												decoration: BoxDecoration(
																													borderRadius: BorderRadius.circular(12),
																												),
																												child: TextButton(
																													onPressed: () {
																														final trainerForProfile = t.map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''));
																														Navigator.push(
																															context,
																															MaterialPageRoute(
																																builder: (_) => TrainerProfileScreen(trainer: Map<String, String>.from(trainerForProfile)),
																															),
																														);
																													},
																													style: TextButton.styleFrom(
																														padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
																														minimumSize: Size.zero,
																													),
																													child: const Text(
																														'view profile',
																														style: TextStyle(
																															color: Color(0xFFFF6B35),
																															fontSize: 16,
																															fontWeight: FontWeight.w900,
																															decoration: TextDecoration.underline,
																															decorationColor: Color(0xFFFF6B35),
																															decorationThickness: 2,
																														),
																													),
																												),
																											),
																										],
																									),
																									const SizedBox(width: 16),
																									// Trainer Details
																									Expanded(
																										child: Column(
																											crossAxisAlignment: CrossAxisAlignment.start,
																											children: [
																												Row(
																													children: [
																														Expanded(
																															child: Column(
																																crossAxisAlignment: CrossAxisAlignment.start,
																																children: [
																																	Text(
																																		name,
																																		style: const TextStyle(
																																			color: Color(0xFFFF6B35),
																																			fontSize: 18,
																																			fontWeight: FontWeight.bold,
																																		),
																																	),
																																	if (code.isNotEmpty)
																																		Text(
																																			'($code)',
																																			style: const TextStyle(
																																				color: Colors.white,
																																				fontSize: 13,
																																				fontWeight: FontWeight.bold,
																																			),
																																		),
																																],
																															),
																														),
																														// Gender Text
																														Container(
																															child: Text(
																																() {
																																	final gender = (t['gender'] ?? '').toString().toLowerCase();
																																	switch (gender) {
																																		case 'female':
																																			return 'Female';
																																		case 'male':
																																			return 'Male';
																																		case 'other':
																																			return 'Other';
																																		default:
																																			return 'Other';
																																	}
																																}(),
																																style: const TextStyle(
																																	color: Colors.white,
																																	fontSize: 14,
																																	fontWeight: FontWeight.bold,
																																),
																															),
																														),
																													],
																												),
																												const SizedBox(height: 6),
																												// Mode Pill
																												if (mode.isNotEmpty)
																													Container(
																														padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
																														decoration: BoxDecoration(
																															color: const Color(0xFFFF6B35),
																															borderRadius: BorderRadius.circular(20),
																														),
																														child: Text(
																															mode.toLowerCase() == 'both'
																																	? 'online & offline session'
																																	: '${mode.toLowerCase()} session',
																															style: const TextStyle(
																																color: Colors.white,
																																fontWeight: FontWeight.bold,
																																fontSize: 12,
																															),
																														),
																													),
																												const SizedBox(height: 8),
																												// Specialization Tags
																												Builder(builder: (context) {
																													final specs = _extractSpecs(t);
																													final cachedSpecs = _specCache[id] ?? [];
																													final allSpecs = [...specs, ...cachedSpecs].where((s) => s.isNotEmpty).toSet().toList();
																													
																													if (allSpecs.isEmpty) return const SizedBox.shrink();
																													
																													final isExpanded = _expandedTrainers.contains(id);
																													final displaySpecs = isExpanded ? allSpecs : allSpecs.take(3).toList();
																													final hasMore = allSpecs.length > 3;
																													final remainingCount = allSpecs.length - 3;
																													
																													return Wrap(
																														spacing: 6,
																														runSpacing: 4,
																														children: [
																															...displaySpecs.map((spec) {
																																return Container(
																																	padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
																																	decoration: BoxDecoration(
																																		color: const Color(0xFFFF6B35),
																																		borderRadius: BorderRadius.circular(12),
																																		border: Border.all(color: Colors.white.withOpacity(0.3)),
																																	),
																																	child: Text(
																																		spec,
																																		style: const TextStyle(
																																			color: Colors.white,
																																			fontSize: 10,
																																			fontWeight: FontWeight.w600,
																																		),
																																	),
																																);
																															}),
																															if (hasMore && !isExpanded)
																																GestureDetector(
																																	onTap: () {
																																		setState(() {
																																			_expandedTrainers.add(id);
																																		});
																																	},
																																	child: Container(
																																		padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
																																		decoration: BoxDecoration(
																																			color: Colors.white.withOpacity(0.2),
																																			borderRadius: BorderRadius.circular(12),
																																			border: Border.all(color: Colors.white.withOpacity(0.4)),
																																		),
																																		child: Text(
																																			'+$remainingCount more',
																																			style: const TextStyle(
																																				color: Colors.white,
																																				fontSize: 10,
																																				fontWeight: FontWeight.w600,
																																			),
																																		),
																																	),
																																),
																															if (hasMore && isExpanded)
																																GestureDetector(
																																	onTap: () {
																																		setState(() {
																																			_expandedTrainers.remove(id);
																																		});
																																	},
																																	child: Container(
																																		padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
																																		decoration: BoxDecoration(
																																			color: Colors.white.withOpacity(0.2),
																																			borderRadius: BorderRadius.circular(12),
																																			border: Border.all(color: Colors.white.withOpacity(0.4)),
																																		),
																																		child: const Text(
																																			'show less',
																																			style: TextStyle(
																																				color: Colors.white,
																																				fontSize: 10,
																																				fontWeight: FontWeight.w600,
																																			),
																																		),
																																	),
																																),
																														],
																													);
																												}),
																											],
																										),
																									),
																								],
																							),
																							const SizedBox(height: 3),
																							// White Info Box
																							Container(
																								width: double.infinity,
																								padding: const EdgeInsets.all(12),
																								decoration: BoxDecoration(
																									color: Colors.white,
																									borderRadius: BorderRadius.circular(15),
																								),
																								child: Column(
																									crossAxisAlignment: CrossAxisAlignment.start,
																									children: [
																										// Location
																										Row(
																											children: [
																												Icon(Icons.place, color: Colors.orange[550], size: 19),
																												const SizedBox(width: 4),
																												Expanded(
																													child: Text(
																														[city, state, pincode].where((e) => e.trim().isNotEmpty).join(', '),
																														style: const TextStyle(color: Colors.black, fontSize: 13, fontWeight: FontWeight.bold),
																														maxLines: 1,
																														overflow: TextOverflow.ellipsis,
																													),
																												),
																											],
																										),
																										const SizedBox(height: 8),
																										// Pricing
																										Row(
																											children: [
																												Icon(Icons.currency_rupee_rounded, color: Colors.orange[550], size: 19),
																												Expanded(
																													child: Text(
																														'${price1.isNotEmpty ? '$price1/ session' : ''}${price1.isNotEmpty && priceM.isNotEmpty ? ' and ' : ''}${priceM.isNotEmpty ? '$priceM monthly session' : ''}',
																														style: const TextStyle(color: Colors.black, fontSize: 13, fontWeight: FontWeight.bold),
																													),
																												),
																											],
																										),
																									],
																								),
																							),
																							const SizedBox(height: 12),
																							// Book Session Button
																							Align(
																								alignment: Alignment.centerRight,
																								child: Container(
																									decoration: BoxDecoration(
																										color: const Color(0xFFFF6B35),
																										borderRadius: BorderRadius.circular(25),
																									),
																									child: TextButton(
																										onPressed: () {
																											final trainerForProfile = t.map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''));
																											Navigator.push(
																												context,
																												MaterialPageRoute(
																													builder: (_) => TrainerProfileScreen(
																														trainer: Map<String, String>.from(trainerForProfile),
																													),
																												),
																											);
																										},
																										style: TextButton.styleFrom(
																											padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
																										),
																										child: const Text(
																											'Book Session',
																											style: TextStyle(
																												color: Colors.white,
																												fontWeight: FontWeight.bold,
																												fontSize: 14,
																											),
																										),
																									),
																								),
																							),
																						],
																					),
																				),
																			),
																		);
																	},
																),
															),
											),
										],
									),
								),
							),
					],
				),
			),
		);
	}
}

