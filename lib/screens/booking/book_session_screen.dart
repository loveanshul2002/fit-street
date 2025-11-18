// lib/screens/booking/book_session_screen.dart
import 'dart:convert';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../widgets/glass_card.dart';
import '../../services/fitstreet_api.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../config/payment_config.dart';
import 'package:http/http.dart' as http;

class BookSessionScreen extends StatefulWidget {
  final String trainerId;
  const BookSessionScreen({super.key, required this.trainerId});

  @override
  State<BookSessionScreen> createState() => _BookSessionScreenState();
}

class _BookSessionScreenState extends State<BookSessionScreen> {
  bool _loading = true;
  Map<String, dynamic> _trainer = {};
  Map<String, dynamic> _sessionInfo = {};
  Map<String, dynamic> _user = {}; // user profile for payment prefill
  final String _apiBase = 'https://api.fitstreet.in'; // used by FitstreetApi

  // Razorpay integration
  late final Razorpay _razorpay;
  bool _processingPayment = false;
  bool _isPaid = false;
  String? _lastOrderId;
  // If backend create-order converts rupees -> paise internally set this true to avoid double *100
  static const bool backendExpectsRupees = true;
  String? _paymentError; // last payment or verification error
  String? _paymentStatus; // human-readable status
  bool _showPrefillEditor = false;
  late final TextEditingController _prefillNameCtrl;
  late final TextEditingController _prefillEmailCtrl;
  late final TextEditingController _prefillContactCtrl;

