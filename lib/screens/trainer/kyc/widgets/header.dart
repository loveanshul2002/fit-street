// lib/screens/trainer/widgets/header.dart
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import '../../../../widgets/glass_card.dart';

class Header extends StatelessWidget {
  final String trainerName;
  final String cityCountry;
  final String? trainerUniqueId;
  final String? trainerImageURL;
  final bool isAvailable;
  final void Function(bool) onToggleAvailability;
  final VoidCallback onOpenAvailabilityEditor;
  final VoidCallback onNotifications;

  const Header({
    super.key,
    required this.trainerName,
    required this.cityCountry,
    this.trainerUniqueId,
    this.trainerImageURL,
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
          CircleAvatar(
            radius: 22,
            backgroundColor: Colors.white12,
            foregroundImage: (trainerImageURL != null && trainerImageURL!.isNotEmpty)
                ? NetworkImage(trainerImageURL!)
                : null,
            child: Text(trainerName.isNotEmpty ? trainerName[0] : "A", style: const TextStyle(color: Colors.white)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("Hi, $trainerName", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(cityCountry, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ])),
          if (trainerUniqueId != null && trainerUniqueId!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    constraints: const BoxConstraints(maxWidth: 140),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.25), width: 0.75),
                    ),
                    child: Text(
                      'ID: ${trainerUniqueId!}',
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            ),

          Column(children: [
            Text(isAvailable ? "Available" : "Available", style: const TextStyle(color: Colors.white, fontSize: 12)),
            Row(children: [
              Switch(value: isAvailable, activeColor: Colors.greenAccent, inactiveThumbColor: Colors.redAccent, onChanged: onToggleAvailability),
            ])
          ])
        ]),
      ),
    );
  }
}
