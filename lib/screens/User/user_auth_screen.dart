//user_auth

import 'package:fit_street/widgets/scaffold_with_bg.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../widgets/glass_card.dart';
import '../../state/auth_manager.dart';
import '../../utils/role_storage.dart' show saveUserName, saveProfileComplete;
import '../../utils/profile_storage.dart' show saveMobile;
import 'otp_verification_screen.dart';
import '../trainer/trainer_register_wizard.dart';
import 'package:flutter/services.dart';

class UserAuthScreen extends StatefulWidget {
  const UserAuthScreen({Key? key}) : super(key: key);

  @override
  State<UserAuthScreen> createState() => _UserAuthScreenState();
}

class _UserAuthScreenState extends State<UserAuthScreen> {
  final _mobileController = TextEditingController();
  final _nameController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _mobileController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final mobile = _mobileController.text.trim();
    final name = _nameController.text.trim();

    if (mobile.length < 10) {
      _showSnack('Enter a valid mobile number');
      return;
    }
    if (name.isEmpty) {
      _showSnack('Please enter your name');
      return;
    }

    setState(() => _loading = true);

    try {
      // Save locally right away so Profile Fill screen and Home greeting can use them
      await saveUserName(name);
      await saveMobile(mobile);
      // Ensure profile-complete is false at start so Home shows the CTA until finished
      try { await saveProfileComplete(false); } catch (_) {}

      final auth = context.read<AuthManager>();
      final result = await auth.sendSignupOtp(mobile);
      print('DEBUG: sendSignupOtp result => $result');

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
            builder: (_) => OtpVerificationScreen(
              mobile: mobile,
              expectedOtp: expectedOtp,
              name: name,
            ),
          ),
        );
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

  void _showSnack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    return ScaffoldWithBg(


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
                      icon: const Icon(Icons.arrow_back, color: Colors.white)),
                  const SizedBox(width: 6),
                  const Text('Join Fit Street',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 18),
              GlassCard(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      // Full Name
                      TextField(
                        controller: _nameController,
                        decoration:
                        const InputDecoration(labelText: 'Full name'),
                      ),
                      const SizedBox(height: 12),

                      // Mobile Number
                      TextField(
                        controller: _mobileController,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Mobile number',
                          prefixText: '+91 ',
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Send OTP Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _sendOtp,
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white12,
                              padding: const EdgeInsets.symmetric(vertical: 14)),
                          child: _loading
                              ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                              : const Text('Send OTP',
                              style: TextStyle(color: Colors.white)),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Trainer Register Link
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const TrainerRegisterWizard(),
                            ),
                          );
                        },
                        child: const Text(
                          "Are you a Trainer? Register Here",
                          style: TextStyle(
                            color: Colors.white,
                            decoration: TextDecoration.underline,
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

    );
  }
}

