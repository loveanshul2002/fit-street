// lib/screens/user/activity_level_screen.dart
import 'package:flutter/material.dart';
import 'dart:ui' show ImageFilter;
import 'profile_fill_screen.dart';
import '../../utils/profile_storage.dart' show savePhysicalLevel;

class ActivityLevelScreen extends StatefulWidget {
  const ActivityLevelScreen({super.key});

  @override
  State<ActivityLevelScreen> createState() => _ActivityLevelScreenState();
}

class _ActivityLevelScreenState extends State<ActivityLevelScreen> {
  String? selected; // Beginner / Intermediate / Advanced

  Widget _levelButton(String label) {
    final sel = selected == label;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
        child: InkWell(
          onTap: () => setState(() => selected = label),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
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
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: sel ? Colors.white : Colors.white70,
                      fontSize: 16,
                      fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
                if (sel)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        margin: const EdgeInsets.only(left: 8),
                        height: 26,
                        width: 26,
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
                        child: const Icon(Icons.check, size: 14, color: Colors.orange),
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
    final levels = ['Beginner', 'Intermediate', 'Advanced'];
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
                              const SizedBox(height: 60),
                              const Text(
                                'Physical Activity Level?',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Choose your regular activity level. This will help personalize plans for you.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white70),
                              ),
                              const SizedBox(height: 16),
                              Expanded(
                                child: SingleChildScrollView(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Column(
                                    children: [
                                      _levelButton(levels[0]),
                                      _levelButton(levels[1]),
                                      _levelButton(levels[2]),
                                    ],
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () async {
                                    if (selected == null) {
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a level')));
                                      return;
                                    }
                                    await savePhysicalLevel(selected!);
                                    if (!context.mounted) return;
                                    Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileFillScreen()));
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
                                          filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
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
                            top: 8,
                            left: 8,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.white.withOpacity(0.16),
                                        Colors.white.withOpacity(0.06),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: Colors.white.withOpacity(0.28), width: 0.75),
                                  ),
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
