// lib/screens/trainer/trainer_register_wizard.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:async';
import '../../widgets/scaffold_with_bg.dart';
import '../../widgets/app_background.dart';


import '../../config/app_colors.dart';
import '../../services/fitstreet_api.dart';
import '../../state/auth_manager.dart';
import '../../utils/role_storage.dart';
import '../../utils/user_role.dart';
import '../../widgets/glass_card.dart';
import 'trainer_dashboard.dart';
import '../../widgets/glass_text_field.dart';
import '../../widgets/glass_button.dart';

class TrainerRegisterWizard extends StatefulWidget {
  const TrainerRegisterWizard({super.key});

  @override
  State<TrainerRegisterWizard> createState() => _TrainerRegisterWizardState();
}

class _TrainerRegisterWizardState extends State<TrainerRegisterWizard> {
  final _page = PageController();
  int _step = 0;

  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  bool _otpSent = false;
  bool _otpVerified = false;
  final _otpCtrl = TextEditingController();

  bool _acceptTnc = false;

  // demo fallback id (if backend doesn't return one)
  final String _demoTrainerId =
      "FS${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}";

  bool _loading = false;
  String? _error;

  int? _trainerNumericId;
  String? _rawTrainerId;
  String _trainerCode = '';

  bool _submitting = false;

  // resend cooldown state
  int _resendCooldown = 0; // seconds remaining
  Timer? _resendTimer;


