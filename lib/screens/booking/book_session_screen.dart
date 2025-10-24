// lib/screens/booking/book_session_screen.dart
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show ImageFilter;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../widgets/glass_card.dart';
import '../../services/fitstreet_api.dart';
import 'package:image_picker/image_picker.dart';

class BookSessionScreen extends StatefulWidget {
  final String trainerId;
  const BookSessionScreen({super.key, required this.trainerId});

  @override
  State<BookSessionScreen> createState() => _BookSessionScreenState();
}

class _BookSessionScreenState extends State<BookSessionScreen> with SingleTickerProviderStateMixin {
  bool _loading = true;
  Map<String, dynamic> _trainer = {};
  Map<String, dynamic> _sessionInfo = {};
  File? _paymentScreenshot;
  final String _qrCodeAsset = 'assets/image/upi-qr.jpeg';
  final ImagePicker _picker = ImagePicker();
  final String _apiBase = 'https://api.fitstreet.in'; // used by FitstreetApi

  // subtle liquid overlay controller
  late final AnimationController _liquidCtrl;

  @override
  void initState() {
    super.initState();
  _liquidCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 16))..repeat();
    _loadData();
  }

  // Load bookingInfo from prefs and trainer profile from API
  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final sp = await SharedPreferences.getInstance();

      // bookingInfo stored earlier when user selected date/time
      final bookingInfo = sp.getString('bookingInfo');
      if (bookingInfo != null) {
        try {
          _sessionInfo = jsonDecode(bookingInfo) as Map<String, dynamic>;
        } catch (_) {
          _sessionInfo = {};
        }
      } else {
        _sessionInfo = {};
      }

      // read token and call API to fetch trainer
      final token = sp.getString('fitstreet_token') ?? '';
      final api = FitstreetApi(_apiBase, token: token);
      final resp = await api.getTrainer(widget.trainerId);

      if (resp.statusCode == 200) {
        dynamic body;
        try {
          body = jsonDecode(resp.body);
        } catch (_) {
          body = resp.body;
        }

        Map<String, dynamic>? trainerObj;
        if (body is Map) {
          // handle common shapes: { data: { ... } }, { trainer: { ... } }, or direct object
          if (body['data'] is Map) {
            trainerObj = Map<String, dynamic>.from(body['data'] as Map);
          } else if (body['trainer'] is Map) {
            trainerObj = Map<String, dynamic>.from(body['trainer'] as Map);
          } else {
            trainerObj = Map<String, dynamic>.from(body);
          }
        }
        _trainer = trainerObj ?? {};
      } else {
        debugPrint('Failed to load trainer: ${resp.statusCode} ${resp.body}');
        _trainer = {};
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
      _trainer = {};
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (image != null) {
        setState(() => _paymentScreenshot = File(image.path));
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to pick image: $e')));
      }
    }
  }

  String _safeString(dynamic v) => v == null ? '' : v.toString();

  // Normalize input like '2025-10-11' or '2025-10-11T00:00:00.000Z' -> UTC ISO midnight
  String _toIsoDateOnly(String dateLike) {
    if (dateLike.trim().isEmpty) return '';
    try {
      final dt = DateTime.parse(dateLike);
      final utcDate = DateTime.utc(dt.year, dt.month, dt.day);
      return utcDate.toIso8601String(); // e.g. 2025-10-11T00:00:00.000Z
    } catch (_) {
      // try simple YYYY-MM-DD
      final parts = dateLike.split(RegExp(r'[\sT]'))[0].split('-');
      if (parts.length == 3) {
        final y = int.tryParse(parts[0]) ?? 1970;
        final m = int.tryParse(parts[1]) ?? 1;
        final d = int.tryParse(parts[2]) ?? 1;
        final utcDate = DateTime.utc(y, m, d);
        return utcDate.toIso8601String();
      }
    }
    return '';
  }

  // Try multiple SharedPreferences keys to find DB user id
  Future<String?> _resolveUserIdFromPrefs() async {
    final sp = await SharedPreferences.getInstance();
    final candidates = [
      'fitstreet_user_id',
      'fitstreet_user_db_id',
      'fitstreet_userId',
      'user_id',
      'id',
      'fitstreet_user',
    ];
    for (final k in candidates) {
      final v = sp.getString(k);
      if (v != null && v.trim().isNotEmpty) return v.trim();
    }
    // fallback: try 'id' stored as JSON
    if (sp.containsKey('id')) {
      final maybe = sp.getString('id');
      if (maybe != null && maybe.trim().isNotEmpty) return maybe.trim();
    }
    return null;
  }

  Future<void> _submitPayment() async {
    if (_paymentScreenshot == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please upload payment screenshot')));
      return;
    }
    if (_sessionInfo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Session details missing')));
      return;
    }

    setState(() => _loading = true);
    try {
      final sp = await SharedPreferences.getInstance();
      final token = sp.getString('fitstreet_token') ?? '';
      final api = FitstreetApi(_apiBase, token: token);

      String? userId = await _resolveUserIdFromPrefs();
      if (userId == null || userId.isEmpty) {
        // final fallback try a few raw keys
        userId = sp.getString('fitstreet_trainer_id') ?? sp.getString('fitstreet_trainer_db_id');
      }

      if (userId == null || userId.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User id not found. Please login again.')));
        }
        setState(() => _loading = false);
        return;
      }

      // Prepare fields
      String rawDate = _safeString(_sessionInfo['sessionDate']);
      if (rawDate.contains(' to')) rawDate = rawDate.split(' to')[0];
      final isoDate = _toIsoDateOnly(rawDate);

      final selectedSession = _safeString(_sessionInfo['sessionType'] ?? _sessionInfo['sessionType']);
      final selectedTime = selectedSession == 'single' ? _safeString(_sessionInfo['sessionTime']) : '';
      final price = _safeString(_sessionInfo['sessionPrice']);
      final mode = _safeString(_sessionInfo['mode'] ?? '');

      final fields = <String, dynamic>{
        'selectedSession': selectedSession,
        'selectedTime': selectedTime,
        'selectedDate': isoDate,
        'price': price,
        'mode': mode,
        'isAccepted': 'false',
        'status': 'upcoming',
        'trainerId': widget.trainerId,
        'userId': userId,
      };

      // Call API (FitstreetApi.bookSession will attach screenshot)
      final resp = await api.bookSession(fields, _paymentScreenshot!);

      debugPrint('bookSession -> status: ${resp.statusCode}');
      debugPrint('bookSession -> body: ${resp.body}');

      if (resp.statusCode == 200 || resp.statusCode == 201) {
        // success — try parse response
        try {
          final parsed = jsonDecode(resp.body);
          final created = (parsed is Map ? (parsed['data'] ?? parsed) : parsed);
          final createdId = (created is Map) ? (created['_id'] ?? created['id'] ?? '') : '';
          // remove local bookingInfo
          await sp.remove('bookingInfo');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(createdId != '' ? 'Booking created: $createdId' : 'Session booked successfully!')),
            );
            Navigator.of(context).pop();
          }
        } catch (_) {
          // not JSON or unexpected shape
          await sp.remove('bookingInfo');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Session booked successfully!')));
            Navigator.of(context).pop();
          }
        }
      } else {
        // failure - show server message if available
        String msg = resp.body;
        try {
          final parsed = jsonDecode(resp.body);
          if (parsed is Map) msg = (parsed['message'] ?? parsed['error'] ?? resp.body).toString();
        } catch (_) {}
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to book session (${resp.statusCode}): $msg')));
        }
      }
    } catch (e) {
      debugPrint('Error booking session: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error booking session: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          toolbarHeight: 50,
          leadingWidth: 177,
          leading: Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  iconSize: 20,
                ),
                const SizedBox(width: 8),
                Image.asset('assets/image/fitstreet-bull-logo.png', width: 100, height: 40, fit: BoxFit.contain),
              ],
            ),
          ),
          flexibleSpace: ClipRRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
              child: Container(color: Colors.black.withOpacity(0.15)),
            ),
          ),
          title: const Text('Book Session'),
        ),
        body: Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/image/bg.png'),
              fit: BoxFit.cover,
              colorFilter: ColorFilter.mode(Colors.black54, BlendMode.darken),
            ),
          ),
          child: const Center(child: CircularProgressIndicator()),
        ),
      );
    }

    // Get readable trainer id (prefer trainerUniqueId then fallback to _id)
    final trainerUnique = _safeString(_trainer['trainerUniqueId']).isNotEmpty
        ? _safeString(_trainer['trainerUniqueId'])
        : (_safeString(_trainer['trainerUniqueID']).isNotEmpty ? _safeString(_trainer['trainerUniqueID']) : _safeString(_trainer['_id']));

    final fullName = _safeString(_trainer['fullName']);
    final imageUrl = _safeString(_trainer['trainerImageURL']);
    final hasNetworkImage = imageUrl.isNotEmpty && (imageUrl.startsWith('http') || imageUrl.startsWith('https'));

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Book Session'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 50,
        leadingWidth: 177,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                iconSize: 20,
              ),
              const SizedBox(width: 8),
              Image.asset('assets/image/fitstreet-bull-logo.png', width: 100, height: 40, fit: BoxFit.contain),
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
            // liquid glow overlay
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _liquidCtrl,
                  builder: (context, _) {
                    final t = _liquidCtrl.value * 2 * math.pi;
                    final dx = 0.5 + 0.25 * math.sin(t);
                    final dy = 0.4 + 0.25 * math.cos(t * 1.3);
                    return Container(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment(dx * 2 - 1, dy * 2 - 1),
                          radius: 1.2,
                          colors: [
                            Colors.white.withOpacity(0.06),
                            Colors.white.withOpacity(0.00),
                          ],
                          stops: const [0.0, 1.0],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
              // Session Details Card
              GlassCard(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // header row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Session Details', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(color: Colors.blue.withOpacity(0.2), borderRadius: BorderRadius.circular(16)),
                            child: Text('${_safeString(_sessionInfo['mode']).toUpperCase()} Session', style: const TextStyle(color: Colors.white)),
                          )
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Trainer info row
                      Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(40),
                            child: Container(
                              width: 64,
                              height: 64,
                              color: Colors.white12,
                              child: hasNetworkImage
                                  ? Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (ctx, err, st) => Image.asset('assets/image/fitstreet-bull-logo.png', fit: BoxFit.contain))
                                  : Image.asset('assets/image/fitstreet-bull-logo.png', fit: BoxFit.contain),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(fullName, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text('ID: $trainerUnique', style: const TextStyle(color: Colors.white70)),
                                const SizedBox(height: 6),
                                Text(
                                  // specialization preview
                                  (_trainer['trainerSpecializationProof'] is List)
                                      ? (_trainer['trainerSpecializationProof'] as List)
                                      .map((e) => (e is Map ? (e['specialization'] ?? '') : e.toString()))
                                      .where((s) => s.toString().isNotEmpty)
                                      .join(', ')
                                      : _safeString(_trainer['specialization']),
                                  style: const TextStyle(color: Colors.white70),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // session rows
                      _infoRow('Session:', '${_safeString(_sessionInfo['sessionType'])}${_safeString(_sessionInfo['sessionType']) == 'monthly' ? ' (20 Sessions included)' : ''}'),
                      _infoRow('Date:', _safeString(_sessionInfo['sessionDate'])),
                      if (_safeString(_sessionInfo['sessionTime']).isNotEmpty) _infoRow('Time:', _safeString(_sessionInfo['sessionTime'])),
                      _infoRow('Price:', '₹${_safeString(_sessionInfo['sessionPrice'])}'),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Total Payment Card
              GlassCard(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Total Payment', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total Amount', style: TextStyle(color: Colors.white70, fontSize: 18)),
                          Text('₹${_safeString(_sessionInfo['sessionPrice'])}', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Payment (QR + upload)
              GlassCard(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Text('Scan to Pay', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      Container(
                        width: 180,
                        height: 180,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                        child: Image.asset(_qrCodeAsset, fit: BoxFit.contain),
                      ),
                      const SizedBox(height: 16),
                      const Text('Scan the QR code above to pay securely.', style: TextStyle(color: Colors.white70)),
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: Colors.purpleAccent.withOpacity(0.5), width: 2),
                          ),
                          child: _paymentScreenshot != null
                              ? Column(children: [
                            Image.file(_paymentScreenshot!, height: 160, fit: BoxFit.cover),
                            const SizedBox(height: 8),
                            const Text('Change Screenshot', style: TextStyle(color: Colors.white70)),
                          ])
                              : Column(children: [
                            const Icon(Icons.cloud_upload, color: Colors.white70, size: 48),
                            const SizedBox(height: 8),
                            RichText(
                              text: TextSpan(
                                style: const TextStyle(color: Colors.white70),
                                children: [
                                  const TextSpan(text: 'Tap to upload '),
                                  TextSpan(text: 'payment screenshot', style: TextStyle(color: Colors.blue[300])),
                                ],
                              ),
                            ),
                          ]),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _paymentScreenshot != null ? _submitPayment : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Text('Submit Payment', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Text(label, style: const TextStyle(color: Colors.white70)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        )
      ]),
    );
  }
}
