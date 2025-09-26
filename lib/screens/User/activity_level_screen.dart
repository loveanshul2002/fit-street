// lib/screens/user/activity_level_screen.dart
import 'package:flutter/material.dart';
import '../../widgets/glass_card.dart';
import '../../config/app_colors.dart';
import 'profile_fill_screen.dart';

class ActivityLevelScreen extends StatefulWidget {
  const ActivityLevelScreen({super.key});

  @override
  State<ActivityLevelScreen> createState() => _ActivityLevelScreenState();
}

class _ActivityLevelScreenState extends State<ActivityLevelScreen> {
  String? selected; // Beginner / Intermediate / Advanced

  Widget _levelButton(String label) {
    final sel = selected == label;
    return InkWell(
      onTap: () => setState(() => selected = label),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: sel ? Colors.white12 : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: sel ? AppColors.primary.withOpacity(0.9) : Colors.white12),
        ),
        child: Center(child: Text(label, style: TextStyle(color: sel ? Colors.white : Colors.white70, fontSize: 16, fontWeight: sel ? FontWeight.w700 : FontWeight.w500))),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final levels = ['Beginner', 'Intermediate', 'Advanced'];
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(gradient: LinearGradient(colors: [AppColors.primary, AppColors.secondary], begin: Alignment.topLeft, end: Alignment.bottomRight)),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 18),
            child: Column(
              children: [
                Row(children: [IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back, color: Colors.white)), const SizedBox(width: 6), const Expanded(child: Text("Physical Activity Level?", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold))),]),
                const SizedBox(height: 8),
                const Text("Choose your regular activity level. This will help personalize plans for you.", style: TextStyle(color: Colors.white70), textAlign: TextAlign.center),
                const SizedBox(height: 18),

                Expanded(
                  child: GlassCard(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          _levelButton(levels[0]),
                          _levelButton(levels[1]),
                          _levelButton(levels[2]),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: BorderSide(color: Colors.white.withOpacity(0.25)), padding: const EdgeInsets.symmetric(vertical: 14)), child: const Text("Back"))),
                  const SizedBox(width: 12),
                  Expanded(child: ElevatedButton(onPressed: () {
                    if (selected == null) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a level")));
                      return;
                    }
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileFillScreen()));
                  }, style: ElevatedButton.styleFrom(backgroundColor: Colors.white12, padding: const EdgeInsets.symmetric(vertical: 14)), child: const Text("Continue", style: TextStyle(color: Colors.white)))),]),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
