// lib/screens/trainer/widgets/header.dart
import 'package:flutter/material.dart';
import '../../../../config/app_colors.dart';
import '../../../../widgets/glass_card.dart';

class Header extends StatelessWidget {
  final String trainerName;
  final String cityCountry;
  final bool isAvailable;
  final void Function(bool) onToggleAvailability;
  final VoidCallback onOpenAvailabilityEditor;
  final VoidCallback onNotifications;

  const Header({
    super.key,
    required this.trainerName,
    required this.cityCountry,
    required this.isAvailable,
    required this.onToggleAvailability,
    required this.onOpenAvailabilityEditor,
    required this.onNotifications,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(children: [
          CircleAvatar(radius: 22, backgroundColor: Colors.white12, child: Text(trainerName.isNotEmpty ? trainerName[0] : "A", style: const TextStyle(color: Colors.white))),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("Hi, $trainerName", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(cityCountry, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ])),
          IconButton(onPressed: onNotifications, icon: const Icon(Icons.notifications, color: Colors.white)),
          const SizedBox(width: 6),
          Column(children: [
            Text(isAvailable ? "Available" : "Available", style: const TextStyle(color: Colors.white, fontSize: 12)),
            Row(children: [
              Switch(value: isAvailable, activeColor: Colors.greenAccent, inactiveThumbColor: Colors.redAccent, onChanged: onToggleAvailability),
              IconButton(onPressed: onOpenAvailabilityEditor, icon: const Icon(Icons.calendar_today, color: Colors.white70))
            ])
          ])
        ]),
      ),
    );
  }
}
