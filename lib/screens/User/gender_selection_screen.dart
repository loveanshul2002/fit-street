// lib/screens/user/gender_selection_screen.dart
import 'package:flutter/material.dart';
import 'dart:ui' show ImageFilter;
import 'package:provider/provider.dart';
import '../../config/app_colors.dart';
import 'age_picker_screen.dart';
import '../home/home_screen.dart';
import '../../utils/role_storage.dart';
import '../../utils/role_storage.dart' show getUserName; // to include fullName in update
import '../../utils/user_role.dart';
import '../../utils/profile_storage.dart' show saveGender, saveAge, StoredGender, getMobile;
import '../../state/auth_manager.dart';

enum GenderOption { male, female, other }

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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 6),
                          const Text(
                            'Tell Us About Yourself',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'To give you a better experience and results\nwe need to know your gender.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(height: 16),
                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Column(
                                children: [
                                  _GenderCircle(
                                    label: 'Male',
                                    icon: Icons.male,
                                    selected: _selected == GenderOption.male,
                                    onTap: () => _onSelect(GenderOption.male),
                                    gradient: AppColors.primaryGradient,
                                  ),
                                  const SizedBox(height: 24),
                                  _GenderCircle(
                                    label: 'Female',
                                    icon: Icons.female,
                                    selected: _selected == GenderOption.female,
                                    onTap: () => _onSelect(GenderOption.female),
                                    gradient: AppColors.primaryGradient,
                                  ),
                                  const SizedBox(height: 24),
                                  _GenderCircle(
                                    label: 'Other',
                                    icon: Icons.transgender,
                                    selected: _selected == GenderOption.other,
                                    onTap: () => _onSelect(GenderOption.other),
                                    gradient: AppColors.primaryGradient,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _selected == null ? null : () async {
                          // Age picker
                          final selectedAge = await Navigator.push<int>(
                            context,
                            MaterialPageRoute(builder: (_) => const AgePickerScreen(initialAge: 25, minAge: 15, maxAge: 80)),
                          );

                          if (selectedAge != null) {
                            // Persist role locally
                            await saveUserRole(UserRole.member);

                            // Persist gender and age locally for quick reuse
                            try {
                              final StoredGender g;
                              switch (_selected) {
                                case GenderOption.male:
                                  g = StoredGender.male;
                                  break;
                                case GenderOption.female:
                                  g = StoredGender.female;
                                  break;
                                case GenderOption.other:
                                  g = StoredGender.other;
                                  break;
                                default:
                                  g = StoredGender.unknown;
                              }
                              await saveGender(g);
                              await saveAge(selectedAge);
                            } catch (_) {}

                            // Push profile details to backend: fullName, mobile, gender, age
                            try {
                              final name = await getUserName();
                              final mobile = await getMobile();
                              final String genderStr;
                              switch (_selected) {
                                case GenderOption.male:
                                  genderStr = 'Male';
                                  break;
                                case GenderOption.female:
                                  genderStr = 'Female';
                                  break;
                                case GenderOption.other:
                                  genderStr = 'Other';
                                  break;
                                default:
                                  genderStr = 'Other';
                              }
                              final fields = <String, dynamic>{
                                if (name != null && name.isNotEmpty) 'fullName': name,
                                if (mobile != null && mobile.isNotEmpty) 'mobileNumber': mobile,
                                'gender': genderStr,
                                'age': selectedAge,
                              };
                              final auth = context.read<AuthManager>();
                              final resp = await auth.updateUserProfile(fields);
                              // Optional: show a quick toast/snack on failure but proceed
                              if (resp['success'] != true) {
                                // ignore failure for now; user can retry from profile
                              }
                            } catch (_) {}

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
                                              Colors.white.withOpacity(_selected == null ? 0.08 : 0.16),
                                              Colors.white.withOpacity(_selected == null ? 0.03 : 0.06),
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          borderRadius: BorderRadius.circular(24),
                                          border: Border.all(
                                            color: Colors.white.withOpacity(_selected == null ? 0.18 : 0.28),
                                            width: 0.75,
                                          ),
                                        ),
                    child: Text(
                                          'Continue',
                                          style: TextStyle(
                      color: Colors.white.withOpacity(_selected == null ? 0.6 : 1.0),
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                                          ),
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
    final double diameter = MediaQuery.of(context).size.width * 0.4;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: diameter,
        height: diameter,
        decoration: selected
            ? BoxDecoration(
                shape: BoxShape.circle,
                // subtle glow ring using a sweep gradient halo
                gradient: SweepGradient(
                  colors: const [
                    Color(0xFF5C6BC0), // indigo
                    Color(0xFFAB47BC), // purple
                    Color(0xFF5C6BC0),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
                boxShadow: [
                  BoxShadow(color: const Color(0xFFAB47BC).withOpacity(0.35), blurRadius: 24, spreadRadius: 1, offset: const Offset(0, 8)),
                ],
              )
            : const BoxDecoration(shape: BoxShape.circle),
        child: Padding(
          padding: selected ? const EdgeInsets.all(2.0) : EdgeInsets.zero,
          child: ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: selected ? 14 : 10, sigmaY: selected ? 14 : 10),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: selected
                        ? [
                            Colors.white.withOpacity(0.08),
                            Colors.white.withOpacity(0.02),
                          ]
                        : [
                            Colors.white.withOpacity(0.16),
                            Colors.white.withOpacity(0.06),
                          ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(color: Colors.white.withOpacity(selected ? 0.5 : 0.28), width: selected ? 1.2 : 0.75),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: diameter * 0.28, color: Colors.white),
                    const SizedBox(height: 12),
                    Text(
                      label,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
