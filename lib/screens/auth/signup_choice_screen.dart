import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import '../User/user_auth_screen.dart';
import '../trainer/trainer_register_wizard.dart';

class SignupChoiceScreen extends StatelessWidget {
  const SignupChoiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Join FitStreet',
            style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
            child: Container(color: Colors.black.withOpacity(0.15)),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/image/home2-bg.png'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(Colors.black54, BlendMode.darken),
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (ctx, constraints) {
              final isNarrow = constraints.maxWidth < 600;
              final content = [
                const SizedBox(height: 8),
                const Text(
                  'Choose how you want to join our fitness community',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 15),
                const Text(
                  'Register As',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                if (isNarrow) ...[
                  _ChoiceCard(
                    icon: Icons.person,
                    title: 'User',
                    subtitle:
                        'Find and book fitness trainers, yoga instructors, nutritionists, and wellness counselors',
                    color: const Color(0xFF3E1F92),
                    onTap: () {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const UserAuthScreen()));
                    },
                  ),
                  const SizedBox(height: 16),
                  _ChoiceCard(
                    icon: Icons.badge,
                    title: 'Professional',
                    subtitle:
                        'Join as a Trainer, Yoga Instructor, Nutritionist, or Wellness Counselor',
                    color: const Color(0xFFFF6B35),
                    onTap: () {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const TrainerRegisterWizard()));
                    },
                  ),
                ] else ...[
                  Row(
                    children: [
                      Expanded(
                        child: _ChoiceCard(
                          icon: Icons.person,
                          title: 'User',
                          subtitle:
                              'Find and book fitness trainers, yoga instructors, nutritionists, and wellness counselors',
                          color: const Color(0xFF3E1F92),
                          onTap: () {
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const UserAuthScreen()));
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _ChoiceCard(
                          icon: Icons.badge,
                          title: 'Professional',
                          subtitle:
                              'Join as a Trainer, Yoga Instructor, Nutritionist, or Wellness Counselor',
                          color: const Color(0xFFFF6B35),
                          onTap: () {
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const TrainerRegisterWizard()));
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ];
              return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: content),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  const _ChoiceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.10),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white30),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.35),
                blurRadius: 24,
                offset: const Offset(0, 10)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: color.withOpacity(0.22),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(height: 12),
            Text(title,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 20)),
            const SizedBox(height: 10),
            Text(
              subtitle,
              style: const TextStyle(
                  color: Colors.white70, fontSize: 14, height: 1.5),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
