// lib/screens/user/goal_screen.dart
import 'package:flutter/material.dart';
import 'dart:ui' show ImageFilter;
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
        child: InkWell(
          onTap: () => setState(() {
            if (sel) {
              selected.remove(title);
            } else {
              selected.add(title);
            }
          }),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(sel ? 0.16 : 0.12),
                  Colors.white.withOpacity(sel ? 0.08 : 0.04),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(sel ? 0.32 : 0.24), width: 0.75),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(color: sel ? Colors.white : Colors.white70, fontSize: 16, fontWeight: sel ? FontWeight.w600 : FontWeight.w500),
                  ),
                ),
                if (sel)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 1, sigmaY: 1),
                      child: Container(
                        height: 28,
                        width: 28,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withOpacity(0.18),
                              Colors.white.withOpacity(0.08),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withOpacity(0.3), width: 0.75),
                        ),
                        child: const Icon(Icons.check, size: 16, color: Colors.orange),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/image/bg.png'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(Colors.black54, BlendMode.darken),
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 1, sigmaY: 1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withOpacity(0.15),
                            Colors.white.withOpacity(0.06),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.28), width: 0.75),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, 10)),
                        ],
                      ),
                      child: Stack(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(height: 6),
                              const Text(
                                'What is Your Goal?',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                "You can choose more than one. Don't worry, you can always change it later.",
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white70),
                              ),
                              const SizedBox(height: 16),
                              Expanded(
                                child: SingleChildScrollView(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Column(
                                    children: [
                                      for (final g in goals) _goalTile(g),
                                      if (selected.contains('Other')) ...[
                                        const SizedBox(height: 8),
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(12),
                                          child: BackdropFilter(
                                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                            child: Container(
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: [
                                                    Colors.white.withOpacity(0.12),
                                                    Colors.white.withOpacity(0.04),
                                                  ],
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                ),
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(color: Colors.white.withOpacity(0.24), width: 0.75),
                                              ),
                                              child: TextField(
                                                controller: otherCtrl,
                                                style: const TextStyle(color: Colors.white),
                                                maxLines: 3,
                                                decoration: const InputDecoration(
                                                  hintText: 'Describe your goal',
                                                  hintStyle: TextStyle(color: Colors.white54),
                                                  border: InputBorder.none,
                                                  isCollapsed: false,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: double.infinity,
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
                                  style: ElevatedButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    elevation: 0,
                                  ),
                                  child: SizedBox(
                                    height: 64,
                                    child: Center(
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(28),
                                        child: BackdropFilter(
                                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [
                                                  Colors.white.withOpacity(0.16),
                                                  Colors.white.withOpacity(0.06),
                                                ],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              ),
                                              borderRadius: BorderRadius.circular(28),
                                              border: Border.all(color: Colors.white.withOpacity(0.28), width: 0.75),
                                            ),
                                            child: const Text(
                                              'Continue',
                                              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          // Glass back button (top-left)
                          Positioned(
                            top: 1,
                            left: 1,


                                  child: Material(
                                    type: MaterialType.transparency,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(14),
                                      onTap: () => Navigator.pop(context),
                                      child: const SizedBox(
                                        height: 40,
                                        width: 40,
                                        child: Icon(Icons.arrow_back, color: Colors.white, size: 20),
                                      ),
                                    ),
                                  ),
                                ),



                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
