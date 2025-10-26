import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/fitstreet_api.dart';
import '../../screens/trainers/trainer_profile_screen.dart';

class FeaturedTrainersSection extends StatefulWidget {
  const FeaturedTrainersSection({super.key});

  @override
  State<FeaturedTrainersSection> createState() => _FeaturedTrainersSectionState();
}

class _FeaturedTrainersSectionState extends State<FeaturedTrainersSection> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];
  // cache fetched specialisations per-trainer id
  final Map<String, List<String>> _specCache = {};

  @override
  void initState() {
    super.initState();
    _load();
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
        final parsed = jsonDecode(resp.body);
        final rawList = (parsed is Map && parsed['data'] is List)
            ? (parsed['data'] as List)
            : (parsed is List ? parsed : []);
        final items = <Map<String, dynamic>>[];
        for (final e in rawList) {
          if (e is Map) {
            final m = <String, dynamic>{};
            e.forEach((k, v) {
              final sk = k?.toString() ?? '';
              if (sk.isNotEmpty) m[sk] = v;
            });
            items.add(m);
          }
        }
        final filtered = items.where((t) {
          final isKyc = (t['isKyc'] ?? false).toString().toLowerCase() == 'true' || t['isKyc'] == true;
          final status = (t['status'] ?? '').toString().toLowerCase();
          final availRaw = t['isAvailable'];
          final isAvailable = !(availRaw == false || (availRaw is String && availRaw.toLowerCase() == 'false'));
          return isKyc && status == 'approved' && isAvailable;
        }).toList();
        filtered.sort((a, b) {
          num ra = (a['rating'] ?? a['avgRating'] ?? 0) is num ? (a['rating'] ?? a['avgRating'] ?? 0) as num : num.tryParse((a['rating'] ?? a['avgRating'] ?? '0').toString()) ?? 0;
          num rb = (b['rating'] ?? b['avgRating'] ?? 0) is num ? (b['rating'] ?? b['avgRating'] ?? 0) as num : num.tryParse((b['rating'] ?? b['avgRating'] ?? '0').toString()) ?? 0;
          num ca = (a['reviewCount'] ?? a['ratingCount'] ?? 0) is num ? (a['reviewCount'] ?? a['ratingCount'] ?? 0) as num : num.tryParse((a['reviewCount'] ?? a['ratingCount'] ?? '0').toString()) ?? 0;
          num cb = (b['reviewCount'] ?? b['ratingCount'] ?? 0) is num ? (b['reviewCount'] ?? b['ratingCount'] ?? 0) as num : num.tryParse((b['reviewCount'] ?? b['ratingCount'] ?? '0').toString()) ?? 0;
          final s = rb.compareTo(ra);
          if (s != 0) return s;
          return cb.compareTo(ca);
        });
        if (mounted) setState(() => _items = filtered.take(10).toList());
      } else {
        setState(() => _error = 'Server ${resp.statusCode}');
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // helper: safe string
  String _s(dynamic v) => (v == null || (v is String && v.toLowerCase() == 'null')) ? '' : v.toString();

  // Extract a list of specialisations from multiple possible shapes/keys
  List<String> _specs(Map<String, dynamic> t) {
    final out = <String>[];
    void addOne(dynamic v) {
      if (v == null) return;
      if (v is Map) {
        final cand = _s(v['specialization'] ?? v['name'] ?? v['title'] ?? v['label'] ?? v['value']);
        if (cand.isNotEmpty) out.add(cand.trim());
      } else {
        final s = _s(v).trim();
        if (s.isNotEmpty) out.add(s);
      }
    }

    // Top-level variants
    final candidates = [
      t['specializationList'],
      t['specializations'],
      t['specialization'],
      t['speciality'],
    ];
    for (final c in candidates) {
      if (c == null) continue;
      if (c is List) {
        for (final e in c) addOne(e);
      } else {
        // comma-separated string
        final s = _s(c);
        if (s.contains(',')) {
          out.addAll(s.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty));
        } else {
          addOne(s);
        }
      }
    }

    // Proofs-based variants
    final proofs = t['trainerSpecializationProof'] ?? t['trainerSpecializationProofs'] ?? t['specializationProofs'] ?? t['proofs'];
    if (proofs is List) {
      for (final p in proofs) addOne(p);
    }

    // Dedupe (case-insensitive) preserving order
    final seen = <String>{};
    return out.where((e) => seen.add(e.toLowerCase())).toList();
  }

  // Fetch specialisations for a trainer id (from proofs) and cache
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
            .map((e) => (e is Map ? _s(e['specialization'] ?? e['name'] ?? e['title'] ?? e['label'] ?? e['value']) : _s(e)))
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
        // dedupe case-insensitive
        final seen = <String>{};
        final out = specs.where((e) => seen.add(e.toLowerCase())).toList();
        _specCache[trainerId] = out;
        return out;
      }
    } catch (_) {}
    return const [];
  }

  // Parse first specialization from a variety of fields
  String _firstSpec(Map<String, dynamic> t) {
    final specs = _specs(t);
    return specs.isNotEmpty ? specs.first : '';
  }

  // build chip used in overlay (small pill)
  Widget _overlayChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      margin: const EdgeInsets.only(top: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24, width: 0.5),
      ),
      child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  Widget _skeletonCard() {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Container(
        width: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white24, width: 0.75),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.white12,
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _fallbackCard(BuildContext context, String name, String speciality, String price) {
    final trainer = {"name": name, "speciality": speciality, "price": price};
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => TrainerProfileScreen(trainer: trainer)));
        },
        child: Container(
          width: 200,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white24, width: 0.75),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(color: Colors.white24),
                    if (price.isNotEmpty)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.55),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white24, width: 0.75),
                          ),
                          child: Text(price, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                        ),
                      ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                            if (speciality.isNotEmpty)
                              Text(speciality, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                      ),
                    )
                  ],
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _itemCard(BuildContext context, Map<String, dynamic> t) {
    final name = _s(t['fullName']).isNotEmpty ? _s(t['fullName']) : (_s(t['name']).isNotEmpty ? _s(t['name']) : 'Trainer');

    // specializations (first)
    final spec = _firstSpec(t);
  final id = _s(t['_id']).isNotEmpty ? _s(t['_id']) : _s(t['id']);

    // fee: try many keys, strip non-numeric
    dynamic feeRaw;
    for (final key in const ['sessionFee','perSessionFee','singleSessionFee','fee','fees','price','monthlyFee','singleSessionPrice','oneSessionPrice']) {
      if (_s(t[key]).isNotEmpty) { feeRaw = t[key]; break; }
    }
    final fee = _s(feeRaw).replaceAll(RegExp(r'[^0-9.]'), '');
    final price = fee.isNotEmpty ? '₹$fee' : (_s(t['price']).isNotEmpty ? _s(t['price']) : '');

    // image
    final img = _s(t['trainerImageURL']).isNotEmpty ? _s(t['trainerImageURL']) : _s(t['image']);

  // small list of spec chips (first two)
  final specList = _specs(t);

    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => TrainerProfileScreen(trainer: t)));
        },
        child: Container(
          width: 300,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white24, width: 0.75),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // background image
                    (img.isNotEmpty)
                        ? Image.network(
                            img,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Image.asset('assets/image/fitstreet-bull-logo.png', fit: BoxFit.cover),
                          )
                        : Image.asset('assets/image/fitstreet-bull-logo.png', fit: BoxFit.cover),

                    // price badge top-right
                    if (price.isNotEmpty)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.55),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white24, width: 0.75),
                          ),
                          child: Text(price, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                        ),
                      ),

                    // bottom gradient overlay with name & spec + small chips
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black.withOpacity(0.75)],
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                            if (spec.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text(spec, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                              ),
                            if (specList.isNotEmpty)
                              Row(
                                children: specList.take(2).map((s) => Padding(padding: const EdgeInsets.only(right: 8), child: _overlayChip(s))).toList(),
                              )
                            else if (id.isNotEmpty)
                              FutureBuilder<List<String>>(
                                future: _fetchSpecsFor(id),
                                builder: (ctx, snap) {
                                  final fetched = snap.data ?? const [];
                                  if (fetched.isEmpty) return const SizedBox.shrink();
                                  return Row(
                                    children: fetched.take(2).map((s) => Padding(padding: const EdgeInsets.only(right: 8), child: _overlayChip(s))).toList(),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("🔥 Featured Trainers", style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 12),
        SizedBox(
          height: 300, // increased height so the image cards appear taller (matches screenshot)
          child: _loading
              ? ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemBuilder: (_, i) => _skeletonCard(),
                  separatorBuilder: (_, __) => const SizedBox(width: 16),
                  itemCount: 3,
                )
              : (_error != null || _items.isEmpty)
                  ? ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _fallbackCard(context, "Rahul Sharma", "Yoga", "₹500"),
                        _fallbackCard(context, "Sneha Kapoor", "Strength", "₹700"),
                        _fallbackCard(context, "Amit Singh", "Zumba", "₹600"),
                      ],
                    )
                  : ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemBuilder: (_, i) => _itemCard(context, _items[i]),
                      separatorBuilder: (_, __) => const SizedBox(width: 1),
                      itemCount: _items.length,
                    ),
        ),
      ],
    );
  }
}
