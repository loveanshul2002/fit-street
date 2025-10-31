// circular_home_screen.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/fitstreet_api.dart';
import '../trainers/trainer_profile_screen.dart';
import '../trainers/trainer_list_screen.dart';

class CircularHomeScreen extends StatefulWidget {
  final bool embedded; // if true, render only the chart body (no Scaffold/bg)
  const CircularHomeScreen({super.key, this.embedded = false});

  @override
  State<CircularHomeScreen> createState() => _CircularHomeScreenState();
}

class _CircularHomeScreenState extends State<CircularHomeScreen>
    with SingleTickerProviderStateMixin {
  int? selectedIndex;
  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> _eligible = [];
  final Map<String, List<String>> _specCache = {};
  final Map<int, List<Map<String, dynamic>>> _categoryCache = {};
  int _animTick = 0;
  late final AnimationController _outerAnim;

  @override
  void initState() {
    super.initState();
    _outerAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _load();
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
          .where((e) => e.isNotEmpty && e.toLowerCase() != 'null')
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
        .map((e) =>
            (e is Map ? (e['specialization'] ?? e['name'] ?? '').toString() : e.toString()))
        .where((s) => s.trim().isNotEmpty)
        .map((s) => s.trim())
        .toList();
    if (fromProofs.isNotEmpty) {
      final seen = <String>{};
      return fromProofs.where((e) => seen.add(e.toLowerCase())).toList();
    }
    return const [];
  }

  bool _isFitness(List<String> specs) {
    if (specs.isEmpty) return false;
    final norms = specs.map(_norm).toList();
    const keys = [
      'fitness',
      'fitness trainer',
      'personal trainer',
      'gym trainer',
      'strength',
      'strength training',
      'bodybuilding',
      'weight training',
      'crossfit',
      'calisthenics',
      'workout coach',
      'fitness coach'
    ];
    return norms.any((s) => keys.any((k) => s.contains(k)));
  }

  bool _isNutrition(List<String> specs) {
    if (specs.isEmpty) return false;
    final norms = specs.map(_norm).toList();
    const keys = [
      'nutrition',
      'nutritionist',
      'nutritionists',
      'diet',
      'dietitian',
      'dietician',
      'dietitians',
      'dieticians',
      'diet planning',
      'diet plan',
      'meal plan',
      'meal planning'
    ];
    return norms.any((s) => keys.any((k) => s.contains(k)));
  }

  bool _isYoga(List<String> specs) {
    if (specs.isEmpty) return false;
    final norms = specs.map(_norm).toList();
    const keys = [
      'yoga',
      'yogi',
      'yogasana',
      'asanas',
      'asana',
      'pranayama',
      'hatha',
      'ashtanga',
      'vinyasa',
      'kundalini'
    ];
    return norms.any((s) => keys.any((k) => s.contains(k)));
  }

  bool _isCounsellor(List<String> specs) {
    if (specs.isEmpty) return false;
    final norms = specs.map(_norm).toList();
    const keys = [
      'counsellor',
      'counsellors',
      'counselor',
      'counselors',
      'counselling',
      'counseling',
      'psychologist',
      'psychologists',
      'therapist',
      'therapists',
      'mental health',
      'mental wellness',
      'psychotherapy',
      'psychological'
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
            .map((e) =>
                (e is Map ? (e['specialization'] ?? e['name'] ?? '').toString() : e.toString()))
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
        final base = list
            .whereType<Map>()
            .map((m) => m.map((k, v) => MapEntry(k.toString(), v)))
            .cast<Map<String, dynamic>>()
            .toList();

        final eligible = base.where((t) {
          final isKyc = (t['isKyc'] ?? false).toString().toLowerCase() == 'true' || t['isKyc'] == true;
          final status = (t['status'] ?? '').toString().trim().toLowerCase();
          final availRaw = t['isAvailable'];
          final isAvailable = !(availRaw == false || (availRaw is String && availRaw.toLowerCase() == 'false'));
          return isKyc && status == 'approved' && isAvailable;
        }).toList();

        setState(() => _eligible = eligible);
      } else {
        setState(() => _error = 'Server ${resp.statusCode}');
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<List<Map<String, dynamic>>> _resolveCategory(int idx) async {
    if (_categoryCache.containsKey(idx)) return _categoryCache[idx]!;
    bool Function(List<String>) predicate;
    switch (idx) {
      case 0:
        predicate = _isFitness;
        break;
      case 1:
        predicate = _isNutrition;
        break;
      case 2:
        predicate = _isYoga;
        break;
      default:
        predicate = _isCounsellor;
    }

    final payloadMatches = _eligible.where((t) => predicate(_extractSpecs(t))).toList();
    final results = <Map<String, dynamic>>[]..addAll(payloadMatches.take(5));
    if (results.length >= 5) {
      _categoryCache[idx] = results;
      return results;
    }

    final unknown = _eligible.where((t) => !predicate(_extractSpecs(t))).toList();
    for (final t in unknown) {
      if (results.length >= 5) break;
      final id = (t['_id'] ?? t['id'] ?? '').toString();
      if (id.isEmpty) continue;
      final specs = await _fetchSpecsFor(id);
      if (predicate(specs)) results.add(t);
    }

    _categoryCache[idx] = results;
    return results;
  }

  void _onInnerTap(int idx) async {
    setState(() => selectedIndex = null);
    await Future.delayed(const Duration(milliseconds: 80));
    if (!mounted) return;
    setState(() {
      selectedIndex = idx;
      _animTick++;
    });

    _outerAnim
      ..stop()
      ..reset()
      ..forward();
  }

  Future<void> _launchSOS() async {
    final Uri telUri = Uri(scheme: 'tel', path: '112');
    if (await canLaunchUrl(telUri)) {
      await launchUrl(telUri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final innerData = const [
      _Slice('Fitness'),
      _Slice('Nutrition'),
      _Slice('Yoga'),
      _Slice('Counsellor'),
    ];

    Widget chartContent() {
      return FutureBuilder<List<Map<String, dynamic>>>(
        future: selectedIndex == null ? Future.value(const []) : _resolveCategory(selectedIndex!),
        builder: (context, snap) {
          final selectedTrainers = snap.data ?? const [];
          final outerCount = 5;
          return SizedBox(
            height: 420,
            width: 420,
            child: AnimatedBuilder(
              animation: _outerAnim,
              builder: (context, _) {
                final sweep = Tween<double>(begin: 0, end: 180).evaluate(CurvedAnimation(parent: _outerAnim, curve: Curves.easeOutCubic));
                final rotation = Tween<double>(begin: -6, end: 0).evaluate(CurvedAnimation(parent: _outerAnim, curve: Curves.easeOut));
                return Transform.rotate(
                  angle: rotation * 0.0174533, // degrees -> radians
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SfCircularChart(
                        key: ValueKey('circ-${selectedIndex ?? -1}-$_animTick'),
                        margin: EdgeInsets.zero,
                        series: <CircularSeries>[
                          DoughnutSeries<_Slice, String>(
                            dataSource: innerData,
                            xValueMapper: (d, _) => d.label,
                            yValueMapper: (_, __) => 1,
                            innerRadius: '34%',
                            radius: '55%',
                            animationDuration: 600,
                            strokeWidth: 2,
                            strokeColor: Colors.black26,
                            pointColorMapper: (d, i) {
                              if (i == selectedIndex) return Colors.white70;
                              return Colors.white24;
                            },
                            onPointTap: (details) => _onInnerTap(details.pointIndex!),
                          ),

                          if (selectedIndex != null)
                            (() {
                              final outerData = <_OuterPoint>[];
                              final trainersToShow = selectedTrainers.take(4).toList();
                              for (var i = 0; i < trainersToShow.length; i++) {
                                outerData.add(_OuterPoint('T${i + 1}', trainersToShow[i]));
                              }
                              for (var i = trainersToShow.length; i < 4; i++) {
                                outerData.add(_OuterPoint('P${i + 1}', {
                                  '_placeholder': true,
                                }));
                              }
                              outerData.add(_OuterPoint('more', {
                                '_viewAll': true,
                                'total': selectedTrainers.length,
                                'label': 'View all',
                              }));

                              return DoughnutSeries<_OuterPoint, String>(
                                dataSource: outerData,
                                xValueMapper: (d, _) => d.label,
                                yValueMapper: (_, __) => 1,
                                startAngle: 210,
                                endAngle: 210 ,
                                innerRadius: '60%',
                                radius: '92%',
                                animationDuration: 0,
                                strokeWidth: 2,
                                strokeColor: Colors.black26,
                                pointColorMapper: (_, __) => const Color(0x20FFFFFF),
                                onPointTap: (details) {
                                  final idx = details.pointIndex ?? -1;
                                  if (idx < 0 || idx >= outerData.length) return;
                                  final t = outerData[idx].trainer;
                                  if (t['_viewAll'] == true) {
                                    Navigator.push(context, MaterialPageRoute(builder: (_) => const TrainerListScreen()));
                                    return;
                                  }
                                  if (t['_placeholder'] == true) {
                                    return;
                                  }
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
                                dataLabelSettings: DataLabelSettings(
                                  isVisible: true,
                                  labelPosition: ChartDataLabelPosition.inside,
                                  builder: (dynamic data, dynamic point, dynamic series, int pointIndex, int seriesIndex) {
                                    final t = (data as _OuterPoint).trainer;
                                    if (t['_viewAll'] == true) {
                                      final appear = (_outerAnim.value - 0.7).clamp(0.0, 1.0);
                                      return _animatedViewAll(appear);
                                    }
                                    if (t['_placeholder'] == true) {
                                      final appear = (_outerAnim.value - (0.2 + (pointIndex * 0.08))).clamp(0.0, 1.0);
                                      return _animatedPlaceholder(appear);
                                    }

                                    final img = (
                                        t['trainerImageURL'] ??
                                            t['imageURL'] ??
                                            t['profileImageURL'] ??
                                            t['userImageURL'] ??
                                            ''
                                    ).toString().trim();
                                    final name = (t['fullName'] ?? t['name'] ?? '').toString();

                                    // compute staggered appearance per index
                                    final baseDelay = 0.18;
                                    final step = 0.10;
                                    final appear = (_outerAnim.value - (baseDelay + pointIndex * step)).clamp(0.0, 1.0);

                                    return _animatedTrainerLabel(img, name, appear, pointIndex);
                                  },
                                ),
                              );
                            })(),
                        ],
                      ),

                      // Center label with pop animation
                      Positioned(
                        child: AnimatedScale(
                          scale: selectedIndex != null ? 1.05 : 1.0,
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.easeOutBack,
                          child: IgnorePointer(
                            ignoring: true,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (selectedIndex != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Text(
                                      innerData[selectedIndex!].label,
                                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      );
    }

    if (widget.embedded) {
      if (_loading) return const Center(child: CircularProgressIndicator());
      if (_error != null) return Text(_error!, style: const TextStyle(color: Colors.white));
      return chartContent();
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0B1020),
      body: SafeArea(
        child: Center(
          child: _loading
              ? const CircularProgressIndicator()
              : _error != null
              ? Text(_error!, style: const TextStyle(color: Colors.white))
              : chartContent(),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.red,
        label: const Text("SOS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        icon: const Icon(Icons.warning, color: Colors.white),
        onPressed: _launchSOS,
      ),
    );
  }

  // Animated trainer label widget: fade+scale + radial pop + gradient avatar
  Widget _animatedTrainerLabel(String img, String name, double appear, int index) {
    // appear in [0..1]
    final scale = 0.72 + 0.28 * appear;
    final opacity = appear;
    // small radial translation outward for pop effect (max 6 px)
    final radial = 6.0 * appear;
    return Opacity(
      opacity: opacity,
      child: Transform.translate(
        offset: Offset(0, -radial), // slight upward pop (visual)
        child: Transform.scale(
          scale: scale,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GradientAvatar(
                imageUrl: img,
                size: 56,
                borderWidth: 3,
                gradient: const LinearGradient(
                  colors: [Color(0xFF7C4DFF), Color(0xFFFF6B6B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                fallbackAsset: 'assets/image/fitstreet-bull-logo.png',
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: 72,
                child: Text(
                  name,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _animatedPlaceholder(double appear) {
    final opacity = appear;
    final scale = 0.85 + 0.15 * appear;
    final radial = 4.0 * appear;
    return Opacity(
      opacity: opacity,
      child: Transform.translate(
        offset: Offset(0, -radial),
        child: Transform.scale(
          scale: scale,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x14FFFFFF)),
                alignment: Alignment.center,
                child: Image.asset('assets/image/fitstreet-bull-logo.png', fit: BoxFit.contain),
              ),
              const SizedBox(height: 6),
              const SizedBox(
                width: 72,
                child: Text('', textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white38, fontSize: 11)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _animatedViewAll(double appear) {
    final opacity = appear;
    final scale = 0.85 + 0.25 * appear;
    final radial = 6.0 * appear;
    return Opacity(
      opacity: opacity,
      child: Transform.translate(
        offset: Offset(0, -radial),
        child: Transform.scale(
          scale: scale,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: Colors.white12),
                alignment: Alignment.center,
                child: const Text('View', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: 72,
                child: Text(
                  'View all',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _outerAnim.dispose();
    super.dispose();
  }
}

/// GradientAvatar: circular avatar with gradient border and fallback.
/// No external package required.
class GradientAvatar extends StatelessWidget {
  final String? imageUrl;
  final double size;
  final double borderWidth;
  final Gradient gradient;
  final String fallbackAsset;

  const GradientAvatar({
    Key? key,
    required this.imageUrl,
    this.size = 56,
    this.borderWidth = 3,
    required this.gradient,
    this.fallbackAsset = 'assets/image/fitstreet-bull-logo.png',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final innerSize = size - borderWidth * 2;
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(borderWidth),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: gradient,
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: ClipOval(
        child: Container(
          width: innerSize,
          height: innerSize,
          color: Colors.white12,
          child: (imageUrl != null && imageUrl!.trim().isNotEmpty)
              ? Image.network(
                  imageUrl!.trim(),
                  fit: BoxFit.cover,
                  errorBuilder: (c, e, s) => Image.asset(fallbackAsset, fit: BoxFit.cover),
                )
              : Image.asset(fallbackAsset, fit: BoxFit.cover),
        ),
      ),
    );
  }
}

class _Slice {
  final String label;
  const _Slice(this.label);
}

class _OuterPoint {
  final String label;
  final Map<String, dynamic> trainer;
  _OuterPoint(this.label, this.trainer);
}
