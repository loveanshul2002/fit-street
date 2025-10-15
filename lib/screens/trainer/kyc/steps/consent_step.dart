import 'dart:typed_data';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import '../../../../widgets/glass_card.dart';
import '../utils/ui_helpers.dart';
import '../widgets/policy_tile.dart';
import '../widgets/signature_pad.dart';
import '../utils/input_formatters.dart';

class ConsentStep extends StatefulWidget {
  final bool noCriminalRecord, agreeHnS, ackTrainerAgreement, ackCancellationPolicy, ackPayoutPolicy, ackPrivacyPolicy;
  final void Function({
  bool? noCrime, bool? hns, bool? agr, bool? cancel, bool? payout, bool? privacy
  }) onChange;

  // kept for compatibility; no longer required for validation
  final TextEditingController esignName;
  final TextEditingController esignDate;
  final ValueChanged<Uint8List?> onSignatureBytes;

  // NEW: payment screenshot handling
  final String? initialPaymentScreenshotPath;
  final ValueChanged<String?>? onPaymentScreenshotSelected; // called with path or null when removed

  const ConsentStep({
    super.key,
    required this.noCriminalRecord,
    required this.agreeHnS,
    required this.ackTrainerAgreement,
    required this.ackCancellationPolicy,
    required this.ackPayoutPolicy,
    required this.ackPrivacyPolicy,
    required this.onChange,
    required this.esignName,
    required this.esignDate,
    required this.onSignatureBytes,
    this.initialPaymentScreenshotPath,
    this.onPaymentScreenshotSelected,
  });

  /// VALIDATION: NOTE — e-sign matching / date checks removed.
  /// Now only verifies background declarations and policy acknowledgements.
  static bool validateConsent({
    required Uint8List? signaturePng, // kept for compatibility — optional now
    required String fullName,         // ignored for validation
    required String esignName,        // ignored
    required String esignDate,        // ignored
    required bool noCriminalRecord,
    required bool agreeHnS,
    required bool ackTrainerAgreement,
    required bool ackCancellationPolicy,
    required bool ackPayoutPolicy,
    required bool ackPrivacyPolicy,
    required void Function(String) toast,
  }) {
    // Check background declarations
    if (!noCriminalRecord || !agreeHnS) {
      toast("Please confirm background declarations.");
      return false;
    }

    // Check policy acknowledgements
    if (!ackTrainerAgreement || !ackCancellationPolicy || !ackPayoutPolicy || !ackPrivacyPolicy) {
      toast("Please open & acknowledge all policies.");
      return false;
    }

    // Signature/date/name are optional now — no validation required.
    return true;
  }

  @override
  State<ConsentStep> createState() => _ConsentStepState();
}

class _ConsentStepState extends State<ConsentStep> {
  Uint8List? _sigBytes;
  String? _paymentScreenshotPath;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _paymentScreenshotPath = widget.initialPaymentScreenshotPath;
  }

  Future<void> _pickPaymentScreenshot() async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2000,
        maxHeight: 2000,
        imageQuality: 85,
      );
      if (picked == null) return;
      setState(() => _paymentScreenshotPath = picked.path);
      if (widget.onPaymentScreenshotSelected != null) widget.onPaymentScreenshotSelected!(picked.path);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to pick image: $e')));
    }
  }

  void _removePaymentScreenshot() {
    setState(() => _paymentScreenshotPath = null);
    if (widget.onPaymentScreenshotSelected != null) widget.onPaymentScreenshotSelected!(null);
  }

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
                title: "Trainer Agreement",
                body: "Your trainer agreement: conduct, service standards, safety, liability, and termination.",
                value: widget.ackTrainerAgreement,
                onChanged: (v)=> widget.onChange(agr: v),
              ),
              PolicyTile(
                title: "Cancellation & No-Show Policy",
                body: "Window, penalties, what counts as no-show.",
                value: widget.ackCancellationPolicy,
                onChanged: (v)=> widget.onChange(cancel: v),
              ),
              PolicyTile(
                title: "Payout & Fee Deduction Policy",
                body: "Payout schedule, platform fees, refunds, chargebacks.",
                value: widget.ackPayoutPolicy,
                onChanged: (v)=> widget.onChange(payout: v),
              ),
              PolicyTile(
                title: "Data & Privacy Policy",
                body: "Data we collect, usage, retention, sharing, rights.",
                value: widget.ackPrivacyPolicy,
                onChanged: (v)=> widget.onChange(privacy: v),
              ),

              const SizedBox(height: 16),

              // ---------------- Payment Method UI ----------------
              const SubTitle("Payment (Activation fee)"),
              const Text("Pay the one-time activation fee and upload the screenshot as proof.", style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 10),

              Center(
                child: Column(
                  children: [
                    // QR + UPI id (use the same asset you have in register wizard)
                    Container(
                      height: 160,
                      width: 160,
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      clipBehavior: Clip.hardEdge,
                      child: Image.asset(
                        'assets/image/upi-qr.jpeg',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Center(child: Text('QR', style: TextStyle(color: Colors.white70))),
                      ),
                    ),

                    const SizedBox(height: 8),
                    const Text("UPI ID: fitstreet@upi", style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 12),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _pickPaymentScreenshot,
                          icon: const Icon(Icons.photo),
                          label: const Text("Choose Screenshot"),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.white12),
                        ),
                        const SizedBox(width: 12),
                        if (_paymentScreenshotPath != null && _paymentScreenshotPath!.isNotEmpty)
                          Stack(
                            alignment: Alignment.topRight,
                            children: [
                              GestureDetector(
                                onTap: () {
                                  // preview
                                  showDialog(
                                    context: context,
                                    builder: (_) => Dialog(
                                      child: Image.file(File(_paymentScreenshotPath!)),
                                    ),
                                  );
                                },
                                child: Container(
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.white24),
                                  ),
                                  clipBehavior: Clip.hardEdge,
                                  child: Image.file(File(_paymentScreenshotPath!), fit: BoxFit.cover),
                                ),
                              ),
                              Positioned(
                                right: -6,
                                top: -6,
                                child: IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.white70, size: 18),
                                  onPressed: _removePaymentScreenshot,
                                  tooltip: 'Remove screenshot',
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // --- User asked to add this commented block here ---
              const SizedBox(height: 16),
                         const GlassCard(
                             child: Padding(
                               padding: EdgeInsets.all(12),
                               child: Column(
                                 crossAxisAlignment: CrossAxisAlignment.start,
                                 children: [
                                   Text("You’ll get instantly:", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                                   SizedBox(height: 8),
                                   _Bullet("Premium T-shirt 🎽"),
                                   _Bullet("FitStreet ID card 🪪"),
                                   _Bullet("Access to Dashboard (book clients, earn ₹₹₹)"),
                                 ],
                               ),
                             ),
                           ),

              const SizedBox(height: 16),

              const SubTitle("E-Sign (Handwritten) — optional"),
              SignaturePad(
                onBytes: (bytes){
                  _sigBytes = bytes;
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