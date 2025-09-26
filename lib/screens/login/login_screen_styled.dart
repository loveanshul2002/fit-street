import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_colors.dart';
import '../../widgets/glass_card.dart';
import '../../state/auth_manager.dart';
import '../user/user_auth_screen.dart';
import 'login_otp_verification_screen.dart'; // <-- use your dedicated login OTP screen

/// Styled Login screen for users/trainers.
/// Sends OTP and navigates to LoginOtpVerificationScreen (role-based login).
class LoginScreenStyled extends StatefulWidget {
  const LoginScreenStyled({Key? key}) : super(key: key);

  @override
  State<LoginScreenStyled> createState() => _LoginScreenStyledState();
}

class _LoginScreenStyledState extends State<LoginScreenStyled> {
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
        } catch (_) {}

        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LoginOtpVerificationScreen(
              mobile: mobile,
              expectedOtp: expectedOtp,
            ),
          ),
        );
      } else if (status == 404) {
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
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primary, AppColors.secondary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Back button
              Positioned(
                left: 12,
                top: 8,
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                    const SizedBox(width: 6),
                    const Text('Back', style: TextStyle(color: Colors.white, fontSize: 16)),
                  ],
                ),
              ),

              // Optional logo
              Positioned(
                right: 16,
                top: 8,
                child: SizedBox(
                  width: 96,
                  height: 56,
                  child: Image.asset(
                    'assets/images/fitstreet_logo.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),

              // Main card
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      color: Colors.white.withOpacity(0.04),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.20),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                      border: Border.all(color: Colors.white.withOpacity(0.06)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 22.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GlassCard(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 22.0),
                                child: Column(
                                  children: [
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        'Login',
                                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 18),

                                    // Mobile number input
                                    TextField(
                                      controller: _mobileController,
                                      keyboardType: TextInputType.phone,
                                      decoration: InputDecoration(
                                        hintText: 'Mobile Number',
                                        filled: true,
                                        fillColor: Colors.white.withOpacity(0.03),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(14),
                                          borderSide: BorderSide(color: Colors.white.withOpacity(0.06)),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(14),
                                          borderSide: BorderSide(color: Colors.white.withOpacity(0.04)),
                                        ),
                                        hintStyle: TextStyle(color: Colors.white70),
                                        prefixText: '+91 ',
                                        prefixStyle: const TextStyle(color: Colors.white70),
                                      ),
                                      style: const TextStyle(color: Colors.white),
                                    ),
                                    const SizedBox(height: 20),

                                    // Send OTP button
                                    SizedBox(
                                      width: double.infinity,
                                      height: 56,
                                      child: ElevatedButton(
                                        onPressed: _loading ? null : _sendOtp,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.white.withOpacity(0.10),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(28),
                                          ),
                                          elevation: 0,
                                        ),
                                        child: _loading
                                            ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                        )
                                            : const Text(
                                          'Send OTP',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                    ),

                                    const SizedBox(height: 18),

                                    // Signup redirect
                                    GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (_) => const UserAuthScreen()),
                                        );
                                      },
                                      child: const Padding(
                                        padding: EdgeInsets.symmetric(vertical: 8.0),
                                        child: Text(
                                          'Not registered yet? Create an account',
                                          style: TextStyle(
                                            color: Colors.white,
                                            decoration: TextDecoration.underline,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ), // Center
            ],
          ),
        ),
      ),
    );
  }
}
