// lib/screens/trainer/profile_edit_restricted_screen.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../../config/app_colors.dart';
import '../../widgets/glass_card.dart';
import '../trainer/kyc/utils/ui_helpers.dart';
import '../trainer/kyc/trainer_kyc_wizard.dart';
import '../../state/auth_manager.dart';
import '../../services/fitstreet_api.dart';
import '../../utils/kyc_utils.dart';

class TrainerProfileEditRestrictedScreen extends StatefulWidget {
  const TrainerProfileEditRestrictedScreen({super.key});

  @override
  State<TrainerProfileEditRestrictedScreen> createState() => _TrainerProfileEditRestrictedScreenState();
}

class _TrainerProfileEditRestrictedScreenState extends State<TrainerProfileEditRestrictedScreen> {
  // Readonly fields
  String _name = '';
  String _mobile = '';
  String _dob = '';
  String _gender = '';
  String _pincode = '';
  String _city = '';
  String _state = '';
  String _address = '';
 // String _pan = '';
 // String _aadhaar = '';
 // String? _panFrontUrl;
 // String? _aadhaarFrontUrl;
 // String? _aadhaarBackUrl;

  // KYC status
  bool _isKycCompleted = false;

  // Editable
  final _emailCtrl = TextEditingController();
  final _pincodectrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _emgNameCtrl = TextEditingController();
  final _emgRelCtrl = TextEditingController();
  final _emgMobileCtrl = TextEditingController();


  String? _experience; // dropdown
  final Set<String> _languages = {};
  final _otherLangCtrl = TextEditingController();

  final _oneSessionPriceCtrl = TextEditingController();
  final _monthlyPriceCtrl = TextEditingController();

  // Specializations → edit like professional step
  final List<_SpecItem> _specsOriginal = [];
  final List<_SpecRowEdit> _specRows = [];
  final ImagePicker _picker = ImagePicker();

  bool _loading = true;
  bool _saving = false;

  // Canonical experience options used by the dropdown and saved to backend
  static const List<String> kExperienceOptions = <String>[
    '<1 year',
    '1-3 years',
    '3-5 years',
    '5-10 years',
    '10+ years',
  ];

  String _normalizeExperience(String s) {
    final v = s.trim().toLowerCase().replaceAll('yrs', 'years').replaceAll('yr', 'year');
    if (v.contains('<1')) return '<1 year';
    if (v.contains('1-3')) return '1-3 years';
    if (v.contains('3-5')) return '3-5 years';
    if (v.contains('5-10')) return '5-10 years';
    if (v.contains('10+')) return '10+ years';
    return s.trim();
  }