  // removed liquid overlay animation controller

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onPaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _onPaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _onExternalWallet);
  _prefillNameCtrl = TextEditingController();
  _prefillEmailCtrl = TextEditingController();
  _prefillContactCtrl = TextEditingController();
    _loadData();
  }

  @override
  void dispose() {
    _razorpay.clear();
  _prefillNameCtrl.dispose();
  _prefillEmailCtrl.dispose();
  _prefillContactCtrl.dispose();
    super.dispose();
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
      // attempt to resolve user id for prefill
      String? userId = await _resolveUserIdFromPrefs();
      if (userId != null && userId.isNotEmpty) {
        try {
          final userResp = await api.getUser(userId);
          if (userResp.statusCode == 200) {
            dynamic uBody;
            try { uBody = jsonDecode(userResp.body); } catch (_) { uBody = userResp.body; }
            if (uBody is Map) {
              _user = Map<String,dynamic>.from(
                (uBody['data'] is Map) ? uBody['data'] as Map : uBody
              );
            }
          }
        } catch (e) { debugPrint('Failed to load user for prefill: $e'); }
      }
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

    // Prepare prefill controllers from loaded user or stored prefs
    final name = (_safeString(_user['fullName']).isNotEmpty)
      ? _safeString(_user['fullName'])
      : (sp.getString('fitstreet_user_name') ?? sp.getString('fitstreet_trainer_name') ?? '');
    final email = (_safeString(_user['email']).isNotEmpty)
      ? _safeString(_user['email'])
      : (sp.getString('fitstreet_user_email') ?? sp.getString('fitstreet_trainer_email') ?? '');
    final contact = (_safeString(_user['mobileNumber']).isNotEmpty)
      ? _safeString(_user['mobileNumber'])
      : (sp.getString('fitstreet_user_mobile') ?? sp.getString('fitstreet_trainer_mobile') ?? '');
    _prefillNameCtrl.text = name;
    _prefillEmailCtrl.text = email;
    _prefillContactCtrl.text = contact;
    } catch (e) {
      debugPrint('Error loading data: $e');
      _trainer = {};
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ---------------- Razorpay helpers ----------------
  Future<FitstreetApi> _api() async {
    final sp = await SharedPreferences.getInstance();
    final token = sp.getString('fitstreet_token') ?? '';
    return FitstreetApi(_apiBase, token: token);
  }

  int _parseAmountToInt(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'[^0-9.]'), '');
    if (cleaned.isEmpty) return 0;
    if (cleaned.contains('.')) {
      try {
        return double.parse(cleaned).round();
      } catch (_) { return 0; }
    }
    return int.tryParse(cleaned) ?? 0;
  }

  Future<void> _startPayment() async {
    if (_processingPayment || _isPaid) return;
    final priceStr = _safeString(_sessionInfo['sessionPrice']);
    final amountRupees = _parseAmountToInt(priceStr);
    if (amountRupees <= 0) {
      _toast('Invalid session price');
      return;
    }
    setState(() => _processingPayment = true);
    try {
      final api = await _api();
      final orderResp = await api.createRazorpayOrder({
  // Send rupees if backend itself multiplies by 100; else send paise.
  'amount': backendExpectsRupees ? amountRupees : amountRupees * 100,
        'currency': 'INR',
        'receipt': 'session-${DateTime.now().millisecondsSinceEpoch}',
        'notes': {
          'purpose': 'session_booking',
          'trainerId': widget.trainerId,
        },
      });
      if (orderResp.statusCode != 200 && orderResp.statusCode != 201) {
        _toast('Failed to create order');
        setState(() => _processingPayment = false);
        return;
      }
      Map<String, dynamic> data = {};
      try { data = jsonDecode(orderResp.body); } catch (_) {}
      final orderId = (data['orderId'] ?? data['order_id'] ?? '').toString();
      if (orderId.isEmpty) {
        _toast('Order id missing');
        setState(() => _processingPayment = false);
        return;
      }
      _lastOrderId = orderId;
  // Prefill from controllers (editable)
  final name = _prefillNameCtrl.text.trim();
  final email = _prefillEmailCtrl.text.trim();
  final contact = _prefillContactCtrl.text.trim();
      final options = {
        'key': razorpayKeyId,
        // Razorpay SDK always expects paise (INR * 100)
        'amount': amountRupees * 100,
        'currency': 'INR',
        'name': 'FitStreet',
        'description': 'Session Booking',
        'order_id': orderId,
        'prefill': {'name': name, 'email': email, 'contact': contact},
        'theme': {'color': '#FF5503'},
      };
      setState(() {
        _paymentStatus = 'Order created. Opening secure checkout…';
        _paymentError = null;
      });
      _razorpay.open(options);
    } catch (e) {
      _toast('Payment init failed: $e');
      setState(() {
        _processingPayment = false;
        _paymentError = 'Init failed: $e';
        _paymentStatus = null;
      });
    }
  }

  void _onPaymentSuccess(PaymentSuccessResponse r) async {
    try {
      final api = await _api();
      final verifyResp = await api.verifyRazorpayPayment({
        'razorpay_order_id': r.orderId,
        'razorpay_payment_id': r.paymentId,
        'razorpay_signature': r.signature,
        // aliases for backend flexibility
        'orderId': r.orderId,
        'paymentId': r.paymentId,
        'signature': r.signature,
        if (_lastOrderId != null) 'clientOrderId': _lastOrderId,
      });
      debugPrint('session payment verify -> ${verifyResp.statusCode}: ${verifyResp.body}');
      if (verifyResp.statusCode == 200 || verifyResp.statusCode == 201) {
        setState(() {
          _isPaid = true;
          _paymentStatus = 'Payment verified';
          _paymentError = null;
        });
        _toast('Payment successful');
        // Auto-book session after payment
        await _bookSession();
      } else {
        setState(() {
          _paymentError = 'Verification failed (${verifyResp.statusCode})';
          _paymentStatus = null;
        });
        _toast('Payment verification failed');
      }
    } catch (e) {
      _toast('Verify failed: $e');
      setState(() {
        _paymentError = 'Verify error: $e';
        _paymentStatus = null;
      });
    } finally {
      if (mounted) setState(() => _processingPayment = false);
    }
  }

  void _onPaymentError(PaymentFailureResponse r) {
    _toast('Payment failed');
    setState(() {
      _processingPayment = false;
      _paymentError = 'Code ${r.code}: ${r.message}';
      _paymentStatus = null;
    });
  }

  void _onExternalWallet(ExternalWalletResponse r) {
    // Optional wallet handling
  }

  void _toast(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

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

  Future<void> _bookSession() async {
    if (_sessionInfo.isEmpty) {
      _toast('Session details missing');
      return;
    }
    if (!_isPaid) {
      _toast('Please complete payment first');
      return;
    }
    setState(() => _loading = true);
    try {
      final sp = await SharedPreferences.getInstance();
      final token = sp.getString('fitstreet_token') ?? '';
  String? userId = await _resolveUserIdFromPrefs();
      if (userId == null || userId.isEmpty) {
        userId = sp.getString('fitstreet_trainer_id') ?? sp.getString('fitstreet_trainer_db_id');
      }
      if (userId == null || userId.isEmpty) {
        _toast('User id not found. Please login again.');
        setState(() => _loading = false);
        return;
      }
      String rawDate = _safeString(_sessionInfo['sessionDate']);
      if (rawDate.contains(' to')) rawDate = rawDate.split(' to')[0];
      final isoDate = _toIsoDateOnly(rawDate);
      final selectedSession = _safeString(_sessionInfo['sessionType']);
      final selectedTime = selectedSession == 'single' ? _safeString(_sessionInfo['sessionTime']) : '';
      final price = _safeString(_sessionInfo['sessionPrice']);
      final mode = _safeString(_sessionInfo['mode']);
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
        // Payment metadata (can be stored server-side for reconciliation)
        if (_lastOrderId != null) 'razorpayOrderId': _lastOrderId,
      };
      // For now reuse existing multipart endpoint without image by creating empty temp file? Better: add server support for JSON-only booking.
      // Attempt JSON booking via a POST to same endpoint if supported.
      final uri = Uri.parse('$_apiBase/api/session-bookings');
      final resp = await http.post(uri, headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      }, body: jsonEncode(fields));
      debugPrint('bookSession (razorpay) -> ${resp.statusCode}: ${resp.body}');
      if (resp.statusCode == 200 || resp.statusCode == 201) {
        try {
          final parsed = jsonDecode(resp.body);
          final created = (parsed is Map ? (parsed['data'] ?? parsed) : parsed);
          final createdId = (created is Map) ? (created['_id'] ?? created['id'] ?? '') : '';
          await sp.remove('bookingInfo');
          _toast(createdId != '' ? 'Booking created: $createdId' : 'Session booked');
          if (mounted) Navigator.of(context).pop();
        } catch (_) {
          await sp.remove('bookingInfo');
          _toast('Session booked');
          if (mounted) Navigator.of(context).pop();
        }
      } else {
        String msg = resp.body;
        try { final parsed = jsonDecode(resp.body); if (parsed is Map) msg = (parsed['message'] ?? parsed['error'] ?? msg).toString(); } catch(_){}
        _toast('Booking failed (${resp.statusCode}): $msg');
      }
    } catch (e) {
      _toast('Error booking: $e');
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
            // static background only (removed animated liquid overlay)
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

              // Payment (Razorpay enhanced UI)
              GlassCard(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Payment', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                          if (_processingPayment && !_isPaid)
                            const SizedBox(height:24, width:24, child: CircularProgressIndicator(strokeWidth:2)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _isPaid ? 'Payment completed ✔' : 'Complete secure payment to confirm booking.',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 12),
                      _paymentStatus != null ? Text(_paymentStatus!, style: const TextStyle(color: Colors.greenAccent, fontSize: 12)) : const SizedBox.shrink(),
                      _paymentError != null ? Text(_paymentError!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)) : const SizedBox.shrink(),
                      if (_lastOrderId != null) ...[
                        const SizedBox(height: 8),
                        Text('Order: $_lastOrderId', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                      ],
                      const SizedBox(height: 16),
                      // Prefill preview + editor
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Payable Amount: ₹${_safeString(_sessionInfo['sessionPrice'])}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Payer details', style: TextStyle(color: Colors.white70)),
                                TextButton(
                                  onPressed: () => setState(() => _showPrefillEditor = !_showPrefillEditor),
                                  child: Text(_showPrefillEditor ? 'Done' : 'Edit'),
                                )
                              ],
                            ),
                            if (!_showPrefillEditor) ...[
                              Text('Name: ${_prefillNameCtrl.text.isNotEmpty ? _prefillNameCtrl.text : 'Not available'}', style: const TextStyle(color: Colors.white70)),
                              Text('Mobile: ${_prefillContactCtrl.text.isNotEmpty ? _prefillContactCtrl.text : 'Not available'}', style: const TextStyle(color: Colors.white70)),
                              Text('Email: ${_prefillEmailCtrl.text.isNotEmpty ? _prefillEmailCtrl.text : 'Not available'}', style: const TextStyle(color: Colors.white70)),
                            ] else ...[
                              const SizedBox(height: 6),
                              TextField(
                                controller: _prefillNameCtrl,
                                style: const TextStyle(color: Colors.white),
                                decoration: const InputDecoration(
                                  labelText: 'Full name',
                                  labelStyle: TextStyle(color: Colors.white54),
                                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white70)),
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _prefillContactCtrl,
                                keyboardType: TextInputType.phone,
                                style: const TextStyle(color: Colors.white),
                                decoration: const InputDecoration(
                                  labelText: 'Mobile number',
                                  labelStyle: TextStyle(color: Colors.white54),
                                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white70)),
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _prefillEmailCtrl,
                                keyboardType: TextInputType.emailAddress,
                                style: const TextStyle(color: Colors.white),
                                decoration: const InputDecoration(
                                  labelText: 'Email',
                                  labelStyle: TextStyle(color: Colors.white54),
                                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white70)),
                                ),
                              ),
                            ],
                            const SizedBox(height: 6),
                            const Text('These details will be shared with Razorpay to speed up payment.', style: TextStyle(color: Colors.white38, fontSize: 11)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (!_isPaid)
                        ElevatedButton.icon(
                          onPressed: _processingPayment ? null : _startPayment,
                          icon: const Icon(Icons.lock_outline),
                          label: Text(_processingPayment ? 'Processing…' : 'Pay Securely'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange.withOpacity(0.25),
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          ),
                        )
                      else
                        ElevatedButton.icon(
                          onPressed: _bookSession,
                          icon: const Icon(Icons.check_circle_outline),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          ),
                          label: const Text('Confirm Booking', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
