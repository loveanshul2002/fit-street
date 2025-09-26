import 'package:flutter/material.dart';
import '../../widgets/glass_card.dart';
import '../../config/app_colors.dart';

class CounsellorScreen extends StatelessWidget {
  const CounsellorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final counsellors = [
      {"name": "Dr. Meera Kapoor", "speciality": "Psychologist", "price": "₹800"},
      {"name": "Ravi Sharma", "speciality": "Nutritionist", "price": "₹600"},
      {"name": "Anita Singh", "speciality": "Physiotherapist", "price": "₹700"},
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Find Counsellors"),
        backgroundColor: Colors.transparent,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primary, AppColors.secondary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: counsellors.length,
          itemBuilder: (context, index) {
            final counsellor = counsellors[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: GlassCard(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Booking ${counsellor['name']} soon!")),
                  );
                },
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundImage: AssetImage("assets/image/counsellor.png"),
                  ),
                  title: Text(counsellor["name"]!,
                      style: const TextStyle(color: Colors.white)),
                  subtitle: Text(counsellor["speciality"]!,
                      style: const TextStyle(color: Colors.white70)),
                  trailing: Text(counsellor["price"]!,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
