// lib/screens/trainer/bank_details_edit_screen.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import '../../config/app_colors.dart';
import '../../widgets/glass_card.dart';
import '../trainer/kyc/utils/ui_helpers.dart';
import '../trainer/kyc/utils/input_formatters.dart';
import '../trainer/kyc/trainer_kyc_wizard.dart';
import '../../state/auth_manager.dart';
import '../../services/fitstreet_api.dart';
import '../../utils/kyc_utils.dart';

class BankDetailsEditScreen extends StatefulWidget {
  const BankDetailsEditScreen({super.key});

  @override
  State<BankDetailsEditScreen> createState() => _BankDetailsEditScreenState();
}

class _BankDetailsEditScreenState extends State<BankDetailsEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _accCtrl = TextEditingController();
  final _ifscCtrl = TextEditingController();
  final _bankCtrl = TextEditingController();
  final _upiCtrl = TextEditingController();

  bool _loading = false;
  bool _saving = false;
  bool _isKycCompleted = false;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Check if we returned from another screen and refresh KYC status
    _refreshKycStatus();
  }

  @override
  void dispose() {
    _accCtrl.dispose();
    _ifscCtrl.dispose();
    _bankCtrl.dispose();
    _upiCtrl.dispose();
    super.dispose();
  }

  Future<void> _refreshKycStatus() async {
    // Quick KYC status check without full reload
    try {
      final sp = await SharedPreferences.getInstance();
      final token = sp.getString('fitstreet_token') ?? '';

      String? trainerId;
      try {
        trainerId = await context.read<AuthManager>().getApiTrainerId();
      } catch (_) {
        trainerId = null;
      }
      trainerId ??= sp.getString('fitstreet_trainer_db_id') ?? sp.getString('fitstreet_trainer_id');

      if (trainerId == null || trainerId.isEmpty) return;

      final api = FitstreetApi('https://api.fitstreet.in', token: token);
      final resp = await api.getTrainer(trainerId);
      if (resp.statusCode == 200) {
        dynamic body;
        try { body = jsonDecode(resp.body); } catch (_) { body = resp.body; }
        final data = (body is Map) ? (body['data'] ?? body) : null;
        if (data is Map) {
          final wasKycCompleted = _isKycCompleted;
          // Convert to Map<String, dynamic> for type safety
          final Map<String, dynamic> trainerData = Map<String, dynamic>.from(data);

          // Check KYC status using utility function
          _isKycCompleted = KycUtils.isKycCompleted(trainerData);

          // Only update UI if KYC status changed
          if (mounted && wasKycCompleted != _isKycCompleted) {
            setState(() {});
            if (_isKycCompleted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('KYC completed! You can now edit your bank details.')),
              );
            }
          }
        }
      }
    } catch (e) {
      // Ignore errors in KYC status refresh
    }
  }

  Future<void> _loadInitial() async {
    setState(() => _loading = true);
    try {
      final sp = await SharedPreferences.getInstance();
      final token = sp.getString('fitstreet_token') ?? '';

      String? trainerId;
      try {
        trainerId = await context.read<AuthManager>().getApiTrainerId();
      } catch (_) {
        trainerId = null;
      }
      trainerId ??= sp.getString('fitstreet_trainer_db_id') ?? sp.getString('fitstreet_trainer_id');

      if (trainerId == null || trainerId.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Trainer id not found. Please login again.')));
        return;
      }

      final api = FitstreetApi('https://api.fitstreet.in', token: token);
      final resp = await api.getTrainer(trainerId);
      if (resp.statusCode == 200) {
        dynamic body;
        try { body = jsonDecode(resp.body); } catch (_) { body = resp.body; }
        final data = (body is Map) ? (body['data'] ?? body) : null;
        if (data is Map) {
          // Convert to Map<String, dynamic> for type safety
          final Map<String, dynamic> trainerData = Map<String, dynamic>.from(data);

          // Check KYC status using utility function
          _isKycCompleted = KycUtils.isKycCompleted(trainerData);

          final accountNumber = trainerData['accountNumber']?.toString() ?? '';
          final ifscCode = trainerData['ifscCode']?.toString() ?? '';
          final bankName = trainerData['bankName']?.toString() ?? '';
          final upiId = trainerData['upiId']?.toString() ?? '';
          if (mounted) {
            _accCtrl.text = accountNumber;
            _ifscCtrl.text = ifscCode;
            _bankCtrl.text = bankName;
            _upiCtrl.text = upiId;
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    // Check KYC status before allowing save
    if (!_isKycCompleted) {
      _showKycRequiredDialog();
      return;
    }

    setState(() => _saving = true);
    try {
      final sp = await SharedPreferences.getInstance();
      final token = sp.getString('fitstreet_token') ?? '';

      String? trainerId;
      try {
        trainerId = await context.read<AuthManager>().getApiTrainerId();
      } catch (_) {
        trainerId = null;
      }
      trainerId ??= sp.getString('fitstreet_trainer_db_id') ?? sp.getString('fitstreet_trainer_id');

      if (trainerId == null || trainerId.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Trainer id not found. Please login again.')));
        return;
      }

      final api = FitstreetApi('https://api.fitstreet.in', token: token);
      final fields = {
        'accountNumber': _accCtrl.text.trim(),
        'ifscCode': _ifscCtrl.text.trim(),
        'bankName': _bankCtrl.text.trim(),
        if (_upiCtrl.text.trim().isNotEmpty) 'upiId': _upiCtrl.text.trim(),
      };

      final streamed = await api.updateTrainerProfileMultipart(trainerId, fields: fields);
      final resp = await http.Response.fromStream(streamed);

      if (resp.statusCode == 200 || resp.statusCode == 201) {
        try {
          await context.read<AuthManager>().fetchTrainerProfile(trainerId);
        } catch (_) {}
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bank details updated')));
        Navigator.pop(context, true);
      } else {
        String msg = 'Failed (${resp.statusCode})';
        try {
          final body = jsonDecode(resp.body);
          if (body is Map && (body['message'] != null || body['error'] != null)) {
            msg = (body['message'] ?? body['error']).toString();
          }
        } catch (_) {}
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showKycRequiredDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
              SizedBox(width: 8),
              Text('KYC Required', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text(
            'You need to complete your KYC verification before you can edit your bank details. Please complete your KYC process first.',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK', style: TextStyle(color: Colors.white)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _navigateToKyc();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primary,
              ),
              child: const Text('Complete KYC'),
            ),
          ],
        );
      },
    );
  }

  void _navigateToKyc() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const TrainerKycWizard(),
      ),
    ).then((result) {
      if (result == true) {
        _loadInitial(); // Reload to check KYC status
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bank Details'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primary, AppColors.secondary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(16),
                child: GlassCard(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _formKey,
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Section('2. Bank & Payout'),

                            // KYC Status Banner
                            if (!_isKycCompleted)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.9),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.orange.shade300),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 24),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Complete KYC to Edit Bank Details',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          const Text(
                                            'Your bank details are read-only until KYC verification is completed.',
                                            style: TextStyle(color: Colors.white, fontSize: 14),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton(
                                      onPressed: _navigateToKyc,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        foregroundColor: Colors.orange,
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      ),
                                      child: const Text('Complete KYC', style: TextStyle(fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                              ),

                            field('Account Number', _accCtrl,
                                readOnly: !_isKycCompleted,
                                validator: req,
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly]),
                            field('IFSC Code', _ifscCtrl,
                                readOnly: !_isKycCompleted,
                                validator: req,
                                inputFormatters: [UpperCaseTextFormatter(), FilteringTextInputFormatter.allow(RegExp(r'[A-Z0-9]'))],
                                maxLength: 11),
                            field('Bank Name', _bankCtrl, readOnly: !_isKycCompleted, validator: req),
                            field('UPI ID (optional)', _upiCtrl,
                                readOnly: !_isKycCompleted,
                                validator: (v) {
                                  if (v != null && v.isNotEmpty && !v.contains('@')) {
                                    return 'Invalid UPI ID';
                                  }
                                  return null;
                                },
                                inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))]),
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerRight,
                              child: ElevatedButton.icon(
                                onPressed: (_saving || !_isKycCompleted) ? null : _save,
                                icon: const Icon(Icons.save),
                                label: _saving
                                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                    : const Text('Save changes'),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.white12),
                              ),
                            )
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
