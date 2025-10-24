import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../widgets/glass_card.dart';
import '../../state/auth_manager.dart';
import '../user/user_auth_screen.dart';
import 'login_otp_verification_screen.dart'; // <-- use your dedicated login OTP screen
import '../../utils/profile_storage.dart';

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
  // Save mobile immediately so greeting can show number instead of 'there'
  try { await saveMobile(mobile); } catch (_) {}

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
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Login'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leadingWidth: 120,
        leading: Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                tooltip: 'Back',
              ),
              const SizedBox(width: 4),
              SizedBox(
                width: 56,
                height: kToolbarHeight,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Image.asset('assets/image/fitstreet-bull-logo.png', fit: BoxFit.contain),
                ),
              ),
            ],
          ),
        ),
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
            child: Container(color: Colors.black.withOpacity(0.15)),
          ),
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
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
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: GlassCard(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 22.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
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
                      TextField(
                        controller: _mobileController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Mobile number',
                          prefixText: '+91 ',
                        ),
                        style: const TextStyle(color: Colors.white),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _sendOtp,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white12,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: _loading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('Send OTP', style: TextStyle(color: Colors.white)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: () {
                          // Keep a single styled auth entry; optionally navigate to a sign-up variant here.
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const UserAuthScreen()),
                          );
                        },
                        child: const Text(
                          'Not registered yet? Create an account',
                          style: TextStyle(color: Colors.white, decoration: TextDecoration.underline),
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
    );
  }
}
