// lib/screens/user/profile_fill_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../widgets/glass_card.dart';
import '../../config/app_colors.dart';
import '../home/home_screen.dart';
import '../../utils/role_storage.dart';
import '../../state/auth_manager.dart';
import 'package:provider/provider.dart';
import '../../utils/profile_storage.dart' show getMobile, getGender, getAge, StoredGender, getWeight, getHeight, getGoal, getPhysicalLevel;

class SubTitle extends StatelessWidget {
  final String text;
  const SubTitle(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8.0, bottom: 6),
    child: Text(text,
        style: const TextStyle(
            color: Colors.white70, fontWeight: FontWeight.w600)),
  );
}

Widget field(String label, TextEditingController controller,
    {bool readOnly = false,
      TextInputType? keyboardType,
      List<TextInputFormatter>? inputFormatters,
      int? maxLength,
      String? hint,
      String? Function(String?)? validator,
      VoidCallback? onTap,
      ValueChanged<String>? onChanged}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      const SizedBox(height: 6),
      TextFormField(
        controller: controller,
        readOnly: readOnly || onTap != null,
        onTap: onTap,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        maxLength: maxLength,
        style: const TextStyle(color: Colors.white),
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint ?? '',
          hintStyle: const TextStyle(color: Colors.white54),
          filled: true,
          fillColor: Colors.white12,
          counterText: '',
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
        ),
      ),
      const SizedBox(height: 8),
    ],
  );
}

class ProfileFillScreen extends StatefulWidget {
  const ProfileFillScreen({super.key});

  @override
  State<ProfileFillScreen> createState() => _ProfileFillScreenState();
}

class _ProfileFillScreenState extends State<ProfileFillScreen> {
  final _nameCtrl = TextEditingController();
  DateTime? _dob;
  final _emailCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _genderCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _pincodeCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _permAddrCtrl = TextEditingController();
  final _currAddrCtrl = TextEditingController();
  // Current address specific controllers (when not same as permanent)
  final _currPincodeCtrl = TextEditingController();
  final _currCityCtrl = TextEditingController();
  final _currStateCtrl = TextEditingController();
  final _healthCtrl = TextEditingController();
  final _emgName = TextEditingController();
  final _emgRelation = TextEditingController();
  final _emgPhone = TextEditingController();

