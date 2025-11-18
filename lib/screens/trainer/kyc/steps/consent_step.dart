import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../widgets/glass_card.dart';
import '../utils/ui_helpers.dart';
import '../widgets/policy_tile.dart';
import '../../../legal/legal_page.dart';
import '../widgets/signature_pad.dart';
import '../utils/input_formatters.dart';
import '../../../../services/fitstreet_api.dart';
import '../../../../config/payment_config.dart';

class ConsentStep extends StatefulWidget {
  final bool noCriminalRecord, agreeHnS, ackTrainerAgreement, ackCancellationPolicy;
  final void Function({
  bool? noCrime, bool? hns, bool? agr, bool? cancel, bool? payout, bool? privacy
  }) onChange;

  // kept for compatibility; no longer required for validation
  final TextEditingController esignName;
  final TextEditingController esignDate;
  final ValueChanged<Uint8List?> onSignatureBytes;

  // Razorpay payment status
  final bool isPaid;
  final ValueChanged<bool>? onPaidChanged;

  const ConsentStep({
    super.key,
    required this.noCriminalRecord,
    required this.agreeHnS,
    required this.ackTrainerAgreement,
    required this.ackCancellationPolicy,
    required this.onChange,
    required this.esignName,
    required this.esignDate,
  required this.onSignatureBytes,
  required this.isPaid,
  this.onPaidChanged,
  });

  /// VALIDATION: NOTE — e-sign matching / date checks removed.
  /// Now only verifies background declarations and policy acknowledgements.
  static bool validateConsent({
    required Uint8List? signaturePng,
    required String fullName, // ignored for validation
    required String esignName, // ignored (no input field rendered currently)
    required String esignDate,
    required bool noCriminalRecord,
    required bool agreeHnS,
    required bool ackTrainerAgreement,
    required bool ackCancellationPolicy,
    required bool isPaid,
    required void Function(String) toast,
  }) {
    // 1) Background declarations
    if (!noCriminalRecord || !agreeHnS) {
      toast("Please confirm background declarations.");
      return false;
    }

    // 2) Policy acknowledgements
    if (!ackTrainerAgreement || !ackCancellationPolicy) {
      toast("Please open & acknowledge all policies.");
      return false;
    }

    // 3) Payment must be completed
    if (!isPaid) {
      toast("Please complete the activation payment.");
      return false;
    }

    // 4) Signature required
    if (signaturePng == null || signaturePng.isEmpty) {
      toast("Please add your handwritten e-sign.");
      return false;
    }

  // 5) Date required and valid (DD/MM/YYYY)
  final dateTxt = esignDate.trim();
  if (!RegExp(r'^\d{2}/\d{2}/\d{4}$').hasMatch(dateTxt)) {
      toast("Enter e-sign date as DD/MM/YYYY.");
      return false;
    }

    return true;
  }

  @override
  State<ConsentStep> createState() => _ConsentStepState();
}