  String _toBackendExperience(String? v) {
    if (v == null) return '';
    switch (v) {
      case '<1 year':
        return '<1 yr';
      case '1-3 years':
        return '1-3 yrs';
      case '3-5 years':
        return '3-5 yrs';
      case '5-10 years':
        return '5-10 yrs';
      case '10+ years':
        return '10+ yrs';
      default:
        return v;
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Check if we returned from another screen and refresh KYC status
    _refreshKycStatus();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _pincodectrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _emgNameCtrl.dispose();
    _emgRelCtrl.dispose();
    _emgMobileCtrl.dispose();
    _otherLangCtrl.dispose();
    _oneSessionPriceCtrl.dispose();
    _monthlyPriceCtrl.dispose();
    super.dispose();
  }


  Future<void> _refreshKycStatus() async {
    // Quick KYC status check without full reload
    try {
      final sp = await SharedPreferences.getInstance();
      final token = sp.getString('fitstreet_token') ?? '';
      String? trainerId;
      try { trainerId = await context.read<AuthManager>().getApiTrainerId(); } catch (_) {}
      trainerId ??= sp.getString('fitstreet_trainer_db_id') ?? sp.getString('fitstreet_trainer_id');
      if (trainerId == null || trainerId.isEmpty) return;

      final api = FitstreetApi('https://api.fitstreet.in', token: token);
      final res = await api.getTrainer(trainerId);
      if (res.statusCode == 200) {
        dynamic body; try { body = jsonDecode(res.body); } catch (_) { body = res.body; }
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
                const SnackBar(content: Text('KYC completed! You can now edit your profile.')),
              );
            }
          }
        }
      }
    } catch (e) {
      // Ignore errors in KYC status refresh
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final sp = await SharedPreferences.getInstance();
      final token = sp.getString('fitstreet_token') ?? '';
      String? trainerId;
      try { trainerId = await context.read<AuthManager>().getApiTrainerId(); } catch (_) {}
      trainerId ??= sp.getString('fitstreet_trainer_db_id') ?? sp.getString('fitstreet_trainer_id');
      if (trainerId == null || trainerId.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Trainer id not found. Please login again.')));
        }
        return;
      }

      final api = FitstreetApi('https://api.fitstreet.in', token: token);
      final res = await api.getTrainer(trainerId);
      if (res.statusCode == 200) {
        dynamic body; try { body = jsonDecode(res.body); } catch (_) { body = res.body; }
        final data = (body is Map) ? (body['data'] ?? body) : null;
        if (data is Map) {
          // readonly
          _name = (data['fullName'] ?? data['name'] ?? '').toString();
          _mobile = (data['mobileNumber'] ?? data['mobile'] ?? '').toString();
          _dob = (data['dob'] ?? '').toString();
          _gender = (data['gender'] ?? '').toString();
          _pincode = (data['pincode'] ?? data['currentPincode'] ?? '').toString();
          _city = (data['city'] ?? data['currentCity'] ?? '').toString();
          _state = (data['state'] ?? data['currentState'] ?? '').toString();
          _address = (data['address'] ?? data['currentAddress'] ?? '').toString();

          // populate controllers for editable fields
          _pincodectrl.text = _pincode;
          _cityCtrl.text = _city;
          _stateCtrl.text = _state;
          _addressCtrl.text = _address;

          //  _pan = (data['panCard'] ?? '').toString();
        //  _aadhaar = (data['aadhaarCard'] ?? '').toString();
        //  _panFrontUrl = data['panFrontImageURL']?.toString();
       //   _aadhaarFrontUrl = data['aadhaarFrontImageURL']?.toString();
       //   _aadhaarBackUrl = data['aadhaarBackImageURL']?.toString();

          // Convert to Map<String, dynamic> for type safety
          final Map<String, dynamic> trainerData = Map<String, dynamic>.from(data);
          
          // Check KYC status using utility function
          _isKycCompleted = KycUtils.isKycCompleted(trainerData);

          // editable
          _emailCtrl.text = (data['email'] ?? '').toString();
          _emgNameCtrl.text = (data['emergencyPersonName'] ?? '').toString();
          _emgRelCtrl.text = (data['emergencyPersonRelation'] ?? '').toString();
          _emgMobileCtrl.text = (data['emergencyPersonMobile'] ?? '').toString();

          final expRaw = (data['experience'] ?? '').toString();
          if (expRaw.isNotEmpty) {
            final norm = _normalizeExperience(expRaw);
            _experience = kExperienceOptions.contains(norm) ? norm : null;
          } else {
            _experience = null;
          }
          final langs = (data['languages'] ?? '').toString();
          if (langs.isNotEmpty) {
            _languages.addAll(langs.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty));
          }

          final one = data['oneSessionPrice'];
          final mon = data['monthlySessionPrice'];
          _oneSessionPriceCtrl.text = one == null ? '' : one.toString();
          _monthlyPriceCtrl.text = mon == null ? '' : mon.toString();

          // specializations (list of proofs)
          try {
            final listRes = await api.getSpecializationProofs(trainerId);
            if (listRes.statusCode == 200) {
              final lb = jsonDecode(listRes.body);
              final arr = (lb is Map) ? (lb['data'] ?? lb['proofs'] ?? lb) : lb;
              if (arr is List) {
                _specsOriginal
                  ..clear();
                _specRows
                  ..forEach((r){ r.dispose(); })
                  ..clear();
                for (final item in arr) {
                  if (item is Map) {
                    final spec = _SpecItem(
                      id: (item['_id'] ?? item['id'])?.toString(),
                      specialization: (item['specialization'] ?? '').toString(),
                      certificateName: (item['certificateName'] ?? '').toString(),
                      imageUrl: item['certificateImageURL']?.toString(),
                    );
                    _specsOriginal.add(spec);
                    _specRows.add(_SpecRowEdit(
                      id: spec.id,
                      specialization: spec.specialization.isEmpty ? null : spec.specialization,
                      certificateName: spec.certificateName,
                      existingImageUrl: spec.imageUrl,
                    ));
                  }
                }
                if (_specRows.isEmpty) {
                  _specRows.add(_SpecRowEdit());
                }
              }
            }
          } catch (_) {}
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Load failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
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
      try { trainerId = await context.read<AuthManager>().getApiTrainerId(); } catch (_) {}
      trainerId ??= sp.getString('fitstreet_trainer_db_id') ?? sp.getString('fitstreet_trainer_id');
      if (trainerId == null || trainerId.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Trainer id not found. Please login again.')));
        return;
      }

      final api = FitstreetApi('https://api.fitstreet.in', token: token);
      // ensure pincode looks valid (optional)
      final pinText = _pincodectrl.text.trim();
      String? pinToSend;
      if (pinText.isNotEmpty) {
        // allow only digits and max 6
        final cleansed = pinText.replaceAll(RegExp(r'\D'), '');
        pinToSend = cleansed.length > 6 ? cleansed.substring(0, 6) : cleansed;
      }

      final fields = <String, dynamic>{
        'email': _emailCtrl.text.trim(),
        // include both variants to be safe; backend may expect either
        if (pinToSend != null && pinToSend.isNotEmpty) 'pincode': pinToSend,
        if (pinToSend != null && pinToSend.isNotEmpty) 'currentPincode': pinToSend,
        if (_addressCtrl.text.trim().isNotEmpty) 'currentAddress': _addressCtrl.text.trim(),
        if (_addressCtrl.text.trim().isNotEmpty) 'address': _addressCtrl.text.trim(),
        if (_cityCtrl.text.trim().isNotEmpty) 'currentCity': _cityCtrl.text.trim(),
        if (_cityCtrl.text.trim().isNotEmpty) 'city': _cityCtrl.text.trim(),
        if (_stateCtrl.text.trim().isNotEmpty) 'currentState': _stateCtrl.text.trim(),
        if (_stateCtrl.text.trim().isNotEmpty) 'state': _stateCtrl.text.trim(),

        if (_emgNameCtrl.text.trim().isNotEmpty) 'emergencyPersonName': _emgNameCtrl.text.trim(),
        if (_emgRelCtrl.text.trim().isNotEmpty) 'emergencyPersonRelation': _emgRelCtrl.text.trim(),
        if (_emgMobileCtrl.text.trim().isNotEmpty) 'emergencyPersonMobile': _emgMobileCtrl.text.trim(),
        if (_experience != null && _experience!.isNotEmpty) 'experience': _toBackendExperience(_experience),
        if (_languages.isNotEmpty) 'languages': _languages.join(','),
        if (_oneSessionPriceCtrl.text.trim().isNotEmpty) 'oneSessionPrice': _oneSessionPriceCtrl.text.trim(),
        if (_monthlyPriceCtrl.text.trim().isNotEmpty) 'monthlySessionPrice': _monthlyPriceCtrl.text.trim(),
      };

      // debug: print payload so you can inspect before sending
      debugPrint('Saving profile fields: ${jsonEncode(fields)}');



      final streamed = await api.updateTrainerProfileMultipart(trainerId, fields: fields);
      final resp = await http.Response.fromStream(streamed);
      if (resp.statusCode == 200 || resp.statusCode == 201) {
        // Now sync specializations based on _specRows vs _specsOriginal
        // 1) Delete removed proofs
        final originalIds = _specsOriginal.map((e) => e.id).whereType<String>().toSet();
        final currentIds = _specRows.map((e) => e.id).whereType<String>().toSet();
        final toDelete = originalIds.difference(currentIds);
        for (final id in toDelete) {
          final del = await api.deleteSpecializationProof(trainerId, id);
          if (del.statusCode != 200 && del.statusCode != 201) {
            throw Exception('Failed to delete specialization');
          }
        }

        // 2) Create/update current rows
        for (final row in _specRows) {
          final spec = (row.specialization ?? '').trim();
          if (spec.isEmpty) continue; // skip empty rows
          final certName = row.certificateNameCtrl.text.trim();

          final isChanged = row.id == null
              || row.originalSpecialization != row.specialization
              || (row.originalCertificateName ?? '') != certName
              || row.certificatePhotoPath != null; // photo replaced

          if (row.id == null || isChanged) {
            if (row.id != null && isChanged) {
              final del = await api.deleteSpecializationProof(trainerId, row.id!);
              if (del.statusCode != 200 && del.statusCode != 201) {
                throw Exception('Failed to update specialization');
              }
            }
            if (row.certificatePhotoPath != null) {
              final file = File(row.certificatePhotoPath!);
              final create = await api.createSpecializationProof(trainerId, spec, file, certificateName: certName.isEmpty ? null : certName);
              if (create.statusCode != 200 && create.statusCode != 201) {
                throw Exception('Failed to add specialization');
              }
            } else {
              final create = await api.createSpecializationProofMinimal(trainerId, spec, certificateName: certName.isEmpty ? null : certName);
              if (create.statusCode != 200 && create.statusCode != 201) {
                throw Exception('Failed to add specialization');
              }
            }
          }
        }

        try { await context.read<AuthManager>().fetchTrainerProfile(trainerId); } catch (_) {}
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated')));
        Navigator.pop(context, true);
      } else {
        String msg = 'Failed (${resp.statusCode})';
        try {
          final b = jsonDecode(resp.body);
          if (b is Map && (b['message'] != null || b['error'] != null)) msg = (b['message'] ?? b['error']).toString();
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
            'You need to complete your KYC verification before you can edit your profile. Please complete your KYC process first.',
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
                // Navigate to KYC screen
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
    // Navigate to KYC wizard
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const TrainerKycWizard(),
      ),
    ).then((result) {
      // If KYC was completed successfully, reload the profile to check KYC status
      if (result == true) {
        _load(); // Reload the profile to update KYC status
      }
    });
  }

  // Removed old on-click add/remove; specializations now saved on bottom Save only.

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('View & Edit Profile'),
        backgroundColor:  AppColors.primary,

        elevation: 0,
  actions: const [],
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
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: Column(
                  children: [
                    GlassCard(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('Personal', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          _ro('Name', _name),
                          _ro('Mobile', _mobile),

                          // Editable current address fields
                          field('Current Address', _addressCtrl, readOnly: false),
                          const SizedBox(height: 8),
                          Row(children: [
                            Expanded(child: field('Current City', _cityCtrl, readOnly: false)),
                            const SizedBox(width: 8),
                            Expanded(child: field('Current State', _stateCtrl, readOnly: false)),
                          ]),
                          const SizedBox(height: 8),
                          field('Current Pincode', _pincodectrl, readOnly: false, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)]),

                          const SizedBox(height: 8),


                        ]),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // KYC Status Banner
                    if (!_isKycCompleted)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.only(bottom: 12),
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
                                    'Complete KYC to Edit Profile',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Your profile is read-only until KYC verification is completed. Complete your KYC to edit your profile.',
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

                    GlassCard(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('Contact & Emergency', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          field('Email', _emailCtrl, readOnly: !_isKycCompleted, validator: (v){
                            if (v==null || v.trim().isEmpty) return null; // optional
                            final ok = RegExp(r'^.+@.+\..+').hasMatch(v.trim());
                            return ok ? null : 'Invalid email';
                          }),
                          field('Emergency Name', _emgNameCtrl, readOnly: !_isKycCompleted),
                          field('Emergency Relation', _emgRelCtrl, readOnly: !_isKycCompleted),
                          field('Emergency Mobile', _emgMobileCtrl, readOnly: !_isKycCompleted, keyboardType: TextInputType.phone, inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)]),
                        ]),
                      ),
                    ),

                    const SizedBox(height: 12),
                    GlassCard(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('Professional', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          _experienceRow(disabled: !_isKycCompleted),
                          const SizedBox(height: 8),
                          _languagesRow(disabled: !_isKycCompleted),
                          const SizedBox(height: 8),
                          Row(children: [
                            Expanded(child: field('One session price', _oneSessionPriceCtrl, readOnly: !_isKycCompleted, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly])),
                            const SizedBox(width: 8),
                            Expanded(child: field('Monthly package price', _monthlyPriceCtrl, readOnly: !_isKycCompleted, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly])),
                          ]),
                        ]),
                      ),
                    ),

                    const SizedBox(height: 12),
                    GlassCard(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('Specializations', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          // Stacked rows like ProfessionalStep
                          ..._specRows.asMap().entries.map((e) => _stackedSpecRowEdit(e.value, e.key)).toList(),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: (_saving || !_isKycCompleted) ? null : () => setState(() { _specRows.add(_SpecRowEdit()); }),
                              icon: const Icon(Icons.add, color: Colors.white),
                              label: const Text('Add more', style: TextStyle(color: Colors.white)),
                            ),
                          ),
                        ]),
                      ),
                    ),

                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: (_saving || !_isKycCompleted) ? null : _save,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.white12, padding: const EdgeInsets.symmetric(vertical: 14)),
                        child: _saving
                            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Save', style: TextStyle(color: Colors.white, fontSize: 16)),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _ro(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(width: 130, child: Text(label, style: const TextStyle(color: Colors.white70))),
          const SizedBox(width: 8),
          Expanded(child: Text(value.isEmpty ? '—' : value, style: const TextStyle(color: Colors.white))),
        ],
      ),
    );
  }

  // ---- Specialization editor UI ----
  Widget _stackedSpecRowEdit(_SpecRowEdit r, int index) {
    final specOptions = _specializationOptions;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              dropdownColor: Colors.black87,
              style: const TextStyle(color: Colors.white),
              decoration: glassInput().copyWith(labelText: 'Specialisation'),
              value: r.specialization != null && specOptions.contains(r.specialization) ? r.specialization : null,
              items: specOptions.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: !_isKycCompleted ? null : (v) => setState(() => r.specialization = v),
              validator: (v) => (v==null || v.isEmpty) ? 'Choose' : null,
              disabledHint: r.specialization != null ? Text(r.specialization!, style: const TextStyle(color: Colors.white70)) : null,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            tooltip: _specRows.length == 1 ? 'Cannot remove last row' : 'Remove this row',
            onPressed: (!_isKycCompleted || _specRows.length == 1) ? null : () {
              setState(() {
                r.dispose();
                _specRows.removeAt(index);
              });
            },
          ),
        ]),
        const SizedBox(height: 10),
        field('Certificate Name (optional)', r.certificateNameCtrl, readOnly: !_isKycCompleted),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: InkWell(
            onTap: !_isKycCompleted ? null : () async {
              try {
                final XFile? picked = await _picker.pickImage(source: ImageSource.gallery);
                if (picked == null) return;
                setState(() => r.certificatePhotoPath = picked.path);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Image pick failed: $e')));
                }
              }
            },
            child: InputDecorator(
              decoration: glassInput().copyWith(labelText: 'Certificate Photo (optional)'),
              child: Row(children: [
                if (r.certificatePhotoPath == null && (r.existingImageUrl == null || r.existingImageUrl!.isEmpty)) ...[
                  const Icon(Icons.photo, color: Colors.white70),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('Tap to upload (optional)', style: TextStyle(color: Colors.white70))),
                ] else ...[
                  if (r.certificatePhotoPath != null) ...[
                    Container(
                      width: 64, height: 64,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        image: DecorationImage(image: FileImage(File(r.certificatePhotoPath!)), fit: BoxFit.cover),
                      ),
                    ),
                  ] else ...[
                    const Icon(Icons.image, color: Colors.white70),
                    const SizedBox(width: 8),
                    Expanded(child: Text('Existing photo selected', style: const TextStyle(color: Colors.white70))),
                  ],
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.white70, size: 18),
                    onPressed: !_isKycCompleted ? null : () => setState(() {
                      r.certificatePhotoPath = null;
                      r.existingImageUrl = null; // treat as removed; will recreate if new picked
                    }),
                    tooltip: 'Remove file',
                  )
                ]
              ]),
            ),
          ),
        )
      ]),
    );
  }

  List<String> get _specializationOptions => const [
    'Strength', 
    'HIIT', 
    'Yoga', 
    'Pilates', 'Rehab', 'Zumba',
    'Prenatal Yoga', 'Postnatal Yoga', 'Recreational Yoga', 'Nutrition', 'Counselors',
    'Cardio', 'CrossFit', 'Aerobics', 'Bodybuilding', 'Weight Loss', 'Weight Gain',
    'Yoga Therapy', 'Functional Training', 'Martial Arts', 'Dance Fitness', 'Sports Conditioning',
  ];

  Widget _imageChip(String label, String url) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(10)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.image, size: 16, color: Colors.white70),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: Colors.white70)),
      ]),
    );
  }

  Widget _experienceRow({bool disabled = false}) {
    final opts = kExperienceOptions;
    return Row(children: [
      const SizedBox(width: 130, child: Text('Experience', style: TextStyle(color: Colors.white70))),
      const SizedBox(width: 8),
      Expanded(
        child: DropdownButtonFormField<String>(
          value: opts.contains(_experience) ? _experience : null,
          items: opts.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: disabled ? null : (v) => setState(() => _experience = v),
          decoration: glassInput(),
          disabledHint: _experience != null ? Text(_experience!, style: const TextStyle(color: Colors.white70)) : null,
          style: const TextStyle(color: Colors.white),
        ),
      ),
    ]);
  }

  Widget _languagesRow({bool disabled = false}) {
    final preset = ['English','Hindi'];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Languages', style: TextStyle(color: Colors.white70)),
      const SizedBox(height: 6),
      Wrap(spacing: 8, runSpacing: 8, children: [
        ...preset.map((l) => FilterChip(
          label: Text(l, style: const TextStyle(color: Colors.white)),
          selected: _languages.contains(l),
          onSelected: disabled ? null : (v){ setState(() { if (v) _languages.add(l); else _languages.remove(l); }); },
          selectedColor: Colors.white24,
          backgroundColor: Colors.white12,
          shape: StadiumBorder(side: BorderSide(color: Colors.white.withOpacity(0.3))),
        )),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: field('Other language', _otherLangCtrl, readOnly: disabled)),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: disabled ? null : (){
            final t = _otherLangCtrl.text.trim();
            if (t.isNotEmpty) setState(() { _languages.add(t); _otherLangCtrl.clear(); });
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.white12),
          child: const Text('Add'),
        )
      ]),
    ]);
  }
}

class _SpecItem {
  final String? id;
  final String specialization;
  final String? certificateName;
  final String? imageUrl;
  _SpecItem({this.id, required this.specialization, this.certificateName, this.imageUrl});
}

class _SpecRowEdit {
  String? id; // existing proof id if any
  String? specialization;
  final TextEditingController certificateNameCtrl;
  String? certificatePhotoPath; // local picked path
  String? existingImageUrl; // existing remote image

  // Originals to detect changes
  final String? originalSpecialization;
  final String? originalCertificateName;

  _SpecRowEdit({
    this.id,
    this.specialization,
    String? certificateName,
    this.existingImageUrl,
  })  : originalSpecialization = specialization,
        originalCertificateName = certificateName,
        certificateNameCtrl = TextEditingController(text: certificateName ?? '');

  void dispose() {
    certificateNameCtrl.dispose();
  }
}
