import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:ui' show ImageFilter;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';

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
	final TextEditingController _locationCtrl = TextEditingController();

	// Full list (nutritionists only) and filtered by search
	List<Map<String, dynamic>> _nutritionists = [];

	// Cache of fetched specialization proofs per-trainer
	final Map<String, List<String>> _specCache = {};

	// Track which trainers have expanded specializations
	final Set<String> _expandedTrainers = {};

	// Filters similar to TrainerListScreen
	String _gender = 'All';
	String _experience = 'All';
	String _mode = 'All';
	String _fee = 'All';

	// User location to compute distance
	Position? _userPos;

	// Overlay glass menu support
	OverlayEntry? _activeMenu;
	void _hideActiveMenu() {
		_activeMenu?.remove();
		_activeMenu = null;
	}
	void _showGlassMenu({
		required GlobalKey anchorKey,
		required List<String> options,
		required void Function(String) onSelected,
	}) {
		_hideActiveMenu();
		final ctx = anchorKey.currentContext;
		if (ctx == null) return;
		final box = ctx.findRenderObject() as RenderBox?;
		if (box == null) return;
		final size = box.size;
		final offset = box.localToGlobal(Offset.zero);
		final screen = MediaQuery.of(context).size;

		const double menuWidth = 200;
		final double horizontalPadding = 16;
		final double top = offset.dy + size.height + 8;
		double left = offset.dx;
		if (left + menuWidth + horizontalPadding > screen.width) {
			left = screen.width - menuWidth - horizontalPadding;
			if (left < horizontalPadding) left = horizontalPadding;
		}

		_activeMenu = OverlayEntry(builder: (oc) {
			return Stack(children: [
				Positioned.fill(
					child: GestureDetector(
						behavior: HitTestBehavior.translucent,
						onTap: _hideActiveMenu,
						child: const SizedBox.expand(),
					),
				),
				Positioned(
					left: left,
					top: top,
					width: menuWidth,
					child: Material(
						color: Colors.transparent,
						child: ClipRRect(
							borderRadius: BorderRadius.circular(16),
							child: BackdropFilter(
								filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
								child: Container(
									constraints: const BoxConstraints(maxHeight: 260),
									decoration: BoxDecoration(
										gradient: LinearGradient(
											colors: [
												Colors.white.withOpacity(0.14),
												Colors.white.withOpacity(0.06),
											],
											begin: Alignment.topLeft,
											end: Alignment.bottomRight,
										),
										borderRadius: BorderRadius.circular(16),
										border: Border.all(color: Colors.white.withOpacity(0.28), width: 0.75),
										boxShadow: [
											BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 18, offset: const Offset(0, 8)),
										],
									),
									child: ListView.separated(
										padding: const EdgeInsets.symmetric(vertical: 8),
										shrinkWrap: true,
										itemCount: options.length,
										separatorBuilder: (_, __) => Divider(height: 1, color: Colors.white.withOpacity(0.12)),
										itemBuilder: (c, i) {
											final o = options[i];
											return InkWell(
												onTap: () {
													onSelected(o);
													_hideActiveMenu();
												},
												child: Padding(
													padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
													child: Text(o, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
												),
											);
										},
									),
								),
							),
						),
					),
				),
			]);
		});
		Overlay.of(context).insert(_activeMenu!);
	}

	@override
	void initState() {
		super.initState();
		_searchCtrl.addListener(() => setState(() {}));
		_locationCtrl.addListener(() => setState(() {}));
		_load();
	}

	@override
	void dispose() {
		_searchCtrl.dispose();
		_locationCtrl.dispose();
		_hideActiveMenu();
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

	String _expDisplay(String v) {
		final s = v.trim().toLowerCase();
		if (s.isEmpty) return '';
		const buckets = ['0-6', '6m-1y', '1-3', '3-5', '5+'];
		if (buckets.contains(s)) {
			switch (s) {
				case '0-6':
					return '0-6 months';
				case '6m-1y':
					return '6 months - 1 year';
				case '1-3':
					return '1-3 years';
				case '3-5':
					return '3-5 years';
				case '5+':
					return '5+ years';
				default:
					return s;
			}
		}
		final match = RegExp(r"(\d+\.?\d*)").firstMatch(s);
		if (match != null) {
			final val = double.tryParse(match.group(1) ?? '');
			if (val != null) {
				final isMonth = s.contains('month');
				final years = isMonth ? (val / 12.0) : val;
				if (years < 0.5) return '0-6 months';
				if (years < 1.0) return '6 months - 1 year';
				if (years < 3.0) return '1-3 years';
				if (years < 5.0) return '3-5 years';
				return '5+ years';
			}
		}
		return v.isEmpty ? '' : v;
	}

	// --- Additional helpers for filters ---
	num? _parseMoney(dynamic v) {
		if (v == null) return null;
		final s = v.toString();
		if (s.trim().isEmpty) return null;
		final digits = s.replaceAll(RegExp(r'[^0-9.]'), '');
		if (digits.isEmpty) return null;
		return num.tryParse(digits);
	}

	String _expBucket(String raw) {
		final s = (raw).toString().trim().toLowerCase();
		if (s.isEmpty) return '';
		const buckets = ['0-6', '6m-1y', '1-3', '3-5', '5+'];
		if (buckets.contains(s)) return s;
		final match = RegExp(r"(\d+\.?\d*)").firstMatch(s);
		if (match != null) {
			final val = double.tryParse(match.group(1) ?? '');
			if (val != null) {
				final isMonth = s.contains('month');
				final years = isMonth ? (val / 12.0) : val;
				if (years < 0.5) return '0-6';
				if (years < 1.0) return '6m-1y';
				if (years < 3.0) return '1-3';
				if (years < 5.0) return '3-5';
				return '5+';
			}
		}
		if (s.contains('5')) return '5+';
		if (s.contains('3-5') || s.contains('3 to 5')) return '3-5';
		if (s.contains('1-3') || s.contains('1 to 3')) return '1-3';
		if (s.contains('6') && s.contains('month')) return '0-6';
		return '';
	}

	bool _supportsChannel(String rawMode, String channel) {
		final s = (rawMode).toString().trim().toLowerCase();
		if (s.isEmpty) return false;
		final hasOnline = s.contains('online');
		final hasOffline = s.contains('offline');
		final isBoth = s.contains('both') || (hasOnline && hasOffline) || s.contains('&');
		switch (channel.toLowerCase()) {
			case 'online':
				return hasOnline || isBoth;
			case 'offline':
				return hasOffline || isBoth;
			default:
				return false;
		}
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
			// Try to obtain user's current position (ask permission if needed)
			final hasService = await Geolocator.isLocationServiceEnabled();
			LocationPermission perm = await Geolocator.checkPermission();
			if (perm == LocationPermission.denied) {
				perm = await Geolocator.requestPermission();
			}
			if (hasService && (perm == LocationPermission.always || perm == LocationPermission.whileInUse)) {
				_userPos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
			}

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

						// Second pass: for those without payload specs, try proofs API and merge
						final unknown = eligible.where((t) => !_isNutritionSpecPresent(_extractSpecs(t))).toList();
						final List<Map<String, dynamic>> toAdd = [];
						if (unknown.isNotEmpty) {
							// Process sequentially to limit load; typically a small list
							for (final t in unknown) {
								final id = (t['_id'] ?? t['id'] ?? '').toString();
								if (id.isEmpty) continue;
								final specs = await _fetchSpecsFor(id);
								if (_isNutritionSpecPresent(specs)) {
									toAdd.add(t);
								}
							}
						}

						// Combine results
						List<Map<String, dynamic>> combined = [...payloadMatches, ...toAdd];

						// compute distance (km) if coordinates available
						if (_userPos != null) {
							for (final t in combined) {
								final lat = double.tryParse((t['latitude'] ?? t['lat'] ?? '').toString());
								final lng = double.tryParse((t['longitude'] ?? t['lng'] ?? t['long'] ?? '').toString());
								if (lat != null && lng != null) {
									final dMeters = Geolocator.distanceBetween(_userPos!.latitude, _userPos!.longitude, lat, lng);
									t['distanceKm'] = (dMeters / 1000.0);
								}
							}
							// sort by nearest first; trainers with distance go first
							combined.sort((a, b) {
								final da = (a['distanceKm'] as num?)?.toDouble();
								final db = (b['distanceKm'] as num?)?.toDouble();
								if (da == null && db == null) return 0;
								if (da == null) return 1;
								if (db == null) return -1;
								return da.compareTo(db);
							});
						}

						if (mounted) setState(() => _nutritionists = combined);
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
		final lq = _locationCtrl.text.trim().toLowerCase();
		return _nutritionists.where((t) {
			// availability guard (defensive)
			final availRaw = t['isAvailable'];
			final isAvailable = !(availRaw == false || (availRaw is String && availRaw.toLowerCase() == 'false'));
			if (!isAvailable) return false;

			// search
			final name = (t['fullName'] ?? t['name'] ?? '').toString().toLowerCase();
			final code = (t['trainerUniqueId'] ?? '').toString().toLowerCase();
			final okSearch = q.isEmpty || name.contains(q) || code.contains(q);

			// location filter: match against city/state/pincode (and current* variants)
			final city = (t['currentCity'] ?? t['city'] ?? '').toString().toLowerCase();
			final state = (t['currentState'] ?? t['state'] ?? '').toString().toLowerCase();
			final pin = (t['currentPincode'] ?? t['pincode'] ?? '').toString().toLowerCase();
			final okLocation = lq.isEmpty || city.contains(lq) || state.contains(lq) || pin.contains(lq);

			// gender
			final g = (t['gender'] ?? '').toString();
			final okGender = _gender == 'All' || g.toLowerCase() == _gender.toLowerCase();

			// mode
			final m = (t['mode'] ?? '').toString();
			bool okMode;
			switch (_mode) {
				case 'All':
					okMode = true;
					break;
				case 'Online':
					okMode = _supportsChannel(m, 'online');
					break;
				case 'Offline':
					okMode = _supportsChannel(m, 'offline');
					break;
				case 'Both':
					okMode = _supportsChannel(m, 'online') && _supportsChannel(m, 'offline');
					break;
				default:
					okMode = true;
			}

			// experience buckets
			final expRaw = (t['experience'] ?? '').toString();
			final expBucket = _expBucket(expRaw);
			final okExp = _experience == 'All' || (_experience.isNotEmpty && expBucket == _experience);

			// fee filter: by one-session price (fallback to monthly if single not present)
			final priceOne = (t['oneSessionPrice'] ?? t['oneSession'] ?? '').toString();
			final priceMonth = (t['monthlySessionPrice'] ?? t['monthly'] ?? '').toString();
			final priceVal = _parseMoney(priceOne) ?? _parseMoney(priceMonth);
			bool okFee;
			switch (_fee) {
				case 'All':
					okFee = true;
					break;
				case '< ₹500':
					okFee = priceVal != null && priceVal < 500;
					break;
				case '₹500-₹999':
					okFee = priceVal != null && priceVal >= 500 && priceVal <= 999;
					break;
				case '₹1000-₹1999':
					okFee = priceVal != null && priceVal >= 1000 && priceVal <= 1999;
					break;
				case '₹2000+':
					okFee = priceVal != null && priceVal >= 2000;
					break;
				default:
					okFee = true;
			}

			return okSearch && okLocation && okGender && okMode && okExp && okFee;
		}).toList();
	}

	Widget _filterChip(String label, String value, List<String> options, void Function(String) onChanged) {
		final key = GlobalKey();
		return GestureDetector(
			onTap: () {
				if (_activeMenu != null) {
					_hideActiveMenu();
				} else {
					_showGlassMenu(anchorKey: key, options: options, onSelected: onChanged);
				}
			},
			child: Container(
				key: key,
				decoration: const BoxDecoration(),
				child: ClipRRect(
					borderRadius: BorderRadius.circular(999),
					child: BackdropFilter(
						filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
						child: Container(
							padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
							decoration: BoxDecoration(
								gradient: LinearGradient(
									colors: [
										Colors.white.withOpacity(0.16),
										Colors.white.withOpacity(0.06),
									],
									begin: Alignment.topLeft,
									end: Alignment.bottomRight,
								),
								borderRadius: BorderRadius.circular(999),
								border: Border.all(color: Colors.white.withOpacity(0.28), width: 0.75),
								boxShadow: [
									BoxShadow(
										color: Colors.black.withOpacity(0.15),
										blurRadius: 12,
										offset: const Offset(0, 6),
									),
								],
							),
							child: Row(
								mainAxisSize: MainAxisSize.min,
								children: [
									Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
									const SizedBox(width: 6),
									const Icon(Icons.keyboard_arrow_down, color: Colors.white70, size: 18),
								],
							),
						),
					),
				),
			),
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
											// Search + location bar
											Row(
												children: [
													Expanded(
														flex: 6,
														child: Container(
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
													),
													const SizedBox(width: 12),
													Expanded(
														flex: 4,
														child: Container(
															height: 44,
															padding: const EdgeInsets.symmetric(horizontal: 12),
															decoration: BoxDecoration(
																color: Colors.white.withOpacity(0.12),
																borderRadius: BorderRadius.circular(12),
																border: Border.all(color: Colors.white24),
															),
															child: Row(children: [
																const Icon(Icons.location_on, color: Colors.white70, size: 20),
																const SizedBox(width: 8),
																Expanded(
																	child: TextField(
																		controller: _locationCtrl,
																		style: const TextStyle(color: Colors.white),
																		decoration: const InputDecoration(
																			hintText: 'City/State/Pincode',
																			hintStyle: TextStyle(color: Colors.white54),
																			border: InputBorder.none,
																		),
																	),
																),
															]),
														),
													),
												],
											),
											const SizedBox(height: 12),
											// Filters row
											SingleChildScrollView(
												scrollDirection: Axis.horizontal,
												child: Row(
													children: [
														_filterChip('Gender', _gender, const ['All','Female','Male','Other'], (v) => setState(() => _gender = v)),
														const SizedBox(width: 8),
														_filterChip('Experience', _experience, const ['All','0-6','6m-1y','1-3','3-5','5+'], (v) => setState(() => _experience = v)),
														const SizedBox(width: 8),
														_filterChip('Mode', _mode, const ['All','Online','Offline','Both'], (v) => setState(() => _mode = v)),
														const SizedBox(width: 8),
														_filterChip('Fee', _fee, const ['All','< ₹500','₹500-₹999','₹1000-₹1999','₹2000+'], (v) => setState(() => _fee = v)),
														const SizedBox(width: 8),
														// Reset
														ClipRRect(
															borderRadius: BorderRadius.circular(999),
															child: BackdropFilter(
																filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
																child: InkWell(
																	onTap: () => setState(() {
																		_gender = 'All';
																		_experience = 'All';
																		_mode = 'All';
																		_fee = 'All';
																		_locationCtrl.clear();
																	}),
																	child: Container(
																		padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
																		decoration: BoxDecoration(
																			gradient: LinearGradient(
																				colors: [
																					Colors.white.withOpacity(0.16),
																					Colors.white.withOpacity(0.06),
																				],
																				begin: Alignment.topLeft,
																				end: Alignment.bottomRight,
																			),
																			borderRadius: BorderRadius.circular(999),
																			border: Border.all(color: Colors.white.withOpacity(0.28), width: 0.75),
																		),
																		child: const Row(
																			mainAxisSize: MainAxisSize.min,
																			children: [
																				Icon(Icons.refresh, color: Colors.white70, size: 18),
																				SizedBox(width: 6),
																				Text('Reset', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
																			],
																		),
																	),
																),
															),
														),
													],
												),
											),
											const SizedBox(height: 10),
											Text(
												() {
													final list = _filtered;
													final loc = _locationCtrl.text.trim();
													final city = list.isNotEmpty ? (list.first['city'] ?? list.first['currentCity'] ?? '') : '';
													final state = list.isNotEmpty ? (list.first['state'] ?? list.first['currentState'] ?? '') : '';
													final area = loc.isNotEmpty
															? loc
															: [city, state].where((s) => s != null && s.toString().trim().isNotEmpty).join(', ');
													final suffix = _userPos != null ? '  •  sorted by nearest' : '';
													return '${list.length} Nutritionist${list.length == 1 ? '' : 's'} available ${area.isNotEmpty ? 'in $area' : ''}$suffix';
												}(),
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
																		final exp = _expDisplay((t['experience'] ?? '').toString());
																		final distanceKm = (t['distanceKm'] as num?)?.toDouble();
																		String? distText;
																		if (distanceKm != null) {
																			final rounded = distanceKm < 1
																					? '${(distanceKm * 1000).toStringAsFixed(0)} m'
																					: '${distanceKm.toStringAsFixed(distanceKm < 10 ? 1 : 0)} km';
																			distText = '$rounded away';
																		}

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
																										// Location with distance
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
																												if (distText != null)
																													Text(distText, style: const TextStyle(color: Colors.black, fontSize: 13, fontWeight: FontWeight.bold),),
																											],
																										),
																										const SizedBox(height: 8),
																										// Experience
																										if (exp.isNotEmpty)
																											Row(
																												children: [
																													Icon(Icons.workspace_premium, color: Colors.orange[550], size: 19),
																													const SizedBox(width: 4),
																													Text(
																														exp,
																														style: const TextStyle(color: Colors.black, fontSize: 13, fontWeight: FontWeight.bold),
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

