// lib/screens/user/profile_completion_wizard.dart
import 'package:flutter/material.dart';
import 'dart:ui' show ImageFilter;
import '../../utils/role_storage.dart';
import 'weight_picker_screen.dart';
import 'height_picker_screen.dart';
import 'goal_screen.dart';
import 'activity_level_screen.dart';
import 'profile_fill_screen.dart';

/// A simple orchestrator that walks user through:
/// Weight -> Height -> Goal -> Activity Level -> Profile Fill
/// On success it marks profileComplete = true and returns to Home.
class ProfileCompletionWizard extends StatefulWidget {
  const ProfileCompletionWizard({super.key});

  @override
  State<ProfileCompletionWizard> createState() => _ProfileCompletionWizardState();
}

class _ProfileCompletionWizardState extends State<ProfileCompletionWizard> {
  bool _saving = false;

  Future<void> _runFlow() async {
    // 1) Weight
    final weight = await Navigator.push<int>(
      context,
      MaterialPageRoute(builder: (_) => const WeightPickerScreen(initialWeight: 65)),
    );
    if (weight == null) return;

    // 2) Height (expect Map<String,int> { 'ft':.., 'in': .. } or you can adapt)
    final height = await Navigator.push<Map<String,int>?>(
      context,
      MaterialPageRoute(builder: (_) => const HeightPickerScreen()),
    );
    if (height == null) return;

    // 3) Goal (returns List<String> or single)
    final goals = await Navigator.push<List<String>?>(
      context,
      MaterialPageRoute(builder: (_) => const GoalScreen()),
    );
    if (goals == null) return;

    // 4) Activity / Physical Level
    final activity = await Navigator.push<String?>(
      context,
      MaterialPageRoute(builder: (_) => const ActivityLevelScreen()),
    );
    if (activity == null) return;

    // 5) Profile fill (this full form; ProfileFillScreen will save name from prefs and return)
    final profileResult = await Navigator.push<bool?>(
      context,
      MaterialPageRoute(builder: (_) => const ProfileFillScreen()),
    );
    if (profileResult == null) return;

    // All done -> persist profileComplete
    setState(() => _saving = true);
    try {
      // TODO: send the collected payload (weight/height/goals/activity/profile) to backend
      await saveProfileComplete(true);
      // On success, go to home and clear stack
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/home', (r) => false);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void initState() {
    super.initState();
    // Start the flow after first frame so this screen shows a helpful message
    WidgetsBinding.instance.addPostFrameCallback((_) => _runFlow());
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
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(height: 6),
                              const Text(
                                'Complete Profile',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'We’ll collect a few details (weight, height, goals, activity level and profile) so you can book trainers',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white70),
                              ),
                              const SizedBox(height: 16),
                              if (_saving)
                                const Center(child: CircularProgressIndicator())
                              else
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: _runFlow,
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
                                                'Start',
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
