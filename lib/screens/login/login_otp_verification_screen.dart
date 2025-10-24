// lib/screens/login/login_otp_verification_screen.dart
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../widgets/glass_card.dart';
import '../../state/auth_manager.dart';
import '../home/home_screen.dart';
import '../trainer/trainer_dashboard.dart';

class LoginOtpVerificationScreen extends StatefulWidget {
  final String mobile;
  final String expectedOtp; // optional debug helper

  const LoginOtpVerificationScreen({
    Key? key,
    required this.mobile,
    this.expectedOtp = '',
  }) : super(key: key);

  @override
  State<LoginOtpVerificationScreen> createState() => _LoginOtpVerificationScreenState();
}

class _LoginOtpVerificationScreenState extends State<LoginOtpVerificationScreen> {
  final TextEditingController _otpController = TextEditingController();
  bool _loading = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    if (widget.expectedOtp.isNotEmpty) _otpController.text = widget.expectedOtp;
  }

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length < 4) {
      _showSnack('Enter a valid OTP');
      return;
    }

    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      final auth = context.read<AuthManager>();
      final Map<String, dynamic> result = await auth.verifyLoginOtp(widget.mobile, otp);
      debugPrint('DEBUG verifyLoginOtp result => $result');

      if (result['success'] == true) {
        // AuthManager persisted token/role/id already.
        final role = (result['role'] ?? result['body']?['type'] ?? 'user').toString().toLowerCase();

        // Ensure ids/tokens are reloaded in case app state was cold
        final auth = context.read<AuthManager>();
        await auth.reloadFromStorage();

        // After login, fetch and persist profile so greeting shows correct name
        try {
          if (role.contains('train')) {
            // prefer DB id; if missing, we can't fetch by unique id using current API client
            final trainerId = await auth.getApiTrainerId();
            if (trainerId != null && trainerId.isNotEmpty) {
              await auth.fetchTrainerProfile(trainerId);
            }
            if (!mounted) return;
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const TrainerDashboard()),
              (route) => false,
            );
          } else {
            await auth.getUserProfile();
            if (!mounted) return;
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const HomeScreen()),
              (route) => false,
            );
          }
        } catch (_) {
          // Even if profile fetch fails, continue navigation
          if (!mounted) return;
          if (role.contains('train')) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const TrainerDashboard()),
              (route) => false,
            );
          } else {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const HomeScreen()),
              (route) => false,
            );
          }
        }
        return;
      }

      // failure case
      final msg = result['message']?.toString() ??
          (result['body'] is String ? result['body'] : 'OTP verification failed');
      setState(() => _error = msg);
      _showSnack(msg);
    } catch (e) {
      setState(() => _error = 'Network error: ${e.toString()}');
      _showSnack(_error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resendOtp() async {
    setState(() => _loading = true);
    try {
      final auth = context.read<AuthManager>();
      final Map<String, dynamic> res = await auth.sendLoginOtp(widget.mobile);
      debugPrint('DEBUG resendLoginOtp => $res');
      final status = res['statusCode'] ?? 0;
      if (status == 200) _showSnack('OTP resent');
      else _showSnack('Failed to resend OTP');
    } catch (e) {
      _showSnack('Network error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSnack(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Widget _otpField() {
    return TextField(
      controller: _otpController,
      keyboardType: TextInputType.number,
      maxLength: 6,
      decoration: const InputDecoration(labelText: 'Enter OTP', counterText: ''),
      style: const TextStyle(color: Colors.white),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Verify OTP'),
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
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: GlassCard(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('OTP sent to +91 ${widget.mobile}', style: const TextStyle(color: Colors.white70)),
                    const SizedBox(height: 12),
                    _otpField(),
                    if (_error.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(_error, style: const TextStyle(color: Colors.redAccent)),
                    ],
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _verifyOtp,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.white12, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
                        child: _loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Verify & Continue', style: TextStyle(color: Colors.white)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(onPressed: _loading ? null : _resendOtp, child: const Text('Resend OTP', style: TextStyle(color: Colors.white70))),
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