  // --> Payment screenshot path (picked from gallery)
  String? _paymentScreenshotPath;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadSavedIds();
  }

  /// Load stored trainerUniqueId (preferred) or fallback IDs from SharedPreferences/AuthManager.
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

      // Helper to extract a nice display id from whatever string we got
      String? extractDisplayId(String? s) {
        if (s == null) return null;
        final trimmed = s.trim();

        // 1) If it's already a short single token like "Bull2513" or 24-hex, return it
        final tokenMatch = RegExp(r'^[A-Za-z0-9\-_]{3,40}$').firstMatch(trimmed);
        if (tokenMatch != null) return trimmed;

        // 2) If it looks like JSON (starts with { or [), try decode and pick trainerUniqueId/_id/id
        if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
          try {
            final decoded = jsonDecode(trimmed);
            if (decoded is Map) {
              final cand = (decoded['trainerUniqueId'] ?? decoded['trainerUniqueID'] ?? decoded['trainerUniqueid'] ?? decoded['_id'] ?? decoded['id']);
              if (cand != null) return cand.toString();
            }
          } catch (_) {
            // not strict JSON, continue to heuristics
          }
        }

        // 3) Look for trainerUniqueId: Bull123 or trainerUniqueId":"Bull123 patterns
        final uniMatch = RegExp("trainerUniqueId\\s*[:=]\\s*['\"]?([A-Za-z0-9_-]+)['\"]?").firstMatch(trimmed);
        if (uniMatch != null) return uniMatch.group(1);

        // 4) Look for a 24-hex DB id
        final hex = RegExp(r'([0-9a-fA-F]{24})').firstMatch(trimmed);
        if (hex != null) return hex.group(1);

        // 5) As a last fallback, return a shortened preview (so UI doesn't overflow)
        final preview = trimmed.length > 20 ? '${trimmed.substring(0, 18)}...' : trimmed;
        return preview;
      }

      final display = extractDisplayId(raw);
      if (display != null && mounted) setState(() => _rawTrainerId = display);

      // Also load numeric id if present
      try {
        final auth = context.read<AuthManager>();
        final num = await auth.getTrainerNumericId();
        if (num != null && mounted) setState(() => _trainerNumericId = num);
      } catch (_) {}
    } catch (e) {
      debugPrint('Failed to load saved ids: $e');
    }
  }

  void _startResendCooldown([int seconds = 30]) {
    // cancel existing timer if any
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


  @override
  void dispose() {
    _page.dispose();
    _nameCtrl.dispose();
    _mobileCtrl.dispose();
    _emailCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
    _resendTimer?.cancel();

  }

  Future<void> _next() async {
    if (_step == 0) {
      if (_formKey.currentState!.validate() && _otpVerified) {
        setState(() => _step = 1);
        _page.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      } else if (!_otpVerified) {
        _snack("Please verify your mobile with OTP.");
      }
      return;
    }

    if (_step == 1) {
      if (_acceptTnc) {
        // Save basic details (name + email) to server BEFORE moving on,
        // but do not block if server fails — always allow continue (saved locally).
        final saved = await _saveBasicDetailsToServer();
        if (saved) {
          setState(() => _step = 2);
          _page.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
        }
      } else {
        _snack("Please accept Terms & Conditions to continue.");
      }
      return;
    }

    if (_step == 2) {
      _onRegistrationComplete();
    }
  }

  /// Attempts to save name + email to server. Returns true on success or fallback local save.
  Future<bool> _saveBasicDetailsToServer() async {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();

    if (name.isEmpty && email.isEmpty) {
      _snack("Name or email should not be empty.");
      return false;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final sp = await SharedPreferences.getInstance();

    try {
      final auth = context.read<AuthManager>();

      // Try getting preferred/trusted trainer id from AuthManager if available
      String? prefId;
      try {
        prefId = await auth.getApiTrainerId();
      } catch (_) {
        prefId = null;
      }

      // fallback to stored prefs
      prefId ??= sp.getString('fitstreet_trainer_id') ?? sp.getString('fitstreet_trainer_db_id') ?? '';

      // If no prefId, just save locally and proceed
      if (prefId == null || prefId.isEmpty) {
        await sp.setString('fitstreet_trainer_name', name);
        if (email.isNotEmpty) await sp.setString('fitstreet_trainer_email', email);
        _snack("Saved locally — will update on registration completion.");
        return true;
      }

      // Attempt server update
      try {
        final res = await auth.updateTrainerProfile(prefId, fullName: name.isEmpty ? null : name, email: email.isEmpty ? null : email);

        final statusCode = (res != null && res['statusCode'] is int) ? res['statusCode'] as int : 0;
        final body = res != null ? res['body'] : null;

        if (statusCode == 200 || statusCode == 201) {
          // success: persist locally and fetch latest
          await sp.setString('fitstreet_trainer_name', name);
          if (email.isNotEmpty) await sp.setString('fitstreet_trainer_email', email);
          try {
            await auth.fetchTrainerProfile(prefId);
            await auth.fetchTrainerProfile(prefId);
            // refresh UI to show backend trainerUniqueId if returned
            await _loadSavedIds();
          } catch (_) {}
          _snack("Basic details saved on server.");
          return true;
        } else {
          // NON-200: fallback to local save but still allow continue
          await sp.setString('fitstreet_trainer_name', name);
          if (email.isNotEmpty) await sp.setString('fitstreet_trainer_email', email);

          String msg = 'Server returned ${statusCode == 0 ? 'no response' : statusCode}';
          try {
            if (body is Map) msg = (body['message'] ?? body['error'] ?? body['msg'] ?? msg).toString();
            else if (res['error'] != null) msg = res['error'].toString();
          } catch (_) {}

          debugPrint('updateTrainerProfile non-200: $statusCode -> $body');
          _snack("Saved locally. Server update failed: $msg — you can continue; we'll sync later.");
          return true; // allow wizard to proceed
        }
      } catch (e) {
        // network/exception: fallback to local save and proceed
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

  void _back() {
    if (_step == 0) return;
    setState(() => _step -= 1);
    _page.previousPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  Future<void> _onRegistrationComplete() async {
    try {
      await saveUserRole(UserRole.trainer);
    } catch (_) {}

    try {
      await _submitTrainerProfile();
    } catch (_) {}

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const TrainerDashboard()),
          (route) => false,
    );
  }

  Future<void> _sendOtp() async {
    final mobile = _mobileCtrl.text.trim();
    if (mobile.length != 10 || !RegExp(r'^[0-9]{10}$').hasMatch(mobile)) {
      _snack("Enter a valid 10-digit mobile number.");
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final auth = context.read<AuthManager>();
    try {
      final res = await auth.sendSignupOtp(mobile, role: 'trainer');
      final status = res['statusCode'] ?? 0;
      final body = res['body'];

      if (status == 200 || status == 201) {
        setState(() {
          _otpSent = true;
          _error = null;
        });
        // start 30s cooldown for resending
        _startResendCooldown(30);
        _snack("OTP sent to $mobile");
      }

      else {
        String msg = 'Failed to send OTP';
        try {
          if (body is Map && (body['message'] != null || body['error'] != null)) msg = (body['message'] ?? body['error']).toString();
          else if (res['message'] != null) msg = res['message'].toString();
        } catch (_) {}
        setState(() => _error = msg);
        _snack(msg);
      }
    } catch (e) {
      setState(() => _error = 'Network error: ${e.toString()}');
      _snack('Network error: ${e.toString()}');
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
      _error = null;
    });

    final auth = context.read<AuthManager>();
    try {
      final res = await auth.verifySignupOtp(mobile, otp, role: 'trainer');
      final success = (res['success'] == true) || ((res['statusCode'] ?? 0) == 200) || ((res['statusCode'] ?? 0) == 201);

      if (success) {
        setState(() {
          _otpVerified = true;
        });

        // Save display name (keeps existing behavior)
        if (name.isNotEmpty) await saveUserName(name);

        // Persist name/email/mobile locally so KYC and other screens can read them
        try {
          final sp = await SharedPreferences.getInstance();
          if (name.isNotEmpty) await sp.setString('fitstreet_trainer_name', name);
          if (email.isNotEmpty) await sp.setString('fitstreet_trainer_email', email);
          if (mobile.isNotEmpty) await sp.setString('fitstreet_trainer_mobile', mobile);
        } catch (_) {}

        // --- Robust extraction of trainer id(s) from response / prefs ---
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

        // res['id'] is another common place
        try {
          if ((dbId == null || dbId.isEmpty) && res['id'] != null) dbId = res['id'].toString();
        } catch (_) {}

        // helper: try to normalize stored/passed id strings to a clean 24-hex if possible
        String? _normalizeId(dynamic raw) {
          if (raw == null) return null;
          final s = raw.toString().trim();
          if (s.isEmpty) return null;
          // already a 24-hex DB id
          final hexMatch = RegExp(r'^[0-9a-fA-F]{24}$').firstMatch(s);
          if (hexMatch != null) return s;
          // if JSON-like string, try to extract _id or id
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
          // try to find any 24-hex substring
          final extract = RegExp(r'([0-9a-fA-F]{24})').firstMatch(s);
          if (extract != null) return extract.group(1);
          // fallback: return trimmed string (may be trainerUniqueId like Bull2512)
          return s;
        }

        // Build list of candidate ids (prefer DB id, then normalize stored prefs)
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

        // also add trainerUnique (readable code) as a last-ditch candidate (but it's usually not a DB id)
        if (trainerUnique != null && trainerUnique.isNotEmpty && !candidates.contains(trainerUnique)) {
          candidates.add(trainerUnique);
        }

        // Try to use the first candidate that looks reasonable
        String? idToUse;
        for (final c in candidates) {
          if (c == null) continue;
          final t = c.trim();
          if (t.isEmpty) continue;
          idToUse = t;
          break;
        }

        if (idToUse != null && idToUse.isNotEmpty) {
          try {
            // Use the normalized id to update profile and fetch latest profile
            await auth.updateTrainerProfile(idToUse, fullName: name.isEmpty ? null : name, email: email.isEmpty ? null : email);
            await auth.fetchTrainerProfile(idToUse);
            // refresh local UI/ids if you have a helper for that
            try {
              await _loadSavedIds();
            } catch (_) {}
          } catch (e) {
            debugPrint('verifyOtp: update/fetch using id $idToUse failed: $e');
          }
        } else {
          // no usable id found — we saved name/email/mobile locally so the KYC should still prefill
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
        setState(() => _error = msg);
        _snack(msg);
      }
    } catch (e) {
      setState(() => _error = 'Network error: ${e.toString()}');
      _snack('Network error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }


  void _snack(String m) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  String _formatTrainerCode(int numericId) {
    final yearTwo = (DateTime.now().year % 100).toString().padLeft(2, '0');
    final idStr = numericId.toString().padLeft(2, '0');
    return 'bull$yearTwo$idStr';
  }

  String _displayTrainerId() {
    // Prefer backend unique id if available, but keep it short to avoid the blob problem
    if (_rawTrainerId != null && _rawTrainerId!.isNotEmpty) {
      final s = _rawTrainerId!.trim();
      return s.length <= 30 ? s : '${s.substring(0, 27)}...';
    }
    return _demoTrainerId;
  }

  /// Pick payment screenshot from gallery
  Future<void> _pickPaymentScreenshot() async {
    try {
      final XFile? picked = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 2000, maxHeight: 2000, imageQuality: 85);
      if (picked == null) return;
      setState(() => _paymentScreenshotPath = picked.path);
    } catch (e) {
      debugPrint('pickPaymentScreenshot error: $e');
      _snack('Failed to pick image.');
    }
  }

  /// Submit profile via FitstreetApi multipart endpoint
  Future<void> _submitTrainerProfile() async {
    if (_submitting) return;
    setState(() => _submitting = true);

    try {
      final sp = await SharedPreferences.getInstance();
      final savedToken = sp.getString('fitstreet_token') ?? '';

      // Try to obtain a preferred API id from AuthManager (DB _id or canonical)
      String? prefId;
      try {
        final auth = context.read<AuthManager>();
        prefId = await auth.getApiTrainerId();
      } catch (_) {
        prefId = null;
      }

      // Fallback to stored prefs
      prefId ??= sp.getString('fitstreet_trainer_id') ?? sp.getString('fitstreet_trainer_db_id') ?? '';

      final useDemoIfMissing = prefId == null || prefId.isEmpty;
      if (useDemoIfMissing) prefId = _demoTrainerId;

      debugPrint('Submitting profile - preferredId: $prefId (demo fallback: $useDemoIfMissing)');

      final fitApi = FitstreetApi('https://api.fitstreet.in', token: savedToken);

      final fields = <String, dynamic>{
        'fullName': _nameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'mobileNumber': _mobileCtrl.text.trim(),
        'bioData': '',
        'commission': '10',
      };

      // read db id fallback candidate from prefs
      final dbIdRaw = sp.getString('fitstreet_trainer_db_id') ?? sp.getString('fitstreet_trainer_db_raw');
// Normalize any candidate id (String, JSON-string, Map, int, etc.) into a plain id String.
      String? _normalizeCandidate(dynamic cand) {
        if (cand == null) return null;

        if (cand is String) {
          final s = cand.trim();
          if (s.isEmpty) return null;
          if (s.startsWith('{') && s.endsWith('}')) {
            try {
              final decoded = jsonDecode(s);
              if (decoded is Map) {
                return (decoded['_id'] ?? decoded['id'] ?? decoded['trainerUniqueId'] ?? decoded['trainerUniqueID'])?.toString();
              }
            } catch (_) {
              // not JSON - fallthrough to return string
            }
          }
          return s.isEmpty ? null : s;
        }

        if (cand is Map) {
          return (cand['_id'] ?? cand['id'] ?? cand['trainerUniqueId'] ?? cand['trainerUniqueID'])?.toString();
        }

        try {
          final s = cand.toString();
          return s.isEmpty ? null : s;
        } catch (_) {
          return null;
        }
      }

      // Build normalized list of string IDs to try
      final List<String> attemptIdsStrings = <String>[];
      final nPref = _normalizeCandidate(prefId);
      if (nPref != null && nPref.isNotEmpty) attemptIdsStrings.add(nPref);
      final nDb = _normalizeCandidate(dbIdRaw);
      if (nDb != null && nDb.isNotEmpty && !attemptIdsStrings.contains(nDb)) attemptIdsStrings.add(nDb);
      if (attemptIdsStrings.isEmpty) attemptIdsStrings.add(_demoTrainerId);

      debugPrint('Normalized attemptIdsStrings: $attemptIdsStrings');

      http.Response? lastResp;
      dynamic lastParsed;

      for (final idToTry in attemptIdsStrings) {
        if (idToTry.trim().isEmpty) {
          debugPrint('Skipping empty normalized idToTry: "$idToTry"');
          continue;
        }

        debugPrint('Trying update with id (string): $idToTry');

        // Build files map for this attempt (only payment screenshot for register wizard)
        final Map<String, File> files = {};
        try {
          if (_paymentScreenshotPath != null && _paymentScreenshotPath!.isNotEmpty) {
            final f = File(_paymentScreenshotPath!);
            if (await f.exists()) {
              files['paymentSSImageURL'] = f;
            } else {
              debugPrint('Payment screenshot file missing at path $_paymentScreenshotPath');
            }
          }
        } catch (e) {
          debugPrint('Error preparing files for submitTrainerProfile: $e');
        }

        final streamed = await fitApi.updateTrainerProfileMultipart(idToTry, fields: fields, files: files.isEmpty ? null : files);
        final resp = await http.Response.fromStream(streamed);

        debugPrint('Attempt id:$idToTry -> status ${resp.statusCode}, body: ${resp.body}');

        lastResp = resp;
        try {
          lastParsed = jsonDecode(resp.body);
        } catch (_) {
          lastParsed = resp.body;
        }

        if (resp.statusCode == 200 || resp.statusCode == 201) {
          // persist any returned trainer ids
          try {
            if (lastParsed is Map) {
              final data = lastParsed['data'] ?? lastParsed;
              if (data is Map) {
                final returnedUnique = (data['trainerUniqueId'] ?? data['trainerUniqueID'])?.toString();
                final returnedDb = (data['_id'] ?? data['id'])?.toString();
                if (returnedUnique != null && returnedUnique.isNotEmpty) {
                  await sp.setString('fitstreet_trainer_unique_id', returnedUnique);
                  // update UI immediately
                  if (mounted) setState(() => _rawTrainerId = returnedUnique);
                }
                if (returnedDb != null && returnedDb.isNotEmpty) {
                  await sp.setString('fitstreet_trainer_db_id', returnedDb);
                  await sp.setString('fitstreet_trainer_id', returnedDb); // canonical API id
                }
                // If backend returns payment screenshot URL, you could persist it here too:
                try {
                  final paymentUrl = (data['paymentSSImageURL'] ?? data['paymentSSImageUrl'] ?? data['paymentScreenshot'])?.toString();
                  if (paymentUrl != null && paymentUrl.isNotEmpty) {
                    await sp.setString('fitstreet_payment_ss_url', paymentUrl);
                  }
                } catch (_) {}
              }
            }
          } catch (_) {}

          _snack('Profile updated successfully');
          if (mounted) setState(() => _submitting = false);
          return;
        }

        final bodyLower = (resp.body ?? '').toString().toLowerCase();
        if (resp.statusCode == 404 || bodyLower.contains('not found') || bodyLower.contains('invalid or missing') || bodyLower.contains('no record')) {
          debugPrint('Server indicates id not found for $idToTry; trying next fallback id if any.');
          continue; // try next id
        } else {
          String msg = 'Failed to update profile';
          if (lastParsed is Map) msg = (lastParsed['message'] ?? lastParsed['error'] ?? lastParsed['msg'] ?? msg).toString();
          else if (lastResp != null && lastResp.body.isNotEmpty) msg = lastResp.body;
          _snack(msg);
          if (mounted) setState(() => _submitting = false);
          return;
        }
      }

      // Exhausted attempts
      String finalMsg = 'Failed to update profile (all ids tried)';
      if (lastParsed is Map) finalMsg = (lastParsed['message'] ?? lastParsed['error'] ?? finalMsg).toString();
      else if (lastResp != null && lastResp.body.isNotEmpty) finalMsg = lastResp.body;
      _snack(finalMsg);
    } catch (e, st) {
      debugPrint('submitTrainerProfile exception: $e\n$st');
      _snack('Exception: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldWithBg(

        title: const Text("Register as Trainer"),


        child: SafeArea(
          child: Column(
            children: [
              // Step indicator
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: GlassCard(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      children: [
                        _stepDot(0, "Basic"),
                        _line(),
                        _stepDot(1, "Payment"),
                        _line(),
                        _stepDot(2, "Done"),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Pages
              Expanded(
                child: PageView(
                  controller: _page,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _stepBasic(),
                    _stepPayment(),
                    _stepConfirm(),
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
                        child: Text(_step < 2 ? "Continue" : "Go to Dashboard",
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
  }


  // ---- UI pieces ----

  Widget _stepDot(int index, String label) {
    final active = _step == index;
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? Colors.orange : Colors.white.withOpacity(0.25),
              border: Border.all(color: Colors.white.withOpacity(0.5)),
            ),
            alignment: Alignment.center,
            child: Text("${index + 1}",
                style: TextStyle(
                  color: active ? AppColors.secondary : Colors.white,
                  fontWeight: FontWeight.w800,
                )),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _line() => const SizedBox(width: 12);

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
                  const Text("Step 1: Basic Details",
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
                        // Resend button with cooldown
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

  Widget _stepPayment() {
    return Padding(
      padding: const EdgeInsets.all(5),
      child: Column(
        children: [
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Step 2: Payment",
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text("₹1499 one-time trainer activation fee",
                      style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 16),

                  // Only QR + UPI id + screenshot upload (UI stub)
                  Center(
                    child: Column(
                      children: [
                        // Placeholder for QR image (replace with your asset or network QR)
                        Container(
                          height: 180,
                          width: 180,
                          decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              // replace asset path if needed
                              Image.asset('assets/image/upi-qr.jpeg', width: 150, height: 150, fit: BoxFit.fill),
                              const SizedBox(height: 8),
                              const Text("UPI ID: fitstreet@upi", style: TextStyle(color: Colors.white70)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton.icon(
                              onPressed: _pickPaymentScreenshot,
                              icon: const Icon(Icons.photo),
                              label: const Text("Choose Screenshot"),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.white12),
                            ),
                            const SizedBox(width: 12),
                            // show small thumbnail if selected
                            if (_paymentScreenshotPath != null && _paymentScreenshotPath!.isNotEmpty)
                              GestureDetector(
                                onTap: () {
                                  // tap to preview (simple dialog)
                                  showDialog(
                                    context: context,
                                    builder: (_) => Dialog(
                                      child: Image.file(File(_paymentScreenshotPath!)),
                                    ),
                                  );
                                },
                                child: Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.white24),
                                  ),
                                  clipBehavior: Clip.hardEdge,
                                  child: Image.file(File(_paymentScreenshotPath!), fit: BoxFit.cover),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                  const GlassCard(
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("You’ll get instantly:", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                          SizedBox(height: 8),
                          _Bullet("Premium T-shirt 🎽"),
                          _Bullet("FitStreet ID card 🪪"),
                          _Bullet("Access to Dashboard (book clients, earn ₹₹₹)"),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),
                  CheckboxListTile(
                    value: _acceptTnc,
                    onChanged: (v) => setState(() => _acceptTnc = v ?? false),
                    checkColor: Colors.white,
                    activeColor: Colors.white.withOpacity(0.25),
                    title: const Text("I agree to Terms & Conditions",
                        style: TextStyle(color: Colors.white)),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepConfirm() {
    final displayId = _displayTrainerId();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: GlassCard(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.celebration, color: Colors.yellowAccent, size: 60),
              const SizedBox(height: 12),
              Text(
                "Welcome to FitStreet, ${_nameCtrl.text.isEmpty ? "Trainer" : _nameCtrl.text}!",
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text("Your Trainer ID",
                  style: const TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(displayId,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 16),
              const GlassCard(
                child: ListTile(
                  leading: Icon(Icons.verified_user, color: Colors.white),
                  title: Text("Next: Complete KYC to unlock payouts",
                      style: TextStyle(color: Colors.white)),
                  subtitle: Text("PAN, bank details & address proof",
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "Tap “Go to Dashboard” below to start accepting bookings.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70),
              ),
            ],
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
}

// Small bullet row
class _Bullet extends StatelessWidget {
  final String text;
  const _Bullet(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          const Text("• ", style: TextStyle(color: Colors.white70)),
          Expanded(child: Text(text, style: const TextStyle(color: Colors.white70)))
        ],
      ),
    );
  }
}
