// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'config/app_theme.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/trainer/trainer_dashboard.dart';
import 'screens/home/home_screen.dart';
import 'services/fitstreet_api.dart';
import 'state/auth_manager.dart';



void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final apiClient = FitstreetApi('https://api.fitstreet.in');

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthManager>(
          create: (_) => AuthManager(apiClient),
        ),
      ],
      child: FitStreetApp(api: apiClient),
    ),
  );
}

class FitStreetApp extends StatelessWidget {
  final FitstreetApi api;
  const FitStreetApp({super.key, required this.api});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FitStreet',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const SplashScreen(),
      routes: {
        '/auth': (context) => const HomeScreen(),
        '/home': (context) => const HomeScreen(),
        '/trainer': (context) => const TrainerDashboard(),
      },
    );
  }
}

