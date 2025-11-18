import 'dart:convert';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/fitstreet_api.dart';
import '../../widgets/glass_card.dart';
import '../trainers/trainer_profile_screen.dart';

// Grouped specializations as provided
const Map<String, List<String>> kGroupedSpecializations = {
  'Fitness Training': [
    'Strength Training',
    'HIIT',
    'CrossFit',
    'Functional Training',
    'Cardio',
    'Aerobics',
    'Zumba',
    'Strength and Conditioning',
    'Endurance Training',
    'Circuit Training',
    'Dance Fitness',
  ],
  'Body Transformation': [
    'Weight Loss',
    'Weight Gain',
    'Bodybuilding',
    'Muscle Gain Expert',
    'Body Transformation',
    'Female Fitness',
    'Physique Enhancement Specialist',
  ],
  'Health & Rehabilitation': [
    'Rehabilitation Trainer',
    'Pain Management',
    'Injury Prevention',
    'Posture Correction',
    'Lifestyle Disorders',
    'Stretching Specialist',
    'Mobility & Flexibility Coach',
    'Physical Therapist Support',
  ],
  'Yoga & Meditation': [
    'Yoga',
    'Hatha Yoga',
    'Vinyasa Yoga',
    'Prenatal Yoga',
    'Postnatal Yoga',
    'Recreational Yoga',
    'Meditation',
    'Breathwork & Pranayama',
    'Sound Healing',
    'Mindfulness Trainer',
  ],
  'Specialized Fitness': [
    'Pilates Instructor',
    'Calisthenics Coach',
    'Core Strength Trainer',
    'Balance & Stability Training',
    'Sports Performance Coach',
  ],
  'Nutrition & Diet Planning': [
    'Nutrition',
    'Sports Nutritionist',
    //'Clinical Nutritionist',
    'Weight Management Expert',
    'Diet Planning Specialist',
    'Holistic Nutrition Coach',
  ],
  'Mental Health & Counseling': [
    'Counselors',
    'Mental Counselor',
    'Psychologist',
    'Depression Support',
    'Stress Management',
    'Art Therapy',
    'Suicide Prevention',
    'Psychological First Aid',
    'Solution-Focused Brief Therapy',
    'Career Counseling',
    'Neuro-Linguistic Programming',
    'Relationship Therapist',
    'Martial Discord',
    'Reproductive Health Counselor',
  ],
  'Sports & Athletics': [
    'Cricket Coach',
    'Boxing Coach',
    'Martial Arts Instructor',
    'Football Trainer',
    'Tennis Coach',
    'Badminton Coach',
    'Athletic Performance Trainer',
  ],
};

/// FindTrainersScreen
/// A Flutter port of the Angular FindTrainers component provided.
/// It supports filters, near-by lookup with geolocation, slot selection for
/// single and monthly sessions, and navigation to BookSessionScreen.
class FindTrainersScreen extends StatefulWidget {
  final String? initialCategory; // maps to Angular `category` query param
  final String? initialName; // maps to Angular `name` query param

  const FindTrainersScreen({super.key, this.initialCategory, this.initialName});

  @override
  State<FindTrainersScreen> createState() => _FindTrainersScreenState();
}

class _FindTrainersScreenState extends State<FindTrainersScreen> {
  // Loading & error state
  bool _loading = true;
  String? _error;

  // Filters/controllers
  final TextEditingController _locationCtrl = TextEditingController();
  final TextEditingController _nameCtrl = TextEditingController();
  String _gender = '';
  String _mode = '';
  String _experience = '';
  String _fee = '';
  String _speciality = '';

  // Location
  Position? _userPos;
  String locationCity = '';

  // Data
  List<Map<String, dynamic>> _trainers = [];

  // Logged in user info (derived from shared prefs)
  // auth flags no longer used in this screen after redirecting to profile

  // Session selection state (per trainer)
  // Removed slot/booking state as we navigate to TrainerProfile for booking
  // Slots expansion state removed as Book Session navigates directly to profile
  // Specialization cache + expanded chips tracking
  final Map<String, List<String>> _specCache = {};
  final Set<String> _expandedTrainers = {};

  // Experience dropdown buckets (mapped to API expected strings)
  static const List<String> _experienceOptions = <String>[
    '',
    '0-6 months',
    '6 months - 1 year',
    '1-3 years',
    '3-5 years',
    '5+ years',
  ];

