// lib/screens/trainer/trainer_register_wizard.dart
import 'dart:convert';
import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
 
// import '../../config/app_colors.dart';
import '../../state/auth_manager.dart';
import '../../utils/role_storage.dart';
import '../../utils/user_role.dart';
import '../../widgets/glass_card.dart';
import 'trainer_dashboard.dart';

class TrainerRegisterWizard extends StatefulWidget {
  const TrainerRegisterWizard({super.key});

  @override
  State<TrainerRegisterWizard> createState() => _TrainerRegisterWizardState();
}

class _TrainerRegisterWizardState extends State<TrainerRegisterWizard> {
  final PageController _page = PageController();
  int _step = 0;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _mobileCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  bool _otpSent = false;
  bool _otpVerified = false;
  final TextEditingController _otpCtrl = TextEditingController();

  // bool _acceptTnc = false; // kept from previous Payment step; not used currently

  // demo fallback id (kept from previous flow)
  // final String _demoTrainerId =
  //     "FS${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}";

  bool _loading = false;
  // String? _rawTrainerId;

  // resend cooldown state
  int _resendCooldown = 0; // seconds remaining
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    _loadSavedIds();
  }

  @override
  void dispose() {
    _page.dispose();
    _nameCtrl.dispose();
    _mobileCtrl.dispose();
    _emailCtrl.dispose();
    _otpCtrl.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadSavedIds() async {
    try {
      // Try AuthManager first
      String? raw;
      try {
        final auth = context.read<AuthManager>();
        raw = await auth.getRawTrainerId();
      } catch (_) {
        raw = null;
      }

      // fallback to prefs
      if (raw == null || raw.isEmpty) {
        final sp = await SharedPreferences.getInstance();
        raw = sp.getString('fitstreet_trainer_unique_id') ??
            sp.getString('fitstreet_trainer_uniqueid') ??
            sp.getString('fitstreet_trainer_db_id') ??
            raw;
      }

  // Previously we displayed a derived trainer id preview; no longer used in UI
  // final display = extractDisplayId(raw);
  // if (display != null && mounted) setState(() => _rawTrainerId = display);
    } catch (e) {
      debugPrint('Failed to load saved ids: $e');
    }
  }

  void _startResendCooldown([int seconds = 30]) {
    _resendTimer?.cancel();
    setState(() {
      _resendCooldown = seconds;
    });
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _resendCooldown = _resendCooldown - 1;
        if (_resendCooldown <= 0) {
          _resendCooldown = 0;
          t.cancel();
          _resendTimer = null;
        }
      });
    });
  }

  Future<void> _next() async {
    if (_step == 0) {
      if (_formKey.currentState!.validate() && _otpVerified) {
        // Save basic details and then redirect to Dashboard
        final saved = await _saveBasicDetailsToServer();
        if (saved) {
          // mark role and go to dashboard
          try { await saveUserRole(UserRole.trainer); } catch (_) {}
          if (!mounted) return;
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const TrainerDashboard()),
                (route) => false,
          );
        }
      } else if (!_otpVerified) {
        _snack("Please verify your mobile with OTP.");
      }
      return;
    }

    // NOTE: If you ever re-enable Payment/Done steps, handle _step 1/2 here.
  }

  Future<bool> _saveBasicDetailsToServer() async {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();

    if (name.isEmpty && email.isEmpty) {
      _snack("Name or email should not be empty.");
      return false;
    }

    setState(() {
      _loading = true;
    });

    final sp = await SharedPreferences.getInstance();

    try {
      final auth = context.read<AuthManager>();

      String? prefId;
      try {
        prefId = await auth.getApiTrainerId();
      } catch (_) {
        prefId = null;
      }

      prefId ??= sp.getString('fitstreet_trainer_id') ?? sp.getString('fitstreet_trainer_db_id') ?? '';

      if (prefId.isEmpty) {
        await sp.setString('fitstreet_trainer_name', name);
        if (email.isNotEmpty) await sp.setString('fitstreet_trainer_email', email);
        _snack("Saved locally — will update on registration completion.");
        return true;
      }

      try {
        final res = await auth.updateTrainerProfile(prefId, fullName: name.isEmpty ? null : name, email: email.isEmpty ? null : email);
        final statusCode = (res['statusCode'] is int) ? res['statusCode'] as int : 0;
        final body = res['body'];

        if (statusCode == 200 || statusCode == 201) {
          await sp.setString('fitstreet_trainer_name', name);
          if (email.isNotEmpty) await sp.setString('fitstreet_trainer_email', email);
          try {
            await auth.fetchTrainerProfile(prefId);
            await _loadSavedIds();
          } catch (_) {}
          _snack("Basic details saved on server.");
          return true;
        } else {
          await sp.setString('fitstreet_trainer_name', name);
          if (email.isNotEmpty) await sp.setString('fitstreet_trainer_email', email);

          String msg = 'Server returned ${statusCode == 0 ? 'no response' : statusCode}';
          try {
            if (body is Map) msg = (body['message'] ?? body['error'] ?? body['msg'] ?? msg).toString();
            else if (res['error'] != null) msg = res['error'].toString();
          } catch (_) {}

          debugPrint('updateTrainerProfile non-200: $statusCode -> $body');
          _snack("Saved locally. Server update failed: $msg — you can continue; we'll sync later.");
          return true;
        }
      } catch (e) {
        await sp.setString('fitstreet_trainer_name', name);
        if (email.isNotEmpty) await sp.setString('fitstreet_trainer_email', email);
        debugPrint('updateTrainerProfile exception: $e');
        _snack("Network error. Saved locally and will sync later.");
        return true;
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendOtp() async {
    final mobile = _mobileCtrl.text.trim();
    if (mobile.length != 10 || !RegExp(r'^[0-9]{10}$').hasMatch(mobile)) {
      _snack("Enter a valid 10-digit mobile number.");
      return;
    }

    setState(() {
      _loading = true;
    });

    final auth = context.read<AuthManager>();
    try {
      final res = await auth.sendSignupOtp(mobile, role: 'trainer');
      final status = res['statusCode'] ?? 0;
      final body = res['body'];

      if (status == 200 || status == 201) {
        setState(() {
          _otpSent = true;
        });
        _startResendCooldown(30);
        _snack("OTP sent to $mobile");
      } else {
        String msg = 'Failed to send OTP';
        try {
          if (body is Map && (body['message'] != null || body['error'] != null)) msg = (body['message'] ?? body['error']).toString();
          else if (res['message'] != null) msg = res['message'].toString();
        } catch (_) {}
        _snack(msg);
        setState(() {});
      }
    } catch (e) {
      _snack('Network error: ${e.toString()}');
      setState(() {});
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _otpCtrl.text.trim();
    final mobile = _mobileCtrl.text.trim();
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    if (otp.length < 4) {
      _snack("Enter the OTP.");
      return;
    }
    setState(() {
      _loading = true;
    });

    final auth = context.read<AuthManager>();
    try {
      final res = await auth.verifySignupOtp(mobile, otp, role: 'trainer');
      final success = (res['success'] == true) || ((res['statusCode'] ?? 0) == 200) || ((res['statusCode'] ?? 0) == 201);

      if (success) {
        setState(() {
          _otpVerified = true;
        });

        if (name.isNotEmpty) await saveUserName(name);

        try {
          final sp = await SharedPreferences.getInstance();
          if (name.isNotEmpty) await sp.setString('fitstreet_trainer_name', name);
          if (email.isNotEmpty) await sp.setString('fitstreet_trainer_email', email);
          if (mobile.isNotEmpty) await sp.setString('fitstreet_trainer_mobile', mobile);
        } catch (_) {}

        // Try extract ids, update profile and fetch profile if possible (best-effort).
        String? dbId;
        String? trainerUnique;

        try {
          final body = res['body'];
          if (body is Map) {
            final data = body['data'] ?? body;
            if (data is Map) {
              dbId = (data['_id'] ?? data['id'])?.toString();
              trainerUnique = (data['trainerUniqueId'] ?? data['trainerUniqueID'] ?? data['trainerUniqueid'])?.toString();
            } else {
              dbId = (body['_id'] ?? body['id'])?.toString();
              trainerUnique = (body['trainerUniqueId'] ?? body['trainerUniqueID'] ?? body['trainerUniqueid'])?.toString();
            }
          }
        } catch (_) {}

        try {
          if ((dbId == null || dbId.isEmpty) && res['id'] != null) dbId = res['id'].toString();
        } catch (_) {}

        String? _normalizeId(dynamic raw) {
          if (raw == null) return null;
          final s = raw.toString().trim();
          if (s.isEmpty) return null;
          final hexMatch = RegExp(r'^[0-9a-fA-F]{24}$').firstMatch(s);
          if (hexMatch != null) return s;
          if (s.startsWith('{') || s.startsWith('[')) {
            try {
              final parsed = jsonDecode(s);
              if (parsed is Map) {
                final cand = parsed['_id'] ?? parsed['id'] ?? parsed['trainerUniqueId'] ?? parsed['trainerUniqueID'];
                if (cand != null) {
                  final candStr = cand.toString();
                  final insideHex = RegExp(r'([0-9a-fA-F]{24})').firstMatch(candStr);
                  if (insideHex != null) return insideHex.group(1);
                  return candStr;
                }
              }
            } catch (_) {}
          }
          final extract = RegExp(r'([0-9a-fA-F]{24})').firstMatch(s);
          if (extract != null) return extract.group(1);
          return s;
        }

        final sp = await SharedPreferences.getInstance();
        final storedPrefCandidate = sp.getString('fitstreet_trainer_db_id') ??
            sp.getString('fitstreet_trainer_id') ??
            sp.getString('fitstreet_trainer_db_raw') ??
            sp.getString('fitstreet_trainer_id_raw');

        final List<String> candidates = [];
        if (dbId != null && dbId.isNotEmpty) {
          final n = _normalizeId(dbId);
          if (n != null && n.isNotEmpty) candidates.add(n);
        }
        final nStored = _normalizeId(storedPrefCandidate);
        if (nStored != null && nStored.isNotEmpty && !candidates.contains(nStored)) candidates.add(nStored);

        if (trainerUnique != null && trainerUnique.isNotEmpty && !candidates.contains(trainerUnique)) {
          candidates.add(trainerUnique);
        }

        String? idToUse;
        for (final c in candidates) {
          final t = c.trim();
          if (t.isEmpty) continue;
          idToUse = t;
          break;
        }

        if (idToUse != null && idToUse.isNotEmpty) {
          try {
            await auth.updateTrainerProfile(idToUse, fullName: name.isEmpty ? null : name, email: email.isEmpty ? null : email);
            await auth.fetchTrainerProfile(idToUse);
            try { await _loadSavedIds(); } catch (_) {}
          } catch (e) {
            debugPrint('verifyOtp: update/fetch using id $idToUse failed: $e');
          }
        } else {
          debugPrint('verifyOtp: no usable trainer id extracted from response or prefs.');
        }

        _snack("Mobile verified — you can continue registration.");
      } else {
        String msg = 'OTP verification failed';
        try {
          final body = res['body'];
          if (body is Map && (body['message'] != null || body['error'] != null)) msg = (body['message'] ?? body['error']).toString();
          else if (res['message'] != null) msg = res['message'].toString();
        } catch (_) {}
        _snack(msg);
        if (mounted) setState(() {});
      }
    } catch (e) {
      _snack('Network error: ${e.toString()}');
      if (mounted) setState(() {});
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String m) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  // String _displayTrainerId() {
  //   if (_rawTrainerId != null && _rawTrainerId!.isNotEmpty) {
  //     final s = _rawTrainerId!.trim();
  //     return s.length <= 30 ? s : '${s.substring(0, 27)}...';
  //   }
  //   return _demoTrainerId;
  // }

  // UI

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Register as Trainer'),
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
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/image/bg.png'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(Colors.black54, BlendMode.darken),
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
            // Step indicator
        //    Padding(
        //      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        //      child: GlassCard(
        //        child: Padding(
        //          padding: const EdgeInsets.all(8),
        //          child: Row(
        //            children: [
         //             _stepDot(0, "Basic"),
                      // If you ever want to re-enable Payment & Done UI, uncomment these:
                      // _line(),
                      // _stepDot(1, "Payment"),
                      // _line(),
                      // _stepDot(2, "Done"),
          //          ],
          //        ),
          //      ),
          //    ),
          //  ),

              const SizedBox(height: 12),

              // Pages - only Basic active; Payment & Done calls are commented for now
              Expanded(
                child: PageView(
                  controller: _page,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _stepBasic(),
                    // _stepPayment(), // commented out - kept in file below for future restore
                    // _stepConfirm(), // commented out - kept in file below for future restore
                  ],
                ),
              ),

              // Nav buttons
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  children: [
                    if (_step > 0)
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(color: Colors.white.withOpacity(0.6)),
                          ),
                          onPressed: _back,
                          child: const Text("Back"),
                        ),
                      ),
                    if (_step > 0) const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.2),
                        ),
                        onPressed: _next,
                        child: Text(
                          _step < 1 ? "Continue" : "Go to Dashboard",
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Widget _stepDot(int index, String label) {
  //   final active = _step == index;
  //   return Expanded(
  //     child: Column(
  //       children: [
  //         Container(
  //           width: 30, height: 30,
  //           decoration: BoxDecoration(
  //             shape: BoxShape.circle,
  //             color: active ? Colors.orange : Colors.white.withOpacity(0.25),
  //             border: Border.all(color: Colors.white.withOpacity(0.5)),
  //           ),
  //           alignment: Alignment.center,
  //           child: Text("${index + 1}",
  //               style: TextStyle(
  //                 color: active ? AppColors.secondary : Colors.white,
  //                 fontWeight: FontWeight.w800,
  //               )),
  //         ),
  //         const SizedBox(height: 6),
  //         Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
  //       ],
  //     ),
  //   );
  // }

  // Widget _line() => const SizedBox(width: 12);

  Widget _stepBasic() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: GlassCard(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(" Basic Details",
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),

                  _field("Full Name", _nameCtrl, validator: (v) =>
                  (v == null || v.trim().isEmpty) ? "Enter your full name" : null),

                  _field("Email", _emailCtrl,
                      keyboardType: TextInputType.emailAddress, validator: (v) {
                        if (v == null || v.isEmpty) return "Email is required";
                        final ok = RegExp(r".+@.+\..+").hasMatch(v);
                        return ok ? null : "Enter a valid email";
                      }),

                  _field("Mobile Number", _mobileCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return "Enter mobile number";
                        if (v.length != 10) return "Enter a 10-digit mobile number";
                        return null;
                      }),

                  const SizedBox(height: 8),

                  if (!_otpSent)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _loading ? null : _sendOtp,
                        child: _loading
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator())
                            : const Text("Send OTP"),
                      ),
                    )
                  else if (!_otpVerified) ...[
                    const SizedBox(height: 8),
                    _field("Enter OTP", _otpCtrl,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        validator: (v) => (v == null || v.length != 6) ? "Enter 6-digit OTP" : null),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: (_resendCooldown == 0 && !_loading) ? _sendOtp : null,
                          child: _resendCooldown == 0
                              ? const Text("Resend OTP")
                              : Text("Resend OTP (${_resendCooldown}s)"),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white.withOpacity(0.2),
                          ),
                          onPressed: _loading ? null : _verifyOtp,
                          child: _loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator()) : const Text("Verify OTP", style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ]
                  else
                    GlassCard(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: const [
                            Icon(Icons.verified, color: Colors.greenAccent),
                            SizedBox(width: 8),
                            Text("Phone verified",
                                style: TextStyle(color: Colors.white)),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 8),
                  const Text(
                    "Your mobile (after OTP verify) becomes your login. Email is for receipts & updates.",
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController c,
      {String? Function(String?)? validator,
        TextInputType? keyboardType,
        bool obscureText = false,
        int? maxLength,
        List<TextInputFormatter>? inputFormatters}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        style: const TextStyle(color: Colors.white),
        validator: validator,
        obscureText: obscureText,
        inputFormatters: inputFormatters,
        keyboardType: keyboardType,
        maxLength: maxLength,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white70),
          counterText: "",
          filled: true,
          fillColor: Colors.white.withOpacity(0.10),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.25)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.white),
          ),
        ),
      ),
    );
  }

  void _back() {
    if (_step == 0) return;
    setState(() => _step -= 1);
    _page.previousPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

// --------------------------------------------------------------------------
// The following functions used to implement Payment & Done steps are kept
// here commented out so you can easily restore them later.
// --------------------------------------------------------------------------

/*
  // Widget _stepPayment() {
  //   return SingleChildScrollView(
  //     padding: const EdgeInsets.all(5),
  //     child: GlassCard(
  //       child: Padding(
  //         padding: const EdgeInsets.all(16),
  //         child: Column(
  //           crossAxisAlignment: CrossAxisAlignment.start,
  //           children: [
  //             const Text("Step 2: Payment",
  //                 style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
  //             const SizedBox(height: 8),
  //             const Text("₹1499 one-time trainer activation fee",
  //                 style: TextStyle(color: Colors.white70)),
  //             const SizedBox(height: 16),
  //
  //             Center(
  //               child: Column(
  //                 children: [
  //                   Container(
  //                     height: 180,
  //                     width: 180,
  //                     decoration: BoxDecoration(
  //                       color: Colors.white10,
  //                       borderRadius: BorderRadius.circular(8),
  //                     ),
  //                     child: Column(
  //                       children: [
  //                         Image.asset('assets/image/upi-qr.jpeg', width: 150, height: 150, fit: BoxFit.fill),
  //                         const SizedBox(height: 8),
  //                         const Text("UPI ID: fitstreet@upi", style: TextStyle(color: Colors.white70)),
  //                       ],
  //                     ),
  //                   ),
  //                   const SizedBox(height: 12),
  //                 ],
  //               ),
  //             ),
  //
  //             const SizedBox(height: 16),
  //            const GlassCard(
  //               child: Padding(
  //                 padding: EdgeInsets.all(12),
  //                 child: Column(
  //                   crossAxisAlignment: CrossAxisAlignment.start,
  //                   children: [
  //                     Text("You’ll get instantly:", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
  //                     SizedBox(height: 8),
  //                     _Bullet("Premium T-shirt 🎽"),
  //                     _Bullet("FitStreet ID card 🪪"),
  //                     _Bullet("Access to Dashboard (book clients, earn ₹₹₹)"),
  //                   ],
  //                 ),
  //               ),
  //             ),
  //
  //             const SizedBox(height: 12),
  //             CheckboxListTile(
  //               value: _acceptTnc,
  //               onChanged: (v) => setState(() => _acceptTnc = v ?? false),
  //               checkColor: Colors.white,
  //               activeColor: Colors.white.withOpacity(0.25),
  //               title: const Text("I agree to Terms & Conditions",
  //                   style: TextStyle(color: Colors.white)),
  //               controlAffinity: ListTileControlAffinity.leading,
  //             ),
  //
  //             const SizedBox(height: 8),
  //           ],
  //         ),
  //       ),
  //     ),
  //   );
  // }
  //
  //
  // Widget _stepConfirm() {
  //   final displayId = _displayTrainerId();
  //   return Padding(
  //     padding: const EdgeInsets.all(16),
  //     child: GlassCard(
  //       child: Padding(
  //         padding: const EdgeInsets.all(20),
  //         child: Column(
  //           mainAxisAlignment: MainAxisAlignment.center,
  //           children: [
  //             const Icon(Icons.celebration, color: Colors.yellowAccent, size: 60),
  //             const SizedBox(height: 12),
  //             Text(
  //               "Welcome to FitStreet, ${_nameCtrl.text.isEmpty ? "Trainer" : _nameCtrl.text}!",
  //               textAlign: TextAlign.center,
  //               style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
  //             ),
  //             const SizedBox(height: 10),
  //             Text("Your Trainer ID",
  //                 style: const TextStyle(color: Colors.white70, fontSize: 14)),
  //             const SizedBox(height: 6),
  //             Container(
  //               padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
  //               decoration: BoxDecoration(
  //                 color: Colors.white12,
  //                 borderRadius: BorderRadius.circular(999),
  //               ),
  //               child: Text(displayId,
  //                   style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
  //             ),
  //             const SizedBox(height: 16),
  //             const GlassCard(
  //               child: ListTile(
  //                 leading: Icon(Icons.verified_user, color: Colors.white),
  //                 title: Text("Next: Complete KYC to unlock payouts",
  //                     style: TextStyle(color: Colors.white)),
  //                 subtitle: Text("PAN, bank details & address proof",
  //                     style: TextStyle(color: Colors.white70, fontSize: 12)),
  //               ),
  //             ),
  //             const SizedBox(height: 16),
  //             const Text(
  //               "Tap “Go to Dashboard” below to start accepting bookings.",
  //               textAlign: TextAlign.center,
  //               style: TextStyle(color: Colors.white70),
  //             ),
  //           ],
  //         ),
  //       ),
  //     ),
  //   );
  // }
  */

}

// Small bullet row kept commented for future use with payment step
// class _Bullet extends StatelessWidget {
//   final String text;
//   const _Bullet(this.text);
//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: const EdgeInsets.only(bottom: 6),
//       child: Row(
//         children: [
//           const Text("• ", style: TextStyle(color: Colors.white70)),
//           Expanded(child: Text(text, style: const TextStyle(color: Colors.white70)))
//         ],
//       ),
//     );
//   }
// }
