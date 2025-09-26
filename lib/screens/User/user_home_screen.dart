// lib/screens/user/user_home_screen.dart
import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../widgets/glass_card.dart';

class UserHomeScreen extends StatelessWidget {
  const UserHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: LinearGradient(colors: [AppColors.primary, AppColors.secondary], begin: Alignment.topLeft, end: Alignment.bottomRight)),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(children: [
              const SizedBox(height: 12),
              Row(children: const [
                CircleAvatar(radius: 20, backgroundColor: Colors.white12, child: Icon(Icons.person, color: Colors.white)),
                SizedBox(width: 12),
                Text('Hello!', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 20),
              GlassCard(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
                Text('Welcome to FitStreet', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                SizedBox(height: 6),
                Text('Explore trainers, book sessions, and track progress.', style: TextStyle(color: Colors.white70)),
              ]))),
              const SizedBox(height: 16),
              // Add home content here: search, featured trainers, booking quick actions...
              const Expanded(child: Center(child: Text('User home placeholder', style: TextStyle(color: Colors.white70)))),
            ]),
          ),
        ),
      ),
    );
  }
}
