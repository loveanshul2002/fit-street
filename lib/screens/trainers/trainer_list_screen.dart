import 'package:flutter/material.dart';
import '../../widgets/glass_card.dart';
import '../../config/app_colors.dart';
import 'trainer_profile_screen.dart';

class TrainerListScreen extends StatelessWidget {
  const TrainerListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final trainers = [
      {"name": "Rahul Sharma", "speciality": "Yoga", "price": "₹500"},
      {"name": "Sneha Kapoor", "speciality": "Strength", "price": "₹700"},
      {"name": "Amit Singh", "speciality": "Zumba", "price": "₹600"},
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Find Trainers"),
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
          itemCount: trainers.length,
          itemBuilder: (context, index) {
            final trainer = trainers[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: GlassCard(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => TrainerProfileScreen(trainer: trainer)),
                ),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundImage: AssetImage("assets/image/trainer.png"),
                  ),
                  title: Text(trainer["name"]!,
                      style: const TextStyle(color: Colors.white)),
                  subtitle: Text(trainer["speciality"]!,
                      style: const TextStyle(color: Colors.white70)),
                  trailing: Text(trainer["price"]!,
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