  // Fee buckets expected by backend
  static const List<String> _feeOptions = <String>[
    '',
    '0-500',
    '500-1000',
    '1000-2000',
    '2000-5000',
    '5000+',
  ];

  @override
  void initState() {
    super.initState();
    // Prefill from constructor (like Angular query params)
    if (widget.initialName?.trim().isNotEmpty == true) {
      _nameCtrl.text = widget.initialName!.trim();
    }
    if (widget.initialCategory?.trim().isNotEmpty == true) {
      _speciality = widget.initialCategory!.trim();
    }
    _boot();
  }

  @override
  void dispose() {
    _locationCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _boot() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
  // auth (not used here anymore)

      // location permission
      final hasService = await Geolocator.isLocationServiceEnabled();
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (hasService && (perm == LocationPermission.always || perm == LocationPermission.whileInUse)) {
        _userPos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
        await _reverseGeocodeCity(_userPos!.latitude, _userPos!.longitude);
      }

      await _getTrainers();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reverseGeocodeCity(double lat, double lng) async {
    try {
      final uri = Uri.parse('https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng');
      final res = await http.get(uri, headers: const {
        'User-Agent': 'fitstreet-mobile/1.0 (Flutter)'
      });
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final addr = body['address'] ?? {};
        final city = (addr['city'] ?? addr['town'] ?? addr['village'] ?? addr['state_district'] ?? addr['state'] ?? '')
            .toString();
        if (city.isNotEmpty) {
          locationCity = city;
          // don't overwrite user-entered location text; use as default only
          if (_locationCtrl.text.trim().isEmpty) {
            // keep input empty but use city for API call
          }
        }
      }
    } catch (_) {}
  }

