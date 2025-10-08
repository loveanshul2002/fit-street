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
import '../../state/auth_manager.dart';
import '../../services/fitstreet_api.dart';

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

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  @override
  void dispose() {
    _accCtrl.dispose();
    _ifscCtrl.dispose();
    _bankCtrl.dispose();
    _upiCtrl.dispose();
    super.dispose();
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
          final accountNumber = data['accountNumber']?.toString() ?? '';
          final ifscCode = data['ifscCode']?.toString() ?? '';
          final bankName = data['bankName']?.toString() ?? '';
          final upiId = data['upiId']?.toString() ?? '';
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
                            field('Account Number', _accCtrl,
                                validator: req,
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly]),
                            field('IFSC Code', _ifscCtrl,
                                validator: req,
                                inputFormatters: [UpperCaseTextFormatter(), FilteringTextInputFormatter.allow(RegExp(r'[A-Z0-9]'))],
                                maxLength: 11),
                            field('Bank Name', _bankCtrl, validator: req),
                            field('UPI ID (optional)', _upiCtrl,
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
                                onPressed: _saving ? null : _save,
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
