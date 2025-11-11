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

	Widget _specChip(String text) {
		return Container(
			padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
			margin: const EdgeInsets.only(right: 8, bottom: 8),
			decoration: BoxDecoration(
				color: Colors.white.withOpacity(0.12),
				borderRadius: BorderRadius.circular(999),
				border: Border.all(color: Colors.white.withOpacity(0.28), width: 0.75),
			),
			child: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
		);
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
																		final initialSpecs = _extractSpecs(t);

																		return Padding(
																			padding: const EdgeInsets.only(bottom: 14),
																			child: GlassCard(
																				child: Padding(
																					padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
																					child: Column(
																						crossAxisAlignment: CrossAxisAlignment.start,
																						children: [
																							Center(
																								child: Column(
																									children: [
																										Container(
																											width: 96,
																											height: 96,
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
																										const SizedBox(height: 8),
																										TextButton(
																											onPressed: () {
																												final trainerForProfile = t.map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''));
																												Navigator.push(
																													context,
																													MaterialPageRoute(
																														builder: (_) => TrainerProfileScreen(trainer: Map<String, String>.from(trainerForProfile)),
																													),
																												);
																											},
																											child: const Text('View Profile', style: TextStyle(decoration: TextDecoration.underline)),
																										),
																									],
																								),
																							),
																							const SizedBox(height: 6),
																							Text(
																								code.isNotEmpty ? '$name ($code)' : name,
																								style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
																							),
																							const SizedBox(height: 8),
																							Builder(
																								builder: (_) {
																									if (initialSpecs.isNotEmpty) {
																										return Wrap(
																											spacing: 8,
																											runSpacing: 8,
																											children: initialSpecs.map((s) => _specChip(s)).toList(),
																										);
																									}
																									if (id.isEmpty) return const SizedBox.shrink();
																									return FutureBuilder<List<String>>(
																										future: _fetchSpecsFor(id),
																										builder: (ctx, snap) {
																											final specs = snap.data ?? const [];
																											if (specs.isEmpty) return const SizedBox.shrink();
																											return Wrap(
																												spacing: 8,
																												runSpacing: 8,
																												children: specs.map((s) => _specChip(s)).toList(),
																											);
																										},
																									);
																								},
																							),
																							const SizedBox(height: 10),
																							Row(
																								crossAxisAlignment: CrossAxisAlignment.start,
																								children: [
																									const Icon(Icons.place, color: Colors.white70, size: 16),
																									const SizedBox(width: 6),
																									Expanded(
																										child: Text(
																											[city, state, pincode].where((e) => e.trim().isNotEmpty).join(', '),
																											style: const TextStyle(color: Colors.white70),
																										),
																									),
																								],
																							),
																							const SizedBox(height: 6),
																							Row(
																								children: [
																									const Icon(Icons.currency_rupee, color: Colors.white70, size: 16),
																									const SizedBox(width: 6),
																									Expanded(
																										child: Text(
																											'${price1.isNotEmpty ? '₹ $price1/ session' : ''}${price1.isNotEmpty && priceM.isNotEmpty ? '  &  ' : ''}${priceM.isNotEmpty ? '₹ $priceM monthly session' : ''}',
																											style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
																										),
																									),
																								],
																							),
																							const SizedBox(height: 12),
																							Align(
																								alignment: Alignment.centerRight,
																								child: ElevatedButton(
																									style: ElevatedButton.styleFrom(
																										backgroundColor: const Color(0xFF1E88E5),
																										padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
																									),
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
																									child: const Text('Book Session', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

