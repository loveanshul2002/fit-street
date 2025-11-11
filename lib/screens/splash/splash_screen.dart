// lib/screens/splash/splash_screen.dart
import 'package:flutter/material.dart';
import 'dart:async';
import '../onboarding/onboarding_screen.dart';
import '../../utils/page_transition.dart';
import 'package:provider/provider.dart';
import '../../state/auth_manager.dart';
import '../../screens/trainer/trainer_dashboard.dart';
import '../../screens/home/home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  double _logoOpacity = 0.0;
  double _textOpacity = 0.0;
  Offset _textOffset = const Offset(0, 0.3);
  Timer? _navTimer;

  @override
  void initState() {
    super.initState();

    // Animate logo
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        _logoOpacity = 1.0;
      });
    });

    // Animate text
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (!mounted) return;
      setState(() {
        _textOpacity = 1.0;
        _textOffset = Offset.zero;
      });
    });

    // Decide navigation after ~3 seconds (same UX as before)
    _navTimer = Timer(const Duration(seconds: 3), _decideNext);
  }

  @override
  void dispose() {
    _navTimer?.cancel();
    super.dispose();
  }

  /// Wait briefly for AuthManager to load persisted state.
  /// We poll up to [maxWaitMs] milliseconds (100ms intervals). If token/role/isLoggedIn
  /// becomes available earlier, we break early and proceed.
  Future<void> _decideNext() async {
    final auth = Provider.of<AuthManager>(context, listen: false);

    // Polling parameters
    const int maxWaitMs = 2000; // total time to wait for auth to initialize
    const int pollIntervalMs = 100; // check every 100ms

    int waited = 0;
    // If AuthManager already loaded quickly, no loop needed.
    // We consider it "loaded enough" if either:
    //  - auth.isLoggedIn is true (token present)
    //  - auth.role is non-null and non-empty
    // Otherwise try to poll for up to maxWaitMs.
    while (waited < maxWaitMs) {
      // small synchronous check
      final isLoggedIn = auth.isLoggedIn;
      final roleVal = auth.role;
      final tokenVal = auth.token;

      if (isLoggedIn || (roleVal != null && roleVal.isNotEmpty) || (tokenVal != null && tokenVal.isNotEmpty)) {
        break;
      }

      // wait a bit and check again
      await Future.delayed(const Duration(milliseconds: pollIntervalMs));
      waited += pollIntervalMs;
    }

    // After polling (or immediate), read the final auth state
    final finalAuth = Provider.of<AuthManager>(context, listen: false);
    Widget destination;

    if (!finalAuth.isLoggedIn) {
      // user not logged in -> onboarding
      destination = const OnboardingScreen();
    } else {
      // logged in: route by role if available
      final role = (finalAuth.role ?? '').toLowerCase();
      if (role == 'trainer') {
        destination = const TrainerDashboard();
      } else {
        destination = const HomeScreen();
      }
    }

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      FadeRoute(page: destination),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/image/splash-bg.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ✅ Animated Logo with glow
              AnimatedOpacity(
                opacity: _logoOpacity,
                duration: const Duration(seconds: 1),
                child: Image.asset(
                  "assets/image/fitstreet-bull-logo.png",
                  width: 150,
                ),
              ),

              const SizedBox(height: 20),

              // ✅ Animated Text with neon glow
              AnimatedSlide(
                offset: _textOffset,
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOut,
                child: AnimatedOpacity(
                  opacity: _textOpacity,
                  duration: const Duration(milliseconds: 800),
                  child: Column(
                    children: const [
                  
                      Text(
                        "Fitness Delivered At Your Doorstep",
                        style: TextStyle(
                          fontSize: 25,
                          color: Colors.white70,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.bold,
                       
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