class _ConsentStepState extends State<ConsentStep> {
  // Razorpay
  late final Razorpay _razorpay;
  bool _processing = false;
  static const int _activationFee = 1; // INR
  String? _lastOrderId; // track last created order id
  // final ImagePicker _picker = ImagePicker();

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
    if (_processing) return;
    setState(() => _processing = true);
    try {
      final api = await _api();
      // Create order (backend can decide multiplier)
      final resp = await api.createRazorpayOrder({
        // Razorpay orders expect amount in paise
        'amount': _activationFee * 1,
        'currency': 'INR',
        'receipt': 'trainer-activation-${DateTime.now().millisecondsSinceEpoch}',
        'notes': {'purpose': 'trainer_activation'},
      });
      if (resp.statusCode != 200 && resp.statusCode != 201) {
        _toast('Failed to create payment order');
        setState(() => _processing = false);
        return;
      }
      final data = resp.body.isNotEmpty ? respToJson(resp.body) : {};
      final orderId = (data['orderId'] ?? data['order_id'] ?? '').toString();
      if (orderId.isEmpty) {
        _toast('Order id missing');
        setState(() => _processing = false);
        return;
      }
      _lastOrderId = orderId;

      // Prefill from local cache if available
      final sp = await SharedPreferences.getInstance();
      final name = sp.getString('fitstreet_trainer_name') ?? '';
      final email = sp.getString('fitstreet_trainer_email') ?? '';
      final contact = sp.getString('fitstreet_trainer_mobile') ?? '';

      final options = {
        'key': razorpayKeyId,
        'amount': _activationFee * 1, // paise for SDK
        'currency': 'INR',
        'name': 'FitStreet',
        'description': 'Trainer Activation Fee',
        'image': 'https://fitstreet.in/assets/fitstreet-bull-logo.png',
        'order_id': orderId,
        'prefill': {'name': name, 'email': email, 'contact': contact},
        'theme': {'color': '#FF5503'},
      };
      _razorpay.open(options);
    } catch (e) {
      _toast('Payment init failed: $e');
      setState(() => _processing = false);
    }
  }

  Map<String, dynamic> respToJson(String s) {
    try { return (s.isNotEmpty) ? (jsonDecode(s) as Map<String, dynamic>) : {}; } catch (_) { return {}; }
  }

  void _onPaymentSuccess(PaymentSuccessResponse r) async {
    try {
      final api = await _api();
      final payload = <String, dynamic>{
        // Common snake_case expected by most Node examples
        'razorpay_order_id': r.orderId,
        'razorpay_payment_id': r.paymentId,
        'razorpay_signature': r.signature,

        // Also send camelCase aliases to be safe
        'razorpayOrderId': r.orderId,
        'razorpayPaymentId': r.paymentId,
        'razorpaySignature': r.signature,

        // Some backends call it orderCreationId
        'orderCreationId': r.orderId,
        'order_id': r.orderId,
        'orderId': r.orderId,
        'paymentId': r.paymentId,
        'signature': r.signature,

        // Optional context
        if (_lastOrderId != null) 'clientOrderId': _lastOrderId,
        'amountPaise': _activationFee * 100,
        'currency': 'INR',
      };
      final verify = await api.verifyRazorpayPayment(payload);
      debugPrint('Razorpay verify -> ${verify.statusCode}: ${verify.body}');
      if (verify.statusCode == 200 || verify.statusCode == 201) {
        widget.onPaidChanged?.call(true);
        _toast('Payment successful');
      } else {
        final msg = verify.body.isNotEmpty ? verify.body : 'Payment verification failed';
        _toast(msg);
      }
    } catch (e) {
      _toast('Verify failed: $e');
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  void _onPaymentError(PaymentFailureResponse r) {
    _toast('Payment failed');
    setState(() => _processing = false);
  }

  void _onExternalWallet(ExternalWalletResponse r) {
    // Optional
  }

  void _toast(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: GlassCard(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Section("4. Compliance & Consent"),

              const SubTitle("Background Declaration"),
              CheckboxListTile(
                  value: widget.noCriminalRecord,
                  onChanged: (v)=> widget.onChange(noCrime: v ?? false),
                  checkColor: Colors.white, activeColor: Colors.white.withOpacity(0.25),
                  title: const Text("I confirm that I have no criminal record.", style: TextStyle(color: Colors.white)),
                  controlAffinity: ListTileControlAffinity.leading),

              CheckboxListTile(
                  value: widget.agreeHnS,
                  onChanged: (v)=> widget.onChange(hns: v ?? false),
                  checkColor: Colors.white, activeColor: Colors.white.withOpacity(0.25),
                  title: const Text("I agree to platform Health & Safety rules.", style: TextStyle(color: Colors.white)),
                  controlAffinity: ListTileControlAffinity.leading),

              const SizedBox(height: 12),
              const SubTitle("Policies Acknowledgement"),
              PolicyTile(
                title: "Terms and Conditions Agreement",
                body: "Read Agreement",
                value: widget.ackTrainerAgreement,
                onChanged: (v)=> widget.onChange(agr: v),
                onRead: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const LegalPage(
                        title: 'Terms & Conditions',
                        assetHtmlPath: 'terms', // placeholder (not used in current implementation)
                      ),
                    ),
                  );
                },
              ),
              PolicyTile(
                title: "Refund and Cancellation Policy",
                body: "Read Agreement",
                value: widget.ackCancellationPolicy,
                onChanged: (v)=> widget.onChange(cancel: v),
                onRead: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const LegalPage(
                        title: 'Refund & Cancellation Policy',
                        assetHtmlPath: 'refund',
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 16),

              // ---------------- Razorpay Payment UI ----------------
      const SubTitle("Payment (Activation fee)"),
      const Text("Pay the one-time activation fee securely via Razorpay.", style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 12),
              Center(
                child: Column(
                  children: [
        const _Bullet('Dashboard access unlocked after payment'),
        const _Bullet('Client booking system'),
        const _Bullet('Start earning instantly'),
        const SizedBox(height: 8),
                    if (!widget.isPaid)
                      ElevatedButton.icon(
                        onPressed: _processing ? null : _startPayment,
                        icon: const Icon(Icons.credit_card),
                        label: Text(_processing ? 'Processing…' : 'Pay ₹$_activationFee Securely'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.white12),
                      )
                    else
                      const Text('Payment completed ✔', style: TextStyle(color: Colors.greenAccent)),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              const SubTitle("E-Sign (Handwritten) — optional"),
              SignaturePad(
                onBytes: (bytes){
                  widget.onSignatureBytes(bytes);
                },
              ),
              const SizedBox(height: 12),
              field("Date (DD/MM/YYYY)", widget.esignDate, keyboardType: TextInputType.number, inputFormatters: dateDDMMYYYYFormatters(), validator: (v){ if (!notEmpty(v)) return "Enter date"; return RegExp(r'^\d{2}/\d{2}/\d{4}$').hasMatch(v!.trim()) ? null : "Use DD/MM/YYYY"; }, ),

              const SizedBox(height: 8),
              const Text("By submitting, you agree that the above information is true and you consent to the policies.",
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
            ]),
          ),
        ),
      ),
    );
  }
}
class _Bullet extends StatelessWidget {
  final String text;
  const _Bullet(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          const Text("• ", style: TextStyle(color: Colors.white70)),
          Expanded(child: Text(text, style: const TextStyle(color: Colors.white70)))
        ],
      ),
    );
  }
}