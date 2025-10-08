// lib/screens/user/goal_screen.dart
import 'package:flutter/material.dart';
import '../../widgets/glass_card.dart';
import '../../config/app_colors.dart';
import 'activity_level_screen.dart';
import '../../utils/profile_storage.dart' show saveGoal;

class GoalScreen extends StatefulWidget {
  const GoalScreen({super.key});

  @override
  State<GoalScreen> createState() => _GoalScreenState();
}

class _GoalScreenState extends State<GoalScreen> {
  final List<String> goals = [
    'Get fitter',
    'Gain weight',
    'Lose weight',
    'Build muscle',
    'Improve endurance',
    'Other'
  ];
  final Set<String> selected = {};
  final TextEditingController otherCtrl = TextEditingController();

  @override
  void dispose() {
    otherCtrl.dispose();
    super.dispose();
  }

  Widget _goalTile(String title) {
    final sel = selected.contains(title);
    return InkWell(
      onTap: () => setState(() {
        if (sel)
          selected.remove(title);
        else
          selected.add(title);
      }),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: sel ? Colors.white12 : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: sel ? Colors.white24 : Colors.white12),
        ),
        child: Row(
          children: [
            Expanded(child: Text(title, style: TextStyle(color: sel ? Colors.white : Colors.white70, fontSize: 16))),
            if (sel) Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.95), shape: BoxShape.circle),
              child: const Icon(Icons.check, size: 16, color: Colors.white),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [AppColors.primary, AppColors.secondary], begin: Alignment.topLeft, end: Alignment.bottomRight),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 18),
            child: Column(
              children: [
                Row(children: [
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back, color: Colors.white)),
                  const SizedBox(width: 6),
                  const Expanded(child: Text("What is Your Goal?", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold))),
                ]),
                const SizedBox(height: 8),
                const Text("You can choose more than one. Don't worry, you can always change it later.", style: TextStyle(color: Colors.white70), textAlign: TextAlign.center),
                const SizedBox(height: 14),

                Expanded(
                  child: GlassCard(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            for (final g in goals) _goalTile(g),
                            if (selected.contains('Other')) ...[
                              const SizedBox(height: 8),
                              TextField(
                                controller: otherCtrl,
                                style: const TextStyle(color: Colors.white),
                                maxLines: 3,
                                decoration: InputDecoration(
                                  hintText: 'Describe your goal',
                                  hintStyle: const TextStyle(color: Colors.white54),
                                  filled: true,
                                  fillColor: Colors.white12,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),
                // Bottom actions: Back / Continue
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: BorderSide(color: Colors.white.withOpacity(0.25)), padding: const EdgeInsets.symmetric(vertical: 14)),
                      child: const Text("Back"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        // Build a combined list: selected presets + optional Other text
                        final List<String> items = selected
                            .where((g) => g != 'Other')
                            .map((s) => s.trim())
                            .where((s) => s.isNotEmpty)
                            .toList();
                        final otherText = otherCtrl.text.trim();
                        if (selected.contains('Other')) {
                          if (otherText.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Please describe your 'Other' goal.")),
                            );
                            return;
                          }
                          items.add(otherText);
                        }
                        if (items.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please select at least one goal.')),
                          );
                          return;
                        }
                        // Save as a comma-separated string so backend gets all goals together
                        final combined = items.join(', ');
                        await saveGoal(combined);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ActivityLevelScreen()),
                        );
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.white12, padding: const EdgeInsets.symmetric(vertical: 14)),
                      child: const Text("Continue", style: TextStyle(color: Colors.white)),
                    ),
                  )
                ]),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
