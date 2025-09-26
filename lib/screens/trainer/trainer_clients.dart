import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../widgets/glass_card.dart';

class TrainerClients extends StatelessWidget {
  const TrainerClients({super.key});

  @override
  Widget build(BuildContext context) {
    final clients = [
      {"name": "Amit Sharma", "sessions": "12"},
      {"name": "Neha Verma", "sessions": "7"},
      {"name": "Rahul Jain", "sessions": "4"},
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Clients"),
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
          itemCount: clients.length,
          itemBuilder: (_, i) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GlassCard(
              onTap: () {},
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.white24,
                  child: Text(clients[i]["name"]![0],
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                title: Text(clients[i]["name"]!, style: const TextStyle(color: Colors.white)),
                subtitle: Text("${clients[i]["sessions"]} sessions",
                    style: const TextStyle(color: Colors.white70)),
                trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white54),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
  