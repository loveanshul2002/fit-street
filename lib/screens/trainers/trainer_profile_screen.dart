import 'package:flutter/material.dart';
import '../../widgets/glass_card.dart';
import '../../config/app_colors.dart';

class TrainerProfileScreen extends StatelessWidget {
  final Map<String, String> trainer;
  const TrainerProfileScreen({super.key, required this.trainer});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(trainer["name"] ?? "Trainer"),
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
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Trainer Info Card
              GlassCard(
                child: Column(
                  children: [
                    const CircleAvatar(
                      radius: 50,
                      backgroundImage: AssetImage("assets/image/trainer.png"),
                    ),
                    const SizedBox(height: 12),
                    Text(trainer["name"]!,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 20)),
                    Text(trainer["speciality"]!,
                        style: const TextStyle(color: Colors.white70)),
                    Text(trainer["price"]!,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Tabs
              Expanded(
                child: DefaultTabController(
                  length: 3,
                  child: Column(
                    children: const [
                      TabBar(
                        tabs: [
                          Tab(text: "About"),
                          Tab(text: "Availability"),
                          Tab(text: "Reviews"),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            Center(
                                child: Text("Certified trainer with 5 years experience",
                                    style: TextStyle(color: Colors.white))),
                            Center(
                                child: Text("Available slots: Tomorrow 7AM, 6PM",
                                    style: TextStyle(color: Colors.white))),
                            Center(
                                child: Text("⭐ Rated 4.8 by 120 users",
                                    style: TextStyle(color: Colors.white))),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
              ),

              // Book Button
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding:
                  const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Booking flow coming soon!")),
                  );
                },
                child: const Text("Book Session",
                    style: TextStyle(color: Colors.white, fontSize: 16)),
              )
            ],
          ),
        ),
      ),
    );
  }
}
