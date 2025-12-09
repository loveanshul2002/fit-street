import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../services/fitstreet_api.dart';
import '../../../../config/payment_config.dart';
import '../../../legal/legal_page.dart';

class PaymentStep extends StatefulWidget {
  final bool isPaid;
  final ValueChanged<bool> onPaidChanged;
  final String fullName;
  final String mobile;
  final String email;
  const PaymentStep(
      {super.key,
      required this.isPaid,
      required this.onPaidChanged,
      required this.fullName,
      required this.mobile,
      required this.email});

  @override
  State<PaymentStep> createState() => _PaymentStepState();
}

class _PaymentStepState extends State<PaymentStep> {
  late final Razorpay _razorpay;
  bool _processing = false;
  String? _lastOrderId;
  // Base activation fee: 2499 for 'both', 1999 otherwise
  int _activationFeeRupees = 2499; // INR rupees (base)
  String? _error;
  bool _agreeTerms = false;
  bool _agreeRefund = false;
  String _sessionProvided = 'both';

  // Promo code state
  final TextEditingController _promoCtrl = TextEditingController();
  bool _promoApplied = false;
  int _promoDiscount = 0; // rupees off
  String? _promoError;

  int get _finalFeeRupees {
    final discounted =
        _activationFeeRupees - (_promoApplied ? _promoDiscount : 0);
    // Ensure non-zero positive amount
    return discounted < 1 ? 1 : discounted;
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() {
      // Reset transient state; parent can re-provide isPaid if changed upstream.
      _error = null;
    });
    // Optionally, trigger a lightweight re-check in the future.
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Refreshed')));
  }

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onPaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _onPaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _onExternalWallet);
    _initSessionModeAndFee();
  }

  @override
  void dispose() {
    _promoCtrl.dispose();
    _razorpay.clear();
    super.dispose();
  }

  Future<void> _updateSessionProvided(String value) async {
    if (value != 'online' && value != 'offline' && value != 'both') return;
    if (!mounted) return;
    setState(() {
      _sessionProvided = value;
      _activationFeeRupees = (value == 'both') ? 2499 : 1999;
      // Reset promo when mode changes
      _promoApplied = false;
      _promoDiscount = 0;
      _promoError = null;
      _promoCtrl.text = '';
    });
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString('fitstreet_session_provided', value);
      await sp.setString('fitstreet_trainer_mode', value);
    } catch (_) {
      // ignore persist errors
    }

    // Push to backend trainer preferences
    try {
      final sp = await SharedPreferences.getInstance();
      final token = sp.getString('fitstreet_token') ?? '';
      String? trainerId = sp.getString('fitstreet_trainer_db_id') ??
          sp.getString('fitstreet_trainer_id');
      if (trainerId != null && trainerId.isNotEmpty && token.isNotEmpty) {
        final api = FitstreetApi('https://api.fitstreet.in', token: token);
        final payload = {
          'mode': value.toLowerCase(),
          // Keep availableFor aligned if needed by backend schema
        };
        final resp = await api.updateTrainerPreferences(trainerId, payload);
        if (mounted) {
          if (resp.statusCode == 200 || resp.statusCode == 201) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Session mode updated in backend')));
          } else {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('Backend update failed: ${resp.statusCode}')));
          }
        }
      }
    } catch (_) {
      // silent fail
    }
  }

  Future<void> _initSessionModeAndFee() async {
    try {
      final sp = await SharedPreferences.getInstance();
      // Try a few possible keys where mode might be stored
      final mode = sp.getString('fitstreet_session_provided') ??
          sp.getString('fitstreet_trainer_mode') ??
          sp.getString('working_mode') ??
          '';
      final m = (mode.isEmpty ? _sessionProvided : mode).trim().toLowerCase();
      setState(() {
        _sessionProvided =
            (m == 'online' || m == 'offline' || m == 'both') ? m : 'both';
        _activationFeeRupees = (_sessionProvided == 'both') ? 2499 : 1999;
        _promoApplied = false;
        _promoDiscount = 0;
        _promoError = null;
        _promoCtrl.text = '';
      });
    } catch (_) {
      // default already set
    }
  }

  void _applyPromoCode() {
    final code = _promoCtrl.text.trim().toUpperCase();
    const validCodes = ['FSSUNNY', 'FSPREETI'];
    if (validCodes.contains(code)) {
      setState(() {
        _promoDiscount = 200;
        _promoApplied = true;
        _promoError = null;
      });
    } else {
      setState(() {
        _promoDiscount = 0;
        _promoApplied = false;
        _promoError = 'Invalid promo code.';
      });
    }
  }

  void _resetPromoCode() {
    setState(() {
      _promoApplied = false;
      _promoDiscount = 0;
      _promoError = null;
      _promoCtrl.text = '';
    });
  }

  Future<FitstreetApi> _api() async {
    final sp = await SharedPreferences.getInstance();
    final token = sp.getString('fitstreet_token') ?? '';
    return FitstreetApi('https://api.fitstreet.in', token: token);
  }

  Future<void> _startPayment() async {
    if (_processing || widget.isPaid) return;
    if (!_agreeTerms || !_agreeRefund) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Please accept Terms & Conditions and Refund Policy')),
      );
      return;
    }
    setState(() {
      _processing = true;
      _error = null;
    });
    try {
      final api = await _api();
      final orderResp = await api.createRazorpayOrder({
        // Backend expects amount in rupees (not paise)
        'amount': _finalFeeRupees,
        'currency': 'INR',
        'receipt':
            'trainer-activation-${DateTime.now().millisecondsSinceEpoch}',
        'notes': {'purpose': 'trainer_activation'},
      });
      if (orderResp.statusCode != 200 && orderResp.statusCode != 201) {
        _fail('Order creation failed (${orderResp.statusCode})');
        return;
      }
      dynamic data;
      try {
        data = jsonDecode(orderResp.body);
      } catch (_) {
        data = {};
      }
      final orderId = (data['orderId'] ?? data['order_id'] ?? '').toString();
      if (orderId.isEmpty) {
        _fail('Order id missing');
        return;
      }
      _lastOrderId = orderId;

      final options = {
        'key': razorpayKeyId,
        'amount': _finalFeeRupees * 100, // paise for SDK
        'currency': 'INR',
        'name': 'FitStreet',
        'description': 'Trainer Activation Fee - ₹$_finalFeeRupees',
        'order_id': orderId,
        'prefill': {
          'name': widget.fullName,
          'email': widget.email,
          'contact': widget.mobile,
        },
        'theme': {'color': '#FF5503'},
      };
      _razorpay.open(options);
    } catch (e) {
      _fail('Payment init failed: $e');
    }
  }

  void _onPaymentSuccess(PaymentSuccessResponse r) async {
    try {
      final api = await _api();
      final payload = {
        'razorpay_order_id': r.orderId,
        'razorpay_payment_id': r.paymentId,
        'razorpay_signature': r.signature,
        // aliases
        'orderId': r.orderId,
        'paymentId': r.paymentId,
        'signature': r.signature,
        if (_lastOrderId != null) 'clientOrderId': _lastOrderId,
        'amountPaise': _finalFeeRupees * 100,
        'currency': 'INR',
      };
      final verify = await api.verifyRazorpayPayment(payload);
      if (verify.statusCode == 200 || verify.statusCode == 201) {
        widget.onPaidChanged(true);
        if (!mounted) return; // guard context use after async
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Payment successful')));
      } else {
        _fail('Verification failed');
      }
    } catch (e) {
      _fail('Verify failed: $e');
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  void _onPaymentError(PaymentFailureResponse r) {
    _fail('Payment failed');
  }

  void _onExternalWallet(ExternalWalletResponse r) {
    // optional
  }

  void _fail(String msg) {
    if (!mounted) return;
    setState(() {
      _processing = false;
      _error = msg;
    });
    if (!mounted) return; // guard context use
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with refresh
          Row(
            children: [
              const Expanded(
                child: Text(
                  '2. Activation Payment',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Refresh',
                onPressed: _refresh,
                icon: const Icon(Icons.refresh, color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Session Provided Mode selection (affects price)
          if (!widget.isPaid)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Session Provided Mode*',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Do you want to train',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _ModeOption(
                        label: 'Online',
                        value: 'online',
                        selected: _sessionProvided == 'online',
                        onTap: () => _updateSessionProvided('online'),
                      ),
                      const SizedBox(width: 8),
                      _ModeOption(
                        label: 'Offline',
                        value: 'offline',
                        selected: _sessionProvided == 'offline',
                        onTap: () => _updateSessionProvided('offline'),
                      ),
                      const SizedBox(width: 8),
                      _ModeOption(
                        label: 'Both',
                        value: 'both',
                        selected: _sessionProvided == 'both',
                        onTap: () => _updateSessionProvided('both'),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          // Promo Code box
          if (!widget.isPaid)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Promo Code',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14),
                  ),
                  const SizedBox(height: 6),
                  if (!_promoApplied) ...[
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _promoCtrl,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'Enter promo code',
                              hintStyle: const TextStyle(color: Colors.white70),
                              filled: true,
                              fillColor:
                                  const Color.fromARGB(30, 255, 255, 255),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: Color.fromARGB(60, 255, 255, 255),
                                    width: 1.5),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: Color.fromARGB(60, 255, 255, 255),
                                    width: 1.5),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  vertical: 12, horizontal: 12),
                            ),
                            onChanged: (_) {
                              setState(() {
                                _promoApplied = false;
                                _promoDiscount = 0;
                                _promoError = null;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _applyPromoCode,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF6B35),
                            padding: const EdgeInsets.symmetric(
                                vertical: 12, horizontal: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Apply',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                    if (_promoError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(_promoError!,
                            style: const TextStyle(color: Colors.redAccent)),
                      ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 14),
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(25, 255, 167, 38),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: const Color(0xFFFFA726), width: 2),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              '${_promoCtrl.text.trim().toUpperCase()} applied! ₹$_promoDiscount off',
                              style: const TextStyle(
                                  color: Color(0xFFFFA726),
                                  fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Remove Promo',
                            onPressed: _resetPromoCode,
                            icon: const Icon(Icons.close,
                                color: Color(0xFFFFA726)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

          // Payment amount card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color.fromARGB(25, 255, 255, 255),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: const Color.fromARGB(46, 255, 255, 255), width: 1.5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Trainer Activation Fee',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600)),
                      SizedBox(height: 4),
                      Text('One-time registration fee',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (_promoApplied && _promoDiscount > 0) ...[
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('₹$_activationFeeRupees',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 16,
                                  decoration: TextDecoration.lineThrough,
                                )),
                            const SizedBox(width: 8),
                            Text('₹$_finalFeeRupees',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text('Total after discount',
                            style:
                                TextStyle(color: Colors.white70, fontSize: 12)),
                      ] else ...[
                        Text('₹$_finalFeeRupees',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w700)),
                      ],
                      const SizedBox(height: 4),
                      const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.shield,
                              color: Colors.greenAccent, size: 16),
                          SizedBox(width: 6),
                          Flexible(
                            child: Text('Secure Payment',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: Colors.greenAccent, fontSize: 12)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Dynamic eligibility message
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _sessionProvided == 'both'
                  ? 'You are eligible to train both online and offline customers.'
                  : _sessionProvided == 'online'
                      ? 'You are eligible to train customers online only.'
                      : 'You are eligible to train customers offline only.',
              style: const TextStyle(
                color: Color(0xFFFF6B35),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          // Rewards box (only when not paid)
          if (!widget.isPaid)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color.fromARGB(20, 255, 85, 3),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: const Color.fromARGB(46, 255, 85, 3), width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.card_giftcard,
                            color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text(
                          "What You'll Get Instantly",
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: const [
                        Expanded(
                          child: Row(
                            children: [
                              Icon(Icons.speed,
                                  color: Colors.greenAccent, size: 18),
                              SizedBox(width: 6),
                              Flexible(
                                  child: Text('Dashboard Access',
                                      style: TextStyle(color: Colors.white))),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Row(
                            children: [
                              Icon(Icons.people,
                                  color: Colors.lightBlueAccent, size: 18),
                              SizedBox(width: 6),
                              Flexible(
                                  child: Text('Client Booking System',
                                      style: TextStyle(color: Colors.white))),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Row(
                            children: [
                              Icon(Icons.currency_rupee,
                                  color: Colors.amber, size: 18),
                              SizedBox(width: 6),
                              Flexible(
                                  child: Text('Start Earning Money',
                                      style: TextStyle(color: Colors.white))),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          // Payment method card (Razorpay)
          if (!widget.isPaid)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color.fromARGB(20, 255, 255, 255),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color.fromARGB(33, 255, 255, 255),
                      width: 1.5),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.credit_card, color: Colors.white, size: 24),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Secure Payment via Razorpay',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600)),
                          SizedBox(height: 4),
                          Text(
                              'Credit Card, Debit Card, Net Banking, UPI & Wallets',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                    ),
                    Icon(Icons.verified, color: Colors.greenAccent, size: 20),
                  ],
                ),
              ),
            ),

          // Processing state
          if (_processing)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                children: const [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 10),
                  Text('Processing Payment...',
                      style: TextStyle(color: Colors.white)),
                  SizedBox(height: 4),
                  Text('Please do not close this window',
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),

          // Secure payment button
          if (!widget.isPaid)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_processing || !_agreeTerms || !_agreeRefund)
                      ? null
                      : _startPayment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1d4ed8),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 4,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_processing) ...[
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        ),
                        const SizedBox(width: 8),
                        const Text('Processing...',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600)),
                      ] else ...[
                        const Icon(Icons.credit_card, color: Colors.white),
                        const SizedBox(width: 8),
                        Text('Pay ₹$_finalFeeRupees Securely',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700)),
                      ],
                    ],
                  ),
                ),
              ),
            ),

          // Terms notice
          if (!widget.isPaid)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(
                    child: Text(
                      'By proceeding with payment, you agree to our Terms & Conditions and Refund Policy',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    value: _agreeTerms,
                    onChanged: (v) => setState(() => _agreeTerms = v ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                    dense: true,
                    checkboxShape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4)),
                    activeColor: const Color(0xFFFF6B35),
                    title: GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const LegalPage(
                              title: 'Terms & Conditions',
                              assetHtmlPath: '',
                            ),
                          ),
                        );
                      },
                      child: const Text(
                        'I accept the Terms & Conditions',
                        style: TextStyle(
                          color: Color.fromARGB(255, 255, 255, 255),
                          decoration: TextDecoration.underline,
                          decorationColor: Color.fromARGB(255, 255, 255, 255),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  CheckboxListTile(
                    value: _agreeRefund,
                    onChanged: (v) => setState(() => _agreeRefund = v ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                    dense: true,
                    checkboxShape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4)),
                    activeColor: const Color(0xFFFF6B35),
                    title: GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const LegalPage(
                              title: 'Refund & Cancellation Policy',
                              assetHtmlPath: '',
                            ),
                          ),
                        );
                      },
                      child: const Text(
                        'I accept the Refund & Cancellation Policy',
                        style: TextStyle(
                          color: Color.fromARGB(255, 255, 255, 255),
                          decoration: TextDecoration.underline,
                          decorationColor: Color.fromARGB(255, 255, 255, 255),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Paid chip
          if (widget.isPaid)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color.fromARGB(20, 34, 197, 94),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: const Color.fromARGB(46, 34, 197, 94), width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: const [
                    Icon(Icons.check_circle,
                        color: Colors.greenAccent, size: 36),
                    SizedBox(height: 8),
                    Text('Payment Successful!',
                        style: TextStyle(
                            color: Colors.greenAccent,
                            fontWeight: FontWeight.w700)),
                    SizedBox(height: 6),
                    Text(
                      'Now complete your KYC by accepting terms and adding your signature.',
                      style: TextStyle(color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),

          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_error!,
                  style: const TextStyle(color: Colors.redAccent)),
            ),
        ],
      ),
    );
  }
}

