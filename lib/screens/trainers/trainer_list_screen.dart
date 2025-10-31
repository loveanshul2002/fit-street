import 'package:flutter/material.dart';
import 'dart:ui' show ImageFilter;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../widgets/glass_card.dart';
import '../../services/fitstreet_api.dart';
import 'trainer_profile_screen.dart';
// Removed direct Book Session navigation; using TrainerProfileScreen instead
import 'package:geolocator/geolocator.dart';

class TrainerListScreen extends StatefulWidget {
  const TrainerListScreen({super.key});

  @override
  State<TrainerListScreen> createState() => _TrainerListScreenState();
}

class _TrainerListScreenState extends State<TrainerListScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _trainers = [];
  // cache for specializations fetched per-trainer (if not present in list payload)
  final Map<String, List<String>> _specCache = {};
  // UI state
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _locationCtrl = TextEditingController();
  String _gender = 'All';
  String _experience = 'All';
  String _mode = 'All';
  String _fee = 'All';
  String _speciality = 'All';
  Position? _userPos;

  // Active glass menu overlay
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
    // Close any existing menu first
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
        // Tap outside to dismiss
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

  // Removed liquid background animation

  // --- Parsing helpers for filters ---
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
    // If already one of the buckets, return as-is
    const buckets = ['0-6', '6m-1y', '1-3', '3-5', '5+'];
    if (buckets.contains(s)) return s;
    // Try to parse months/years
    // Heuristics: if contains 'month', parse number as months; else years
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
    // Fallback: textual hints
    if (s.contains('5')) return '5+';
    if (s.contains('3-5') || s.contains('3 to 5')) return '3-5';
    if (s.contains('1-3') || s.contains('1 to 3')) return '1-3';
    if (s.contains('6') && s.contains('month')) return '0-6';
    return '';
  }

  String _norm(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[_\-]+'), ' ')
      .replaceAll(RegExp(r'[^a-z0-9 ]+'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

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

  @override
  void initState() {
    super.initState();
    _load();
  _searchCtrl.addListener(() => setState(() {}));
  // Update list as user types a location (city/state/pincode)
  _locationCtrl.addListener(() => setState(() {}));
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
        final parsed = jsonDecode(resp.body);
        final list = (parsed is Map && parsed['data'] is List)
            ? (parsed['data'] as List)
            : (parsed is List ? parsed : []);
        final filtered = list.whereType<Map>().where((t) {
          final isKyc = (t['isKyc'] ?? false).toString().toLowerCase() == 'true' || t['isKyc'] == true;
          final status = (t['status'] ?? '').toString();
          // Only show when trainer is available (t['isAvailable'] not explicitly false)
          final availRaw = t['isAvailable'];
          final isAvailable = !(availRaw == false || (availRaw is String && availRaw.toLowerCase() == 'false'));
          return isKyc && status.toLowerCase() == 'approved' && isAvailable;
        }).map((m) => m.map((k, v) => MapEntry(k.toString(), v))).cast<Map<String, dynamic>>().toList();

        // compute distance (km) if coordinates available
        if (_userPos != null) {
          for (final t in filtered) {
            final lat = double.tryParse((t['latitude'] ?? t['lat'] ?? '').toString());
            final lng = double.tryParse((t['longitude'] ?? t['lng'] ?? t['long'] ?? '').toString());
            if (lat != null && lng != null) {
              final dMeters = Geolocator.distanceBetween(_userPos!.latitude, _userPos!.longitude, lat, lng);
              t['distanceKm'] = (dMeters / 1000.0);
            }
          }
          // sort by nearest first; trainers with distance go first
          filtered.sort((a, b) {
            final da = (a['distanceKm'] as num?)?.toDouble();
            final db = (b['distanceKm'] as num?)?.toDouble();
            if (da == null && db == null) return 0;
            if (da == null) return 1;
            if (db == null) return -1;
            return da.compareTo(db);
          });
        }
  if (mounted) setState(() => _trainers = filtered);
  // Prefetch specializations for better speciality filter options (non-blocking)
  // Fetch a subset to limit overhead.
  _primeSpecialities(maxCount: 20);
      } else {
        setState(() => _error = 'Server ${resp.statusCode}');
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _primeSpecialities({int maxCount = 20}) async {
    try {
      final ids = _trainers
          .map((t) => (t['_id'] ?? t['id'] ?? '').toString())
          .where((id) => id.isNotEmpty && !_specCache.containsKey(id))
          .take(maxCount)
          .toList();
      if (ids.isEmpty) return;
      await Future.wait(ids.map(_fetchSpecsFor));
      if (mounted) setState(() {});
    } catch (_) {
      // ignore errors silently
    }
  }

  // --- Specialization helpers ---
  List<String> _parseSpecs(dynamic v) {
    if (v == null) return const [];
    if (v is String) {
      final s = v.trim();
      if (s.isEmpty) return const [];
      return s.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }
    if (v is List) {
      return v.map((e) => e.toString().trim()).where((e) => e.isNotEmpty && e.toLowerCase() != 'null').toList();
    }
    return const [];
  }

  List<String> _extractSpecs(Map<String, dynamic> t) {
    // Try a variety of common fields
    final List<String> fromStr = <String>[]
      ..addAll(_parseSpecs(t['specialization']))
      ..addAll(_parseSpecs(t['speciality']))
      ..addAll(_parseSpecs(t['specializations']))
      ..addAll(_parseSpecs(t['specializationList']));
    if (fromStr.isNotEmpty) {
      // remove duplicates while preserving order
      final seen = <String>{};
      return fromStr.where((e) => seen.add(e.toLowerCase())).toList();
    }
    // Sometimes specializations are nested under proofs
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

  Future<List<String>> _fetchSpecsFor(String trainerId) async {
    if (trainerId.isEmpty) return const [];
    if (_specCache.containsKey(trainerId)) return _specCache[trainerId]!;
    try {
      final sp = await SharedPreferences.getInstance();
      final token = sp.getString('fitstreet_token') ?? '';
      final api = FitstreetApi('https://api.fitstreet.in', token: token);
      final resp = await api.getSpecializationProofs(trainerId);
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        List items;
        if (body is List) {
          items = body;
        } else if (body is Map) {
          items = (body['data'] ?? body['proofs'] ?? body['specializations'] ?? body['items'] ?? []) as List? ?? [];
        } else {
          items = const [];
        }
        final specs = items
            .map((e) => (e is Map ? (e['specialization'] ?? e['name'] ?? '').toString() : e.toString()))
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
        // dedupe
        final seen = <String>{};
        final out = specs.where((e) => seen.add(e.toLowerCase())).toList();
        _specCache[trainerId] = out;
        return out;
      }
    } catch (_) {}
    return const [];
  }

  List<Map<String, dynamic>> get _filtered {
    final q = _searchCtrl.text.trim().toLowerCase();
    final lq = _locationCtrl.text.trim().toLowerCase();
    return _trainers.where((t) {
  // availability guard at view-time as well (defensive)
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

      // experience (string buckets e.g., '0-6','1-3','3-5','5+')
      final expRaw = (t['experience'] ?? '').toString();
      final expBucket = _expBucket(expRaw);
      final okExp = _experience == 'All' || (_experience.isNotEmpty && expBucket == _experience);

    // speciality (from payload and cached API proofs)
    final specsFromPayload = _extractSpecs(t).map((e) => e.toLowerCase().trim());
    final idForSpecs = (t['_id'] ?? t['id'] ?? '').toString();
    final specsFromCache = (_specCache[idForSpecs] ?? const <String>[])
      .map((e) => e.toLowerCase().trim());
    final mergedSpecs = <String>{}
    ..addAll(specsFromPayload)
    ..addAll(specsFromCache);
    final specStr = (t['specialization'] ?? t['speciality'] ?? '').toString();
    final normSel = _norm(_speciality);
    final mergedNorms = mergedSpecs.map(_norm).toList();
    final specNormStr = _norm(specStr);
    final okSpec = _speciality == 'All' ||
      mergedNorms.contains(normSel) ||
      mergedNorms.any((s) => s.contains(normSel) || normSel.contains(s)) ||
      specNormStr.contains(normSel);

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

  // optional: prioritize within 20km first (sorting done in _load), but we still include everyone
  return okSearch && okLocation && okGender && okMode && okExp && okSpec && okFee;
    }).toList();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
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

  String _expDisplay(String v) {
    switch (v) {
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
        return v.isEmpty ? '—' : v;
    }
  }

  // removed old _badge helper (not needed after redesign)

  Widget _specChip(String text) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 1, sigmaY: 1),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          margin: const EdgeInsets.only(right: 8),
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
          child: Text(
            text,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
          ),
        ),
      ),
    );
  }

  Widget _modePill(String mode) {
    final label = mode.toLowerCase() == 'both'
        ? 'Online & Offline Session'
        : '${mode.isNotEmpty ? mode[0].toUpperCase() + mode.substring(1).toLowerCase() : ''} Session';
    return ClipRRect(
      borderRadius: BorderRadius.circular(8), 
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 1, sigmaY: 1),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.16),
                Colors.white.withOpacity(0.06),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withOpacity(0.28), width: 0.75),
          ),
          child: Text(
            label,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
  // final screenWidth = MediaQuery.of(context).size.width; // not needed in new layout
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Find Trainers"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 50,
        leadingWidth: 177,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(width: 20, height: 20),
                visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                onPressed: () => Navigator.pop(context),
                tooltip: 'Back',
              ),
              const SizedBox(width: 4),
              SizedBox(
                width: 125,
                height: 77,
                child: Opacity(
                  opacity: 1,
                  child: Image.asset(
                    'assets/image/fitstreet-bull-logo.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ],
          ),
        ),
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
            child: Container(color: Colors.black.withOpacity(0.15)),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/image/bg.png'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(Colors.black54, BlendMode.darken),
          ),
        ),
        child: Stack(
          children: [
            // removed animated liquid overlay for a static, cleaner background
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
                    flex: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white24),
                      ),
                      height: 44,
                      child: Row(children: [
                        const Icon(Icons.location_on, color: Colors.white70, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _locationCtrl,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              hintText: 'Location',
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
                    flex: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white24),
                      ),
                      height: 44,
                      child: Row(children: [
                        const Icon(Icons.search, color: Colors.white70, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _searchCtrl,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              hintText: 'Search by Name, Trainer Id',
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
              const SizedBox(height: 10),
              // filters row
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
                    // Build speciality options dynamically from loaded trainers and cache
                    Builder(builder: (_) {
                      final set = <String>{};
                      for (final t in _trainers) {
                        for (final s in _extractSpecs(t)) {
                          if (s.trim().isNotEmpty) set.add(s.trim());
                        }
                        final id = (t['_id'] ?? t['id'] ?? '').toString();
                        final cached = _specCache[id];
                        if (cached != null) {
                          for (final s in cached) {
                            if (s.trim().isNotEmpty) set.add(s.trim());
                          }
                        }
                      }
                      final options = ['All', ...set.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()))];
                      return _filterChip('Speciality', _speciality, options, (v) => setState(() => _speciality = v));
                    }),
                    const SizedBox(width: 8),
                    // Reset as a glass chip
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
                            _speciality = 'All';
                            _locationCtrl.clear();
                            _searchCtrl.clear();
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
                            child: const Text('Reset', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // header count
              Builder(builder: (_) {
                final list = _filtered;
                final loc = _locationCtrl.text.trim();
                final city = list.isNotEmpty ? (list.first['city'] ?? '') : '';
                final state = list.isNotEmpty ? (list.first['state'] ?? '') : '';
                final area = loc.isNotEmpty
                    ? loc
                    : [city, state].where((s) => s != null && s.toString().trim().isNotEmpty).join(', ');
        return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
          '${list.length} Trainer${list.length == 1 ? '' : 's'} available ${area.isNotEmpty ? 'in $area' : ''}${_userPos != null ? '  •  sorted by nearest' : ''}',
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                );
              }),
              const SizedBox(height: 10),
              // list
              Expanded(
                child: _filtered.isEmpty
                    ? const Center(child: Text('No trainers match your filters', style: TextStyle(color: Colors.white70)))
                    : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: _filtered.length,
                    itemBuilder: (context, index) {
                      final t = _filtered[index];
                      final name = (t['fullName'] ?? t['name'] ?? 'Trainer').toString();
                      final code = (t['trainerUniqueId'] ?? '').toString();
                      final mode = (t['mode'] ?? '').toString();
                      final city = (t['currentCity'] ?? t['city'] ?? '').toString();
                      final state = (t['currentState'] ?? t['state'] ?? '').toString();
                      final pincode = (t['currentPincode'] ?? t['pincode'] ?? '').toString();
                      final exp = _expDisplay((t['experience'] ?? '').toString());
                      final price1 = (t['oneSessionPrice'] ?? '').toString();
                      final priceM = (t['monthlySessionPrice'] ?? '').toString();
                      final gender = (t['gender'] ?? '').toString().toLowerCase();
                      final id = (t['_id'] ?? t['id'] ?? '').toString();
                      final initialSpecs = _extractSpecs(t);
                      final img = (t['trainerImageURL'] ?? '').toString();
                      final distanceKm = (t['distanceKm'] as num?)?.toDouble();
                      String? distText;
                      if (distanceKm != null) {
                        final rounded = distanceKm < 1
                            ? (distanceKm * 1000).round().toString() + ' m'
                            : distanceKm.toStringAsFixed(distanceKm < 10 ? 1 : 0) + ' km';
                        distText = '$rounded away';
                      }

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: GlassCard(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // top avatar + view profile
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
                                        child: const Text(
                                          'View Profile',
                                          style: TextStyle(decoration: TextDecoration.underline),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 6),
                                // name
                                Text(
                                  code.isNotEmpty ? '$name ($code)' : name,
                                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 8),
                                // specialization chips (from payload, or lazy-fetch from API if missing)
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
                                if (mode.isNotEmpty)
                                  _modePill(mode),
                                const SizedBox(height: 10),
                                // info lines
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
                                    if (distText != null) ...[
                                      const SizedBox(width: 8),
                                      Text(distText, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
                                    ]
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Icon(Icons.access_time, color: Colors.white70, size: 16),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        exp == '—' ? 'Experience not specified' : 'Experience: $exp',
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
                                const SizedBox(height: 6),
                                if (gender.isNotEmpty)
                                  Row(
                                    children: [
                                      const Icon(Icons.person, color: Colors.white70, size: 16),
                                      const SizedBox(width: 6),
                                      Text(gender, style: const TextStyle(color: Colors.white70)),
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


