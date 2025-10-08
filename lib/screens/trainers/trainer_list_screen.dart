import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../widgets/glass_card.dart';
import '../../config/app_colors.dart';
import '../../services/fitstreet_api.dart';
import 'trainer_profile_screen.dart';
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

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(() => setState(() {}));
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
          return isKyc && status.toLowerCase() == 'approved';
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
      } else {
        setState(() => _error = 'Server ${resp.statusCode}');
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
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
    return _trainers.where((t) {
      // search
      final name = (t['fullName'] ?? t['name'] ?? '').toString().toLowerCase();
      final code = (t['trainerUniqueId'] ?? '').toString().toLowerCase();
      final okSearch = q.isEmpty || name.contains(q) || code.contains(q);

      // gender
      final g = (t['gender'] ?? '').toString();
      final okGender = _gender == 'All' || g.toLowerCase() == _gender.toLowerCase();

      // mode
      final m = (t['mode'] ?? '').toString();
      final okMode = _mode == 'All' || m.toLowerCase() == _mode.toLowerCase();

      // experience (string buckets e.g., '0-6','1-3','3-5','5+')
      final exp = (t['experience'] ?? '').toString();
      final okExp = _experience == 'All' || exp == _experience;

      // speciality (best-effort: string field or comma list)
      final spec = (t['specialization'] ?? t['speciality'] ?? '').toString().toLowerCase();
      final okSpec = _speciality == 'All' || spec.contains(_speciality.toLowerCase());

      // fee filter (simple: skip or allow all)
      final okFee = true;

  // optional: prioritize within 20km first (sorting done in _load), but we still include everyone
  return okSearch && okGender && okMode && okExp && okSpec && okFee;
    }).toList();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  Widget _filterChip(String label, String value, List<String> options, void Function(String) onChanged) {
    return PopupMenuButton<String>(
      color: Colors.white,
      onSelected: onChanged,
      itemBuilder: (_) => options
          .map((o) => PopupMenuItem<String>(value: o, child: Text(o)))
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$label', style: const TextStyle(color: Colors.white)),
            const SizedBox(width: 6),
            const Icon(Icons.keyboard_arrow_down, color: Colors.white70, size: 18),
          ],
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E88E5).withOpacity(0.9),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }

  Widget _modePill(String mode) {
    Color bg;
    switch (mode.toLowerCase()) {
      case 'offline':
        bg = const Color(0xFF29B770); // green
        break;
      case 'online':
        bg = const Color(0xFF5C6BC0); // indigo
        break;
      case 'both':
        bg = const Color(0xFFAB47BC); // purple
        break;
      default:
        bg = Colors.white.withOpacity(0.15);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        mode.toLowerCase() == 'both'
            ? 'Online & Offline Session'
            : '${mode.isNotEmpty ? mode[0].toUpperCase() + mode.substring(1).toLowerCase() : ''} Session',
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
  // final screenWidth = MediaQuery.of(context).size.width; // not needed in new layout
    return Scaffold(
      appBar: AppBar(
        title: const Text("Find Trainers"),
        backgroundColor: Colors.transparent,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primary, AppColors.secondary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(child: Text(_error!, style: const TextStyle(color: Colors.white)))
            : Padding(
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
                    _filterChip('Fee', _fee, const ['All'], (v) => setState(() => _fee = v)),
                    const SizedBox(width: 8),
                    _filterChip('Speciality', _speciality, const ['All','Yoga','Strength','Rehab'], (v) => setState(() => _speciality = v)),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => setState(() {
                        _gender = 'All';
                        _experience = 'All';
                        _mode = 'All';
                        _fee = 'All';
                        _speciality = 'All';
                        _searchCtrl.clear();
                      }),
                      child: const Text('Reset'),
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
                      final city = (t['city'] ?? '').toString();
                      final state = (t['state'] ?? '').toString();
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
                                        [city, state].where((e) => e.trim().isNotEmpty).join(', '),
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
                                        exp == '—' ? 'Experience overall: —' : '$exp experience overall',
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
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Booking flow coming soon')));
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
    );
  }
}