class _LegalRoute extends StatelessWidget {
  final String title;
  const _LegalRoute({super.key, required this.title});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.black,
      ),
      body: const _LegalContent(),
    );
  }
}

class _LegalContent extends StatelessWidget {
  const _LegalContent({super.key});
  @override
  Widget build(BuildContext context) {
    // Reuse existing legal page widget if available; fallback to simple text.
    try {
      // ignore: unnecessary_statements
      // If `LegalPage` exists, navigate to it inside this route.
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('Legal',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
            SizedBox(height: 12),
            Text(
                'Please refer to the Legal page for full Terms & Conditions and Refund Policy.',
                style: TextStyle(color: Colors.white70)),
          ],
        ),
      );
    } catch (_) {
      return const SizedBox.shrink();
    }
  }
}

class _ModeOption extends StatelessWidget {
  final String label;
  final String value;
  final bool selected;
  final VoidCallback onTap;
  const _ModeOption({
    super.key,
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = selected
        ? const Color(0xFFFF6B35)
        : const Color.fromARGB(60, 255, 255, 255);
    final bg = selected
        ? const Color.fromARGB(28, 255, 107, 53)
        : const Color.fromARGB(20, 255, 255, 255);
    final textColor = selected ? const Color(0xFFFF6B35) : Colors.white;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: 1.5),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