  // Fetch trainers from backend with filters
  Future<void> _getTrainers() async {
    setState(() => _loading = true);
    try {
  final sp = await SharedPreferences.getInstance();
      final token = sp.getString('fitstreet_token') ?? '';
      final api = FitstreetApi('https://api.fitstreet.in', token: token);

      final city = _locationCtrl.text.trim().isNotEmpty ? _locationCtrl.text.trim() : (locationCity.isNotEmpty ? locationCity : 'Ghaziabad');
      final name = _nameCtrl.text.trim().isNotEmpty ? _nameCtrl.text.trim() : null;
      final resp = await api.getNearbyTrainers(
        city: city,
        lat: _userPos?.latitude.toString(),
        lng: _userPos?.longitude.toString(),
        specialization: _speciality.isNotEmpty ? _speciality : null,
        page: 1,
        limit: 100,
        gender: _gender.isNotEmpty ? _gender : null,
        experience: _experience.isNotEmpty ? _experience : null,
        mode: _mode.isNotEmpty ? _mode : null,
        fee: _fee.isNotEmpty ? _fee : null,
        name: name,
      );

      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        List list;
        if (body is Map) {
          if (body['trainers'] is List) {
            list = body['trainers'];
          } else if (body['data'] is List) {
            list = body['data'];
          } else {
            list = (body['items'] as List?) ?? [];
          }
        } else if (body is List) {
          list = body;
        } else {
          list = const [];
        }
        final mapped = list
            .whereType<Map>()
            .map((m) => m.map((k, v) => MapEntry(k.toString(), v)))
            .cast<Map<String, dynamic>>()
            .toList();

        // compute distance if we have user position
        if (_userPos != null) {
          for (final t in mapped) {
            final lat = double.tryParse((t['latitude'] ?? t['lat'] ?? '').toString());
            final lng = double.tryParse((t['longitude'] ?? t['lng'] ?? t['long'] ?? '').toString());
            if (lat != null && lng != null) {
              final dMeters = Geolocator.distanceBetween(_userPos!.latitude, _userPos!.longitude, lat, lng);
              t['distanceKm'] = (dMeters / 1000.0);
            }
          }
          mapped.sort((a, b) {
            final da = (a['distanceKm'] as num?)?.toDouble();
            final db = (b['distanceKm'] as num?)?.toDouble();
            if (da == null && db == null) return 0;
            if (da == null) return 1;
            if (db == null) return -1;
            return da.compareTo(db);
          });
        }

        if (mounted) setState(() => _trainers = mapped);
      } else {
        if (mounted) setState(() => _error = 'Failed to fetch (${resp.statusCode})');
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // UI helpers
  String _expDisplay(String v) {
    final s = v.toLowerCase();
    if (s.contains('0-6')) return '0-6 months';
    if (s.contains('6') && s.contains('1')) return '6 months - 1 year';
    if (s.contains('1-3')) return '1-3 years';
    if (s.contains('3-5')) return '3-5 years';
    if (s.contains('5+')) return '5+ years';
    return v;
  }

  // Extract specialization strings from a trainer map (similar to trainer_list_screen)
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
        .map((e) => (e is Map ? (e['specialization'] ?? e['name'] ?? '') : e).toString())
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (fromProofs.isNotEmpty) {
      final seen = <String>{};
      return fromProofs.where((e) => seen.add(e.toLowerCase())).toList();
    }
    return const [];
  }

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

  List<Map<String, dynamic>> get _filtered => _trainers; // server-side filtered

  // Slot/day helpers and booking confirmation removed as booking is handled in profile page

  // _formatDate and _idOf removed as not used

  // _toggleSlots removed as Book Session now navigates to profile directly.

  // _pickMonthlyStartDate and _modePill removed as not used in current flow

  @override
  Widget build(BuildContext context) {
    final categoryParam = widget.initialCategory ?? '';
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('Find ${categoryParam.isEmpty ? 'Trainers' : categoryParam}${categoryParam != 'Yoga' && categoryParam.isNotEmpty ? 's' : ''}'),
        backgroundColor: Colors.transparent,
        elevation: 0,
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
            image: AssetImage('assets/image/trainer-bg.png'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(Colors.black54, BlendMode.darken),
          ),
        ),
    child: _loading
      ? const Center(child: CircularProgressIndicator())
      : (_error != null && _error!.isNotEmpty)
        ? Center(child: Text(_error!, style: const TextStyle(color: Colors.white)))
        : SafeArea(
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
                                    onChanged: (_) => _getTrainers(),
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
                                    controller: _nameCtrl,
                                    style: const TextStyle(color: Colors.white),
                                    decoration: const InputDecoration(
                                      hintText: 'Search by Name, Trainer Id',
                                      hintStyle: TextStyle(color: Colors.white54),
                                      border: InputBorder.none,
                                    ),
                                    onSubmitted: (_) => _getTrainers(),
                                  ),
                                ),
                              ]),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Filters row
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _DropdownFilter<String>(
                              label: _gender.isEmpty ? 'Gender' : _gender,
                              items: const ['', 'Male', 'Female'],
                              onSelected: (v) => setState(() { _gender = v ?? ''; _getTrainers(); }),
                            ),
                            const SizedBox(width: 8),
                            _DropdownFilter<String>(
                              label: _experience.isEmpty ? 'Experience' : _experience,
                              items: _experienceOptions,
                              onSelected: (v) => setState(() { _experience = v ?? ''; _getTrainers(); }),
                            ),
                            const SizedBox(width: 8),
                            _DropdownFilter<String>(
                              label: _mode.isEmpty ? 'Mode' : _mode,
                              items: const ['', 'Online', 'Offline', 'Both'],
                              onSelected: (v) => setState(() { _mode = v ?? ''; _getTrainers(); }),
                            ),
                            const SizedBox(width: 8),
                            _DropdownFilter<String>(
                              label: _fee.isEmpty ? 'Fee' : _fee,
                              items: _feeOptions,
                              onSelected: (v) => setState(() { _fee = v ?? ''; _getTrainers(); }),
                            ),
                            const SizedBox(width: 8),
                            // Speciality: grouped picker
                            _SpecializationFilterButton(
                              label: _speciality.isEmpty ? 'Speciality' : _speciality,
                              onSelected: (spec) {
                                setState(() {
                                  _speciality = spec;
                                });
                                _getTrainers();
                              },
                            ),
                            const SizedBox(width: 8),
                            // Reset
                            ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                child: InkWell(
                                  onTap: () {
                                    setState(() {
                                      _gender = '';
                                      _mode = '';
                                      _experience = '';
                                      _fee = '';
                                      _speciality = '';
                                      _nameCtrl.clear();
                                      _locationCtrl.clear();
                                    });
                                    _getTrainers();
                                  },
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

                      Text(
                        '${_filtered.length} Trainers available in ${_locationCtrl.text.trim().isNotEmpty ? _locationCtrl.text.trim() : (locationCity.isNotEmpty ? locationCity : 'your area')}',
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),

                      Expanded(
                        child: _filtered.isEmpty
                            ? const Center(child: Text('No trainers found for selected filters.', style: TextStyle(color: Colors.white70)))
                            : RefreshIndicator(
                                onRefresh: _getTrainers,
                                child: ListView.builder(
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  itemCount: _filtered.length,
                                  itemBuilder: (context, index) {
                                    final t = _filtered[index];
                                    final name = (t['fullName'] ?? t['name'] ?? '').toString();
                                    final code = (t['trainerUniqueId'] ?? '').toString();
                                    final img = (t['trainerImageURL'] ?? '').toString();
                                    final mode = (t['mode'] ?? '').toString();
                                    final city = (t['currentCity'] ?? t['city'] ?? '').toString();
                                    final state = (t['currentState'] ?? t['state'] ?? '').toString();
                                    final exp = _expDisplay((t['experience'] ?? '').toString());
                                    final priceOne = (t['oneSessionPrice'] ?? '').toString();
                                    final priceMonth = (t['monthlySessionPrice'] ?? '').toString();
                                    final distanceKm = (t['distanceKm'] as num?)?.toDouble();
                                    final pincode = (t['currentPincode'] ?? t['pincode'] ?? '').toString();
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
                                          padding: const EdgeInsets.all(13),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  // Profile Image with Specialization Badge
                                                  Column(
                                                    children: [
                                                      Stack(
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
                                                        ],
                                                      ),
                                                      const SizedBox(height: 4),
                                                      // View Profile Button - Now below the image with better visibility
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
                                                                  color: Color(0xFFFFFFFF),
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
                                                          final id = (t['_id'] ?? t['id'] ?? '').toString();
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
                                                                    color: Colors.orange[550],
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
                                                                  onTap: () => setState(() => _expandedTrainers.add(id)),
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
                                                              if (isExpanded && hasMore)
                                                                GestureDetector(
                                                                  onTap: () => setState(() => _expandedTrainers.remove(id)),
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
                                                            [city, state, pincode]
                                                                .where((e) => e.toString().trim().isNotEmpty)
                                                                .join(', '),
                                                            style: const TextStyle(color: Colors.black, fontSize: 13, fontWeight: FontWeight.bold),
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                        ),
                                                        if (distText != null)
                                                          Text(distText, style: const TextStyle(color: Colors.black, fontSize: 13, fontWeight: FontWeight.bold)),
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
                                                            '${priceOne.isNotEmpty ? '$priceOne/ session' : ''}${priceOne.isNotEmpty && priceMonth.isNotEmpty ? ' and ' : ''}${priceMonth.isNotEmpty ? '$priceMonth monthly session' : ''}',
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
                                                    borderRadius: BorderRadius.circular(70),
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

                                                    child: const Text(
                                                      'Book Session',
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 15,
                                                        fontWeight: FontWeight.bold,
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
      ),
    );
  }
}

/// Small glassy dropdown chip used for filters
class _DropdownFilter<T> extends StatelessWidget {
  final String label;
  final List<T> items;
  final void Function(T?) onSelected;

  const _DropdownFilter({
    required this.label,
    required this.items,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<T>(
      onSelected: onSelected,
      color: Colors.black87,
      itemBuilder: (ctx) => [
        for (final it in items)
          PopupMenuItem<T>(
            value: it,
            child: Text(it.toString().isEmpty ? 'All' : it.toString(), style: const TextStyle(color: Colors.white)),
          )
      ],
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
              children: [
                Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                const SizedBox(width: 6),
                const Icon(Icons.keyboard_arrow_down, color: Colors.white70, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Button that opens a bottom sheet with grouped specializations to pick one
class _SpecializationFilterButton extends StatelessWidget {
  final String label;
  final ValueChanged<String> onSelected;

  const _SpecializationFilterButton({required this.label, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: GestureDetector(
        onTap: () => _openPicker(context),
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

  void _openPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black87,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Container(
            constraints: const BoxConstraints(maxHeight: 500),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text('Select Specialization', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView(
                    children: [
                      for (final entry in kGroupedSpecializations.entries)
                        Theme(
                          data: Theme.of(ctx).copyWith(dividerColor: Colors.white24),
                          child: ExpansionTile(
                            initiallyExpanded: false,
                            title: Text(entry.key, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                            childrenPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            children: [
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final spec in entry.value)
                                    GestureDetector(
                                      onTap: () {
                                        Navigator.pop(ctx);
                                        onSelected(spec);
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(color: Colors.white24),
                                        ),
                                        child: Text(spec, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
                                      ),
                                    ),
                                ],
                              )
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      onSelected('');
                    },
                    child: const Text('Clear', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
