// lib/screens/user/gender_selection_screen.dart
import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../widgets/glass_card.dart';
import 'age_picker_screen.dart';
import '../home/home_screen.dart';
import '../../utils/role_storage.dart';
import '../../utils/user_role.dart';

enum GenderOption { male, female }

class GenderSelectionScreen extends StatefulWidget {
  const GenderSelectionScreen({super.key});

  @override
  State<GenderSelectionScreen> createState() => _GenderSelectionScreenState();
}

class _GenderSelectionScreenState extends State<GenderSelectionScreen> {
  GenderOption? _selected;

  void _onSelect(GenderOption g) => setState(() => _selected = g);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.primaryGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22.0, vertical: 20),
            child: Column(
              children: [
                const SizedBox(height: 12),
                const Text('Tell Us About Yourself', textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 8),
                const Text('To give you a better experience and results\nwe need to know your gender.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
                const Spacer(),

                Column(
                  children: [
                    _GenderCircle(label: 'Male', icon: Icons.male, selected: _selected == GenderOption.male, onTap: () => _onSelect(GenderOption.male), gradient: const LinearGradient(colors: [Color(0xFF9E9E9E), Color(0xFF9E9E9E)])),
                    const SizedBox(height: 28),
                    _GenderCircle(label: 'Female', icon: Icons.female, selected: _selected == GenderOption.female, onTap: () => _onSelect(GenderOption.female), gradient: AppColors.primaryGradient),
                  ],
                ),

                const Spacer(),

                GlassCard(
                  borderRadius: 40,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _selected == null ? null : () async {
                          // Age picker
                          final selectedAge = await Navigator.push<int>(
                            context,
                            MaterialPageRoute(builder: (_) => const AgePickerScreen(initialAge: 25, minAge: 15, maxAge: 80)),
                          );

                          if (selectedAge != null) {
                            // mark as member role (demo) and go to Home (clear backstack)
                            await saveUserRole(UserRole.member);

                            // Do not mark profile complete yet; Home will show "Complete profile" CTA
                            if (!mounted) return;
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(builder: (_) => const HomeScreen()),
                                  (r) => false,
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                        ),
                        child: Ink(
                          decoration: BoxDecoration(
                            gradient: _selected == null ? const LinearGradient(colors: [Colors.grey, Colors.grey]) : AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(32),
                          ),
                          child: Container(
                            alignment: Alignment.center,
                            height: 52,
                            child: const Text('Continue', style: TextStyle(color: Colors.white, fontSize: 16)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GenderCircle extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final Gradient gradient;

  const _GenderCircle({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final double diameter = MediaQuery.of(context).size.width * 0.56;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(
          gradient: selected ? gradient : null,
          color: selected ? null : Colors.white.withOpacity(0.22),
          shape: BoxShape.circle,
          boxShadow: selected ? [BoxShadow(color: Colors.black26, blurRadius: 12, offset: const Offset(0, 6))] : [],
          border: Border.all(color: Colors.white.withOpacity(0.14)),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, size: diameter * 0.28, color: Colors.white), const SizedBox(height: 12), Text(label, style: const TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w600))]),
      ),
    );
  }
}