  bool sameAsPermanent = true;
  String? _photoPath;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _pincodeCtrl.addListener(_onPincodeChanged);
  _currPincodeCtrl.addListener(_onCurrentPincodeChanged);
    _loadSavedBasics();
  }

  Future<void> _loadSavedBasics() async {
    final savedName = await getUserName();
    final savedMobile = await getMobile();
    final g = await getGender();
    final a = await getAge();

    String genderLabel;
    switch (g) {
      case StoredGender.male:
        genderLabel = 'Male';
        break;
      case StoredGender.female:
        genderLabel = 'Female';
        break;
      case StoredGender.other:
        genderLabel = 'Other';
        break;
      default:
        genderLabel = '';
    }

    if (!mounted) return;
    setState(() {
      if (savedName != null && savedName.isNotEmpty) {
        _nameCtrl.text = savedName;
      }
      if (savedMobile != null && savedMobile.isNotEmpty) {
        _mobileCtrl.text = savedMobile;
      }
      _genderCtrl.text = genderLabel;
      _ageCtrl.text = a != null ? a.toString() : '';
    });
  }

  @override
  void dispose() {
    _pincodeCtrl.removeListener(_onPincodeChanged);
  _currPincodeCtrl.removeListener(_onCurrentPincodeChanged);
  _nameCtrl.dispose();
  _mobileCtrl.dispose();
  _genderCtrl.dispose();
  _ageCtrl.dispose();
    _emailCtrl.dispose();
    _pincodeCtrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _permAddrCtrl.dispose();
    _currAddrCtrl.dispose();
  _currPincodeCtrl.dispose();
  _currCityCtrl.dispose();
  _currStateCtrl.dispose();
    _healthCtrl.dispose();
    _emgName.dispose();
    _emgRelation.dispose();
    _emgPhone.dispose();
    super.dispose();
  }

  void _onPincodeChanged() {
    final v = _pincodeCtrl.text.trim();
    if (v.length == 6 && RegExp(r'^\d{6}$').hasMatch(v)) {
      () async {
        try {
          final auth = context.read<AuthManager>();
          final d = await auth.getCityState(v);
          if (!mounted) return;
          setState(() {
            _cityCtrl.text = (d != null && (d['city'] ?? '').isNotEmpty) ? d['city']! : '—';
            _stateCtrl.text = (d != null && (d['state'] ?? '').isNotEmpty) ? d['state']! : '—';
            if (sameAsPermanent) {
              _currAddrCtrl.text = _permAddrCtrl.text;
              _currPincodeCtrl.text = _pincodeCtrl.text;
              _currCityCtrl.text = _cityCtrl.text;
              _currStateCtrl.text = _stateCtrl.text;
            }
          });
        } catch (_) {
          if (!mounted) return;
          setState(() {
            _cityCtrl.text = '—';
            _stateCtrl.text = '—';
            if (sameAsPermanent) {
              _currCityCtrl.text = '—';
              _currStateCtrl.text = '—';
              _currPincodeCtrl.text = _pincodeCtrl.text;
            }
          });
        }
      }();
    } else {
      setState(() {
        _cityCtrl.clear();
        _stateCtrl.clear();
        if (sameAsPermanent) {
          _currCityCtrl.clear();
          _currStateCtrl.clear();
          _currPincodeCtrl.text = _pincodeCtrl.text;
        }
      });
    }
  }

  void _onCurrentPincodeChanged() {
    final v = _currPincodeCtrl.text.trim();
    if (v.length == 6 && RegExp(r'^\d{6}$').hasMatch(v)) {
      () async {
        try {
          final auth = context.read<AuthManager>();
          final d = await auth.getCityState(v);
          if (!mounted) return;
          setState(() {
            _currCityCtrl.text = (d != null && (d['city'] ?? '').isNotEmpty) ? d['city']! : '—';
            _currStateCtrl.text = (d != null && (d['state'] ?? '').isNotEmpty) ? d['state']! : '—';
          });
        } catch (_) {
          if (!mounted) return;
          setState(() {
            _currCityCtrl.text = '—';
            _currStateCtrl.text = '—';
          });
        }
      }();
    } else {
      setState(() {
        _currCityCtrl.clear();
        _currStateCtrl.clear();
      });
    }
  }

  Future<void> _pickPhoto() async {
    try {
      final x = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (x != null) {
        setState(() => _photoPath = x.path);
      }
    } catch (_) {
      _show('Unable to pick image');
    }
  }

  // removed mock pincode lookup (API is used instead)

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty) {
      _show('Enter name');
      return;
    }
  if (sameAsPermanent) {
    _currAddrCtrl.text = _permAddrCtrl.text;
    _currPincodeCtrl.text = _pincodeCtrl.text;
    _currCityCtrl.text = _cityCtrl.text;
    _currStateCtrl.text = _stateCtrl.text;
  }

    // Save name to storage (if changed)
    await saveUserName(_nameCtrl.text.trim());

    // Build payload and send to backend
    final fields = <String, dynamic>{};
  // basics
    fields['fullName'] = _nameCtrl.text.trim();
  fields['type'] = 'user';
    if (_emailCtrl.text.trim().isNotEmpty) fields['email'] = _emailCtrl.text.trim();
    final mobile = await getMobile();
    if (mobile != null && mobile.isNotEmpty) fields['mobileNumber'] = mobile;
    final g = await getGender();
    final genderStr = g == StoredGender.male
        ? 'Male'
        : g == StoredGender.female
            ? 'Female'
            : g == StoredGender.other
                ? 'Other'
                : null;
    if (genderStr != null) fields['gender'] = genderStr;
    final a = await getAge();
    if (a != null) fields['age'] = a;
    // measurements and goals
    final w = await getWeight();
    if (w != null) fields['weight'] = w;
    final h = await getHeight();
    if (h != null && h.isNotEmpty) fields['height'] = h;
    final goal = await getGoal();
    if (goal != null && goal.isNotEmpty) fields['goal'] = goal;
    final phys = await getPhysicalLevel();
    if (phys != null && phys.isNotEmpty) fields['physicalLevel'] = phys;
    // address
    if (_permAddrCtrl.text.trim().isNotEmpty) fields['address'] = _permAddrCtrl.text.trim();
    final permCityVal = _cityCtrl.text.trim();
    final permStateVal = _stateCtrl.text.trim();
    if (permCityVal.isNotEmpty && permCityVal != '—') fields['city'] = permCityVal;
    if (permStateVal.isNotEmpty && permStateVal != '—') fields['state'] = permStateVal;
    if (_pincodeCtrl.text.trim().isNotEmpty) fields['pincode'] = _pincodeCtrl.text.trim();
    fields['isAddressSame'] = sameAsPermanent;
    if (sameAsPermanent) {
      if (_permAddrCtrl.text.trim().isNotEmpty) fields['currentAddress'] = _permAddrCtrl.text.trim();
      if (permCityVal.isNotEmpty && permCityVal != '—') fields['currentCity'] = permCityVal;
      if (permStateVal.isNotEmpty && permStateVal != '—') fields['currentState'] = permStateVal;
      if (_pincodeCtrl.text.trim().isNotEmpty) fields['currentPincode'] = _pincodeCtrl.text.trim();
    } else {
      final currCityVal = _currCityCtrl.text.trim();
      final currStateVal = _currStateCtrl.text.trim();
      if (_currAddrCtrl.text.trim().isNotEmpty) fields['currentAddress'] = _currAddrCtrl.text.trim();
      if (currCityVal.isNotEmpty && currCityVal != '—') fields['currentCity'] = currCityVal;
      if (currStateVal.isNotEmpty && currStateVal != '—') fields['currentState'] = currStateVal;
      if (_currPincodeCtrl.text.trim().isNotEmpty) fields['currentPincode'] = _currPincodeCtrl.text.trim();
    }
    // emergency and health
    if (_emgName.text.trim().isNotEmpty) fields['emergencyPersonName'] = _emgName.text.trim();
    if (_emgPhone.text.trim().isNotEmpty) fields['emergencyPersonMobile'] = _emgPhone.text.trim();
    if (_emgRelation.text.trim().isNotEmpty) fields['emergencyPersonRelation'] = _emgRelation.text.trim();
    if (_healthCtrl.text.trim().isNotEmpty) fields['healthIssue'] = _healthCtrl.text.trim();

    // Flags
    fields['isActive'] = true;
    fields['isProfileCompleted'] = true;

    try {
      final auth = context.read<AuthManager>();
      var resp = await auth.updateUserProfile(fields, image: _photoPath != null ? File(_photoPath!) : null);
      if (resp['success'] != true) {
        final code = (resp['statusCode'] ?? 0) as int;
        if (code >= 500 || code == 0) {
          final slim = Map<String, dynamic>.from(fields)
            ..remove('type')
            ..remove('isActive')
            ..remove('isProfileCompleted');
          resp = await auth.updateUserProfile(slim);
          if (resp['success'] != true) {
            // Final minimal fallback: only a safe subset
            final minimal = <String, dynamic>{
              'fullName': _nameCtrl.text.trim(),
              if (_emailCtrl.text.trim().isNotEmpty) 'email': _emailCtrl.text.trim(),
              if (mobile != null && mobile.isNotEmpty) 'mobileNumber': mobile,
              if (genderStr != null) 'gender': genderStr,
              if (a != null) 'age': a,
            };
            resp = await auth.updateUserProfile(minimal);
            if (resp['success'] != true && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Could not save profile (server ${resp['statusCode']}). You can continue and update later.')),
              );
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Network error while saving profile.')),
        );
      }
    }

    // Mark profile complete locally
    await saveProfileComplete(true);

    // Navigate to Home (clear stack)
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
          (r) => false,
    );
  }

  void _show(String t) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
            gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.secondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight)),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 18),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back, color: Colors.white)),
                    const SizedBox(width: 6),
                    const Expanded(
                        child: Text("Fill Your Profile",
                            style:
                            TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold))),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: SingleChildScrollView(
                    child: GlassCard(
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Center(
                            child: InkWell(
                              onTap: _pickPhoto,
                              child: CircleAvatar(
                                radius: 36,
                                backgroundColor: Colors.white12,
                                backgroundImage: _photoPath != null ? FileImage(File(_photoPath!)) : null,
                                child: _photoPath == null ? const Icon(Icons.camera_alt, color: Colors.white70) : null,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Name — prefilled and read-only
                          field("Full Name", _nameCtrl, hint: "Your full name", readOnly: true),
                          // Mobile — prefilled and read-only
                          field("Mobile", _mobileCtrl, hint: "+91xxxxxxxxxx", readOnly: true),
                          // Gender — prefilled and read-only
                          field("Gender", _genderCtrl, hint: "Gender", readOnly: true),
                          // Age — prefilled and read-only
                          field("Age", _ageCtrl, hint: "Age in years", readOnly: true),
                          const SizedBox(height: 6),

                          SubTitle("Date of birth"),
                          GestureDetector(
                            onTap: () async {
                              final p = await showDatePicker(
                                  context: context,
                                  initialDate: DateTime(1995, 1, 1),
                                  firstDate: DateTime(1900),
                                  lastDate: DateTime.now());
                              if (p != null) setState(() => _dob = p);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                              decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(8)),
                              child: Row(children: [
                                Expanded(
                                    child: Text(_dob == null ? "Select date of birth (optional)" : DateFormat.yMMMd().format(_dob!),
                                        style: TextStyle(color: _dob == null ? Colors.white54 : Colors.white))),
                                const Icon(Icons.calendar_today, color: Colors.white54)
                              ]),
                            ),
                          ),
                          const SizedBox(height: 12),

                          field("Email", _emailCtrl, keyboardType: TextInputType.emailAddress, hint: "example@you.com"),
                          const SizedBox(height: 6),

                          const SubTitle("Address"),
                          field("Pincode", _pincodeCtrl,
                              keyboardType: TextInputType.number,
                              maxLength: 6,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                              hint: "6-digit pin"),
                          field("City", _cityCtrl, readOnly: true),
                          field("State", _stateCtrl, readOnly: true),

                          field("Permanent Address", _permAddrCtrl, hint: "Street / locality / landmark"),
                          SwitchListTile(
                            value: sameAsPermanent,
                            onChanged: (v) {
                              setState(() {
                                sameAsPermanent = v;
                                if (v) {
                                  _currAddrCtrl.text = _permAddrCtrl.text;
                                  _currPincodeCtrl.text = _pincodeCtrl.text;
                                  _currCityCtrl.text = _cityCtrl.text;
                                  _currStateCtrl.text = _stateCtrl.text;
                                } else {
                                  _currAddrCtrl.clear();
                                  _currPincodeCtrl.clear();
                                  _currCityCtrl.clear();
                                  _currStateCtrl.clear();
                                }
                              });
                            },
                            title: const Text("Same as permanent address", style: TextStyle(color: Colors.white)),
                            activeColor: Colors.white,
                            contentPadding: EdgeInsets.zero,
                          ),
                          if (!sameAsPermanent) ...[
                            field("Current Address", _currAddrCtrl, hint: "Street / locality"),
                            field("Current Pincode", _currPincodeCtrl,
                                keyboardType: TextInputType.number,
                                maxLength: 6,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                                hint: "6-digit pin"),
                            field("Current City", _currCityCtrl, readOnly: true),
                            field("Current State", _currStateCtrl, readOnly: true),
                          ],

                          const SizedBox(height: 6),
                          field("Any health issues / allergies", _healthCtrl, maxLength: 200, hint: "e.g. asthma, diabetes (optional)"),
                          const SizedBox(height: 8),

                          const SubTitle("Emergency Contact"),
                          field("Name", _emgName, hint: "Contact name"),
                          field("Relation", _emgRelation, hint: "e.g. spouse, parent"),
                          field("Phone", _emgPhone, keyboardType: TextInputType.phone, hint: "+91xxxxxxxxxx", inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)]),

                          const SizedBox(height: 12),
                        ]),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                      child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: BorderSide(color: Colors.white.withOpacity(0.25)), padding: const EdgeInsets.symmetric(vertical: 14)),
                          child: const Text("Back"))),
                  const SizedBox(width: 12),
                  Expanded(child: ElevatedButton(onPressed: _submit, style: ElevatedButton.styleFrom(backgroundColor: Colors.white12, padding: const EdgeInsets.symmetric(vertical: 14)), child: const Text("Start", style: TextStyle(color: Colors.white)))),
                ]),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
