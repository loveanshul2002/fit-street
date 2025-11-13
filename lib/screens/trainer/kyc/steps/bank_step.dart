import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../widgets/glass_card.dart';
import '../utils/ui_helpers.dart';

class BankStep extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController accName, ifsc, bankName, branch, upi;

  const BankStep({
    super.key,
    required this.formKey,
    required this.accName,
    required this.ifsc,
    required this.bankName,
    required this.branch,
    required this.upi,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: GlassCard(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Section("2. Bank & Payout"),
                field("Account Number", accName, validator: req),
                field("IFSC Code", ifsc, validator: req,),


                field("Bank Name", bankName, validator: req),

                field("UPI ID (optional)", upi, validator: (v){
                  if(v!=null && v.isNotEmpty && !v.contains('@')) {
                    return 'Invalid UPI ID';
                  }
                  return null;
                }, inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))]),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
