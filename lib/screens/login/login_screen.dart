// lib/screens/login/login_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_colors.dart';
import '../../widgets/glass_card.dart';
import '../../state/auth_manager.dart';
import '../user/user_auth_screen.dart';
import '../user/otp_verification_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _mobileController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _mobileController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final mobile = _mobileController.text.trim();
    if (mobile.length < 10) {
      _showSnack('Enter a valid mobile number');
      return;
    }

    setState(() => _loading = true);
    try {
      final auth = context.read<AuthManager>();
      final Map<String, dynamic> result = await auth.sendLoginOtp(mobile);
      debugPrint('DEBUG sendLoginOtp => $result');

      final status = result['statusCode'] ?? 0;
      final body = result['body'];

      if (status == 200) {
        String expectedOtp = '';
        try {
          if (body is String) {
            expectedOtp = body;
          } else if (body is Map && (body['otp'] != null || body['data']?['otp'] != null)) {
            expectedOtp = (body['otp'] ?? body['data']?['otp']).toString();
          }
        } catch (_) {
          expectedOtp = '';
        }

        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OtpVerificationScreen(
              mobile: mobile,
              expectedOtp: expectedOtp,
              // login flow: no `name`
            ),
          ),
        );
      } else if (status == 404) {
        // number not registered
        _showSnack('Number not registered. Please create an account.');
      } else {
        String message = 'Failed to send OTP';
        try {
          if (body is Map && (body['message'] != null || body['error'] != null)) {
            message = (body['message'] ?? body['error']).toString();
          } else if (body is String && body.isNotEmpty) {
            message = body;
          }
        } catch (_) {}
        _showSnack(message);
      }
    } catch (e) {
      _showSnack('Network error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSnack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Background gradient consistent with app
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primary, AppColors.secondary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                const SizedBox(height: 8),
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Login',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                GlassCard(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        TextField(
                          controller: _mobileController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Mobile number',
                            prefixText: '+91 ',
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _sendOtp,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white12,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            child: _loading
                                ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                                : const Text('Send OTP', style: TextStyle(color: Colors.white)),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Create account link -> goes to signup screen
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const UserAuthScreen()),
                            );
                          },
                          child: const Text(
                            "Not registered yet? Create an account",
                            style: TextStyle(
                              color: Colors.blueAccent,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // optional spacing at bottom to match screenshot spacing
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
