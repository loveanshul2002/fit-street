import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/fitstreet_api.dart';
// import '../../state/auth_manager.dart';
// import 'package:provider/provider.dart';

/// Consultation screen replicating the Angular consultation form.
class ConsultationScreen extends StatefulWidget {
  const ConsultationScreen({super.key});

  @override
  State<ConsultationScreen> createState() => _ConsultationScreenState();
}

class _ConsultationScreenState extends State<ConsultationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _detailsCtrl = TextEditingController();

  bool _submitting = false;
  String? _errorMsg;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _mobileCtrl.dispose();
    _detailsCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;
    setState(() { _submitting = true; _errorMsg = null; });
    try {
      final sp = await SharedPreferences.getInstance();
      final token = sp.getString('fitstreet_token') ?? '';
      final api = FitstreetApi('https://api.fitstreet.in', token: token.isEmpty ? null : token);
      final resp = await api.createConsultation(
        name: _nameCtrl.text.trim(),
        phoneNumber: _mobileCtrl.text.trim(),
        requirement: _detailsCtrl.text.trim(),
      );
      if (!mounted) return;
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Consultation request submitted successfully. Our team will get back to you soon.')),
        );
        Navigator.pop(context); // Back to previous (dashboard/home)
      } else {
        String msg = 'Failed to submit';
        try {
          final body = resp.body.isNotEmpty ? jsonDecode(resp.body) : null;
          if (body is Map && body['error'] is String) msg = body['error'];
        } catch (_) {}
        setState(() => _errorMsg = msg);
      }
    } catch (e) {
      if (mounted) setState(() => _errorMsg = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String? _req(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    return null;
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Free Consultation'),
        flexibleSpace: Container(color: Colors.black.withOpacity(0.15)),
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 12),
                      const Text(
                        'Book Your Free Consultation',
                        style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
            _glassField(
                        child: TextFormField(
                          controller: _nameCtrl,
              autofocus: true,
                          decoration: const InputDecoration(
                            hintText: 'Name',
                            border: InputBorder.none,
                          ),
                          validator: _req,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 14),
          _glassField(
                        child: TextFormField(
                          controller: _mobileCtrl,
                          decoration: const InputDecoration(
                            hintText: 'Mobile Number',
                            border: InputBorder.none,
            counterText: '',
                          ),
                          keyboardType: TextInputType.phone,
                      
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _glassField(
                        child: TextFormField(
                          controller: _detailsCtrl,
                          decoration: const InputDecoration(
                            hintText: 'Requirement / Details',
                            border: InputBorder.none,
                          ),
                          maxLines: 3,
                          validator: _req,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 22),
                      if (_errorMsg != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(_errorMsg!, style: const TextStyle(color: Colors.redAccent)),
                        ),
                      ElevatedButton(
                        onPressed: _submitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF5B01),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
                        ),
                        child: _submitting
                            ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Submit', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                      ),
                      const SizedBox(height: 30),
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

  Widget _glassField({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24, width: 0.75),
      ),
      child: child,
    );
  }
}
