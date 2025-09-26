import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../widgets/glass_card.dart';

class TrainerPayments extends StatelessWidget {
  const TrainerPayments({super.key});

  @override
  Widget build(BuildContext context) {
    final payouts = [
      {"date": "Sep 01", "amount": "₹4,500", "status": "Paid"},
      {"date": "Aug 25", "amount": "₹3,200", "status": "Paid"},
      {"date": "Aug 18", "amount": "₹2,700", "status": "Pending"},
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Payments"),
        backgroundColor: Colors.transparent,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
              colors: [AppColors.primary, AppColors.secondary],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
        ),
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: payouts.length,
          itemBuilder: (_, i) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GlassCard(
              child: ListTile(
                leading: const Icon(Icons.receipt_long, color: Colors.white),
                title: Text(payouts[i]["amount"]!, style: const TextStyle(color: Colors.white)),
                subtitle: Text(payouts[i]["date"]!, style: const TextStyle(color: Colors.white70)),
                trailing: Text(payouts[i]["status"]!,
                    style: TextStyle(
                        color: payouts[i]["status"] == "Paid"
                            ? Colors.greenAccent : Colors.orangeAccent,
                        fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
