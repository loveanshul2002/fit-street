import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../../../widgets/glass_card.dart';
import '../utils/ui_helpers.dart';
import '../widgets/policy_tile.dart';
import '../../../legal/legal_page.dart';
import '../widgets/signature_pad.dart';
import '../utils/input_formatters.dart';
// payment removed from consent; Razorpay logic moved to PaymentStep

class ConsentStep extends StatefulWidget {
  final bool noCriminalRecord, agreeHnS, ackTrainerAgreement, ackCancellationPolicy;
  final void Function({
  bool? noCrime, bool? hns, bool? agr, bool? cancel, bool? payout, bool? privacy
  }) onChange;

  // kept for compatibility; no longer required for validation
  final TextEditingController esignName;
  final TextEditingController esignDate;
  final ValueChanged<Uint8List?> onSignatureBytes;

  // Payment status passed in (readonly now)
  final bool isPaid;

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

  @override
  void initState() {
    super.initState();
    if (widget.esignDate.text.trim().isEmpty) {
      final now = DateTime.now();
      final today = '${now.day.toString().padLeft(2,'0')}/${now.month.toString().padLeft(2,'0')}/${now.year}';
      widget.esignDate.text = today;
    }
  }

  // local toast removed (payment UI stripped); rely on parent wizard to show errors.

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
                  checkColor: Colors.white, activeColor: Color.fromARGB((0.25 * 255).round(), 255, 255, 255),
                  title: const Text("I confirm that I have no criminal record.", style: TextStyle(color: Colors.white)),
                  controlAffinity: ListTileControlAffinity.leading),

              CheckboxListTile(
                  value: widget.agreeHnS,
                  onChanged: (v)=> widget.onChange(hns: v ?? false),
                  checkColor: Colors.white, activeColor: Color.fromARGB((0.25 * 255).round(), 255, 255, 255),
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

              // Payment step removed; display payment status only
              if (widget.isPaid)
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Text('Activation payment confirmed ✔', style: TextStyle(color: Colors.greenAccent)),
                )
              else
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Text('Activation payment pending (complete in previous step).', style: TextStyle(color: Colors.orangeAccent)),
                ),

              const SubTitle("E-Sign (Handwritten) — optional"),
              SignaturePad(
                onBytes: (bytes){
                  widget.onSignatureBytes(bytes);
                },
              ),
              const SizedBox(height: 12),
              field(
                "Date (DD/MM/YYYY)",
                widget.esignDate,
                readOnly: true,
                keyboardType: TextInputType.number,
                inputFormatters: dateDDMMYYYYFormatters(),
                validator: (v){
                  if (!notEmpty(v)) return "Enter date"; // should never happen after auto-fill
                  return RegExp(r'^\d{2}/\d{2}/\d{4}$').hasMatch(v!.trim()) ? null : "Use DD/MM/YYYY";
                },
              ),

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
// Bullet widget removed with payment UI