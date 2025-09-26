import 'dart:typed_data';
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

              const SizedBox(height: 12),
              const SubTitle("E-Sign (Handwritten) — optional"),
              SignaturePad(
                onBytes: (bytes){
                  _sigBytes = bytes;
                  widget.onSignatureBytes(bytes);
                },
              ),
              const SizedBox(height: 12),
              field("Date (DD/MM/YYYY)", widget.esignDate, keyboardType: TextInputType.number, inputFormatters: dateDDMMYYYYFormatters(), validator: (v){ if (!notEmpty(v)) return "Enter date"; return RegExp(r'^\d{2}/\d{2}/\d{4}$').hasMatch(v!.trim()) ? null : "Use DD/MM/YYYY"; }, ),

              // NOTE: Date / name fields removed from UI because validation no longer requires them.
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
