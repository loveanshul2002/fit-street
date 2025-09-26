  import 'package:flutter/material.dart';
  import '../../config/app_colors.dart';
  import '../../widgets/glass_card.dart';

  class TrainerSchedule extends StatelessWidget {
    const TrainerSchedule({super.key});

    @override
    Widget build(BuildContext context) {
      final slots = [
        {"time": "7:00 AM", "client": "Amit Sharma", "status": "Confirmed"},
        {"time": "9:00 AM", "client": "Neha Verma", "status": "Pending"},
        {"time": "6:30 PM", "client": "Rahul Jain", "status": "Confirmed"},
      ];

      return Scaffold(
        appBar: AppBar(
          title: const Text("My Schedule"),
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
            itemCount: slots.length,
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GlassCard(
                onTap: () {},
                child: ListTile(
                  leading: const Icon(Icons.access_time, color: Colors.white),
                  title: Text(slots[i]["time"]!, style: const TextStyle(color: Colors.white)),
                  subtitle: Text(slots[i]["client"]!, style: const TextStyle(color: Colors.white70)),
                  trailing: Text(slots[i]["status"]!,
                      style: TextStyle(
                          color: slots[i]["status"] == "Confirmed"
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
