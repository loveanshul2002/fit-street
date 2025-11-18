import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../widgets/glass_card.dart';
import '../../../../services/fitstreet_api.dart';
import '../../../../config/payment_config.dart';

class PaymentStep extends StatefulWidget {
  final bool isPaid;
  final ValueChanged<bool> onPaidChanged;
  final String fullName;
  final String mobile;
  final String email;
  const PaymentStep({super.key, required this.isPaid, required this.onPaidChanged, required this.fullName, required this.mobile, required this.email});

  @override
  State<PaymentStep> createState() => _PaymentStepState();
}

class _PaymentStepState extends State<PaymentStep> {
  late final Razorpay _razorpay;
  bool _processing = false;
  String? _lastOrderId;
  static const int _activationFeeRupees = 1; // INR rupees
  String? _error;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onPaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _onPaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _onExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  Future<FitstreetApi> _api() async {
    final sp = await SharedPreferences.getInstance();
    final token = sp.getString('fitstreet_token') ?? '';
    return FitstreetApi('https://api.fitstreet.in', token: token);
  }

  Future<void> _startPayment() async {
    if (_processing || widget.isPaid) return;
    setState(() { _processing = true; _error = null; });
    try {
      final api = await _api();
      final orderResp = await api.createRazorpayOrder({
        // Backend expects amount in rupees (not paise)
        'amount': _activationFeeRupees,
        'currency': 'INR',
        'receipt': 'trainer-activation-${DateTime.now().millisecondsSinceEpoch}',
        'notes': {'purpose': 'trainer_activation'},
      });
      if (orderResp.statusCode != 200 && orderResp.statusCode != 201) {
        _fail('Order creation failed (${orderResp.statusCode})');
        return;
      }
      dynamic data; try { data = jsonDecode(orderResp.body); } catch (_) { data = {}; }
      final orderId = (data['orderId'] ?? data['order_id'] ?? '').toString();
      if (orderId.isEmpty) { _fail('Order id missing'); return; }
      _lastOrderId = orderId;

      final options = {
        'key': razorpayKeyId,
        'amount': _activationFeeRupees * 100, // paise for SDK
        'currency': 'INR',
        'name': 'FitStreet',
        'description': 'Trainer Activation Fee',
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
        'amountPaise': _activationFeeRupees * 100,
        'currency': 'INR',
      };
      final verify = await api.verifyRazorpayPayment(payload);
      if (verify.statusCode == 200 || verify.statusCode == 201) {
        widget.onPaidChanged(true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment successful')));
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
    setState(() { _processing = false; _error = msg; });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: GlassCard(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('2. Activation Payment', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(widget.isPaid ? 'Activation fee already paid.' : 'Pay the one-time activation fee to unlock remaining steps.', style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 12),
            if (!widget.isPaid) ...[
              ElevatedButton.icon(
                onPressed: _processing ? null : _startPayment,
                icon: const Icon(Icons.lock_open),
                label: Text(_processing ? 'Processing…' : 'Pay ₹$_activationFeeRupees Securely'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white12),
              ),
              const SizedBox(height: 8),
              const Text('Includes dashboard access & booking system.', style: TextStyle(color: Colors.white54, fontSize: 12)),
            ] else ...[
              const Chip(label: Text('Paid', style: TextStyle(color: Colors.white)), backgroundColor: Colors.green),
            ],
            if (_error != null) Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
            ),
          ]),
        ),
      ),
    );
  }
}
