// lib/screens/user/profile_completion_wizard.dart
import 'package:flutter/material.dart';
import '../../widgets/glass_card.dart';
import '../../config/app_colors.dart';
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
      appBar: AppBar(
        title: const Text("Complete Profile"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [AppColors.primary, AppColors.secondary], begin: Alignment.topLeft, end: Alignment.bottomRight),
        ),
        child: SafeArea(
          child: Center(
            child: GlassCard(
              child: Padding(
                padding: const EdgeInsets.all(18.0),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text("Completing your profile", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 8),
                  const Text("We’ll collect a few details (weight, height, goals, activity level and profile) so you can book trainers", style: TextStyle(color: Colors.white70), textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  _saving ? const CircularProgressIndicator() : ElevatedButton(
                    onPressed: _runFlow,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.white12),
                    child: const Text("Start", style: TextStyle(color: Colors.white)),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
