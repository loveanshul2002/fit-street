// lib/screens/User/otp_verification_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui' show ImageFilter;
import 'package:provider/provider.dart';

// removed unused glass_card and app_colors after switching to direct blur and image background
import 'gender_selection_screen.dart';
import '../../utils/role_storage.dart';
import '../../utils/user_role.dart';
import '../../state/auth_manager.dart';
import '../../screens/trainer/trainer_dashboard.dart';
// removed unused home_screen import

class OtpVerificationScreen extends StatefulWidget {
  final String mobile;
  final String expectedOtp; // for dev only
  final String? name; // made nullable

  const OtpVerificationScreen({super.key, required this.mobile, required this.expectedOtp, this.name});

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _otpCtrl = TextEditingController();
  bool _verifying = false;
  int _resendSeconds = 30;
  bool _canResend = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startResendCountdown();
  }

  @override
  void dispose() {
    _otpCtrl.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startResendCountdown() {
    _resendSeconds = 30;
    _canResend = false;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_resendSeconds <= 0) {
        setState(() {
          _canResend = true;
        });
        t.cancel();
        return;
      }
      setState(() {
        _resendSeconds -= 1;
      });
    });
  }

  Future<void> _verifyOtp() async {
    final otp = _otpCtrl.text.trim();
    if (otp.length != 6) {
      _showSnack('Enter 6-digit OTP');
      return;
    }

    setState(() => _verifying = true);

    try {
      final auth = context.read<AuthManager>();
      Map<String, dynamic> result;

      // If name was provided, assume this flow is signup -> call signup verify
      if (widget.name != null && widget.name!.isNotEmpty) {
        result = await auth.verifySignupOtp(widget.mobile, otp, role: 'user');
      } else {
        // login flow
        result = await auth.verifyLoginOtp(widget.mobile, otp);
      }

      final status = result['statusCode'] ?? 0;
      final body = result['body'];

      if ((result['success'] == true) || status == 200) {
        // success: existing logic (save role/name if returned)
        final roleStr = result['role'] ?? auth.role ?? 'user';
        if (roleStr.toString().toLowerCase() == 'trainer' || roleStr.toString().toLowerCase() == 'coach') {
          await saveUserRole(UserRole.trainer);
          if (!mounted) return;
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const TrainerDashboard()));
          return;
        } else {
          await saveUserRole(UserRole.member);
          if (!mounted) return;
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const GenderSelectionScreen()));
          return;
        }
      } else {
        // Extract a helpful message that handles different server keys
        String serverMessage = 'OTP verification failed';
        if (body is Map) {
          serverMessage = (body['message'] ?? body['error'] ?? body['detail'] ?? serverMessage).toString();
        } else if (body is String && body.isNotEmpty) {
          serverMessage = body;
        }

        // Specific handling: number not registered when calling login
        if (status == 404 && (widget.name == null || widget.name!.isEmpty)) {
          // Offer signup suggestion on login attempts
          _showSnack('Number not registered. Please sign up.');
          // Optionally navigate back to auth screen and toggle to signup:
          // Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => UserAuthScreen(... with signup selected ...)));
        } else {
          _showSnack(serverMessage);
        }
      }
    } catch (e) {
      _showSnack('Network error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }


  Future<void> _resend() async {
    if (!_canResend) return;
    setState(() {
      _canResend = false;
      _resendSeconds = 30;
    });
    final auth = context.read<AuthManager>();
    try {
      final r = await auth.sendLoginOtp(widget.mobile);
      final status = r['statusCode'] ?? 0;
      final body = r['body'];
      if (status == 200) {
        _showSnack('OTP resent');
        _startResendCountdown();
      } else {
        String message = 'Failed to resend OTP';
        if (body is Map && body['message'] != null) message = body['message'].toString();
        _showSnack(message);
        setState(() {
          _canResend = true;
          _resendSeconds = 0;
        });
      }
    } catch (e) {
      _showSnack('Network error: ${e.toString()}');
      setState(() {
        _canResend = true;
        _resendSeconds = 0;
      });
    }
  }

  void _showSnack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

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
        // Use same background style as home screens for visual consistency
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
            child: Column(children: [
              const SizedBox(height: kToolbarHeight + 8),
              // Blur the OTP box like the notification overlay, without changing behavior
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.16),
                          Colors.white.withOpacity(0.06),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.28), width: 0.75),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, 8)),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(children: [
                        Text('OTP sent to +91 ${widget.mobile}', style: const TextStyle(color: Colors.white70)),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _otpCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Enter 6-digit OTP',
                            labelStyle: const TextStyle(color: Colors.white70),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.06),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white12)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _verifying ? null : _verifyOtp,
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.white12, padding: const EdgeInsets.symmetric(vertical: 14)),
                            child: _verifying
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('Verify', style: TextStyle(color: Colors.white)),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          TextButton(
                            onPressed: _canResend ? _resend : null,
                            child: Text(_canResend ? 'Resend OTP' : 'Resend in $_resendSeconds s', style: const TextStyle(color: Colors.white70)),
                          ),
                        ]),
                      ]),
                    ),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
