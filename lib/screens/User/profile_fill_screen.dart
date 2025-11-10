// lib/screens/user/profile_fill_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
// removed intl date picker usage
import 'dart:ui' show ImageFilter;
import '../trainer/kyc/utils/input_formatters.dart' show DateSlashFormatter;
import '../home/home_screen.dart';
import '../../utils/role_storage.dart';
import '../../state/auth_manager.dart';
import 'package:provider/provider.dart';
import '../../utils/profile_storage.dart' show getMobile, getGender, getAge, StoredGender, getWeight, getHeight, getGoal, getPhysicalLevel, saveWeight, saveHeight, saveGoal, savePhysicalLevel;

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
  final bool editableBasics; // allow editing of name/mobile/gender/age
  const ProfileFillScreen({super.key, this.editableBasics = false});

  @override
  State<ProfileFillScreen> createState() => _ProfileFillScreenState();
}

class _ProfileFillScreenState extends State<ProfileFillScreen> {
  final _nameCtrl = TextEditingController();
  // DOB as text in DD/MM/YYYY
  final _dobTextCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _genderCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _goalCtrl = TextEditingController();
  final _activityCtrl = TextEditingController();
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
    // Also fetch the full profile from server and prefill fields
    // Doing this after first frame to ensure context is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _prefillFromServer();
    });
  }

  Future<void> _prefillFromServer() async {
    try {
      final auth = context.read<AuthManager>();
      final resp = await auth.getUserProfile();
      if (resp['success'] == true) {
        final body = resp['body'];
        dynamic data;
        if (body is Map) {
          data = body['data'] ?? body;
        } else {
          data = body;
        }
        if (data is Map) {
          final name = (data['fullName'] ?? data['name'])?.toString();
          final email = data['email']?.toString();
          final mobile = (data['mobileNumber'] ?? data['mobile'] ?? data['phone'])?.toString();
          final gender = data['gender']?.toString();
          final ageVal = data['age'];
          final address = data['address']?.toString();
          final city = data['city']?.toString();
          final state = data['state']?.toString();
          final pincode = (data['pincode'] ?? data['pin'])?.toString();
          final same = data['isAddressSame'];
          final currAddr = data['currentAddress']?.toString();
          final currCity = data['currentCity']?.toString();
          final currState = data['currentState']?.toString();
          final currPin = (data['currentPincode'] ?? data['currentPin'])?.toString();
          final health = data['healthIssue']?.toString();
          final emgName = data['emergencyPersonName']?.toString();
          final emgRel = data['emergencyPersonRelation']?.toString();
          final emgPhone = (data['emergencyPersonMobile'] ?? data['emergencyMobile'])?.toString();
          final dobRaw = (data['dob'] ?? data['dateOfBirth'])?.toString();
          final weightVal = data['weight'];
          final heightVal = data['height']?.toString();
          final goalVal = data['goal']?.toString();
          final physVal = data['physicalLevel']?.toString();

          // Normalize DOB into DD/MM/YYYY if possible
          String? dobText;
          if (dobRaw != null && dobRaw.isNotEmpty) {
            // Common formats: 1990-12-31, 1990/12/31, 31/12/1990, 31-12-1990, ISO with time
            final isoDate = RegExp(r'^(\d{4})[-/](\d{2})[-/](\d{2})');
            final ddmmyyyy = RegExp(r'^(\d{2})[-/](\d{2})[-/](\d{4})');
            if (isoDate.hasMatch(dobRaw)) {
              final m = isoDate.firstMatch(dobRaw)!;
              final y = m.group(1)!;
              final mm = m.group(2)!;
              final dd = m.group(3)!;
              dobText = '$dd/$mm/$y';
            } else if (ddmmyyyy.hasMatch(dobRaw)) {
              final m = ddmmyyyy.firstMatch(dobRaw)!;
              final dd = m.group(1)!;
              final mm = m.group(2)!;
              final y = m.group(3)!;
              dobText = '$dd/$mm/$y';
            }
          }

          if (!mounted) return;
          setState(() {
            if (name != null && name.isNotEmpty) _nameCtrl.text = name;
            if (email != null && email.isNotEmpty) _emailCtrl.text = email;
            if (mobile != null && mobile.isNotEmpty) _mobileCtrl.text = mobile;
            if (gender != null && gender.isNotEmpty) _genderCtrl.text = gender;
            if (ageVal != null) _ageCtrl.text = ageVal.toString();
            if (dobText != null && dobText.isNotEmpty) _dobTextCtrl.text = dobText;

            if (address != null && address.isNotEmpty) _permAddrCtrl.text = address;
            if (city != null && city.isNotEmpty) _cityCtrl.text = city;
            if (state != null && state.isNotEmpty) _stateCtrl.text = state;
            if (pincode != null && pincode.isNotEmpty) _pincodeCtrl.text = pincode;

            // Address sameness
            if (same is bool) {
              sameAsPermanent = same;
            } else if (same is String) {
              sameAsPermanent = same.toLowerCase() == 'true' || same == '1';
            }

            if (sameAsPermanent) {
              _currAddrCtrl.text = _permAddrCtrl.text;
              _currCityCtrl.text = _cityCtrl.text;
              _currStateCtrl.text = _stateCtrl.text;
              _currPincodeCtrl.text = _pincodeCtrl.text;
            } else {
              if (currAddr != null && currAddr.isNotEmpty) _currAddrCtrl.text = currAddr;
              if (currCity != null && currCity.isNotEmpty) _currCityCtrl.text = currCity;
              if (currState != null && currState.isNotEmpty) _currStateCtrl.text = currState;
              if (currPin != null && currPin.isNotEmpty) _currPincodeCtrl.text = currPin;
            }

            if (health != null && health.isNotEmpty) _healthCtrl.text = health;
            if (emgName != null && emgName.isNotEmpty) _emgName.text = emgName;
            if (emgRel != null && emgRel.isNotEmpty) _emgRelation.text = emgRel;
            if (emgPhone != null && emgPhone.isNotEmpty) _emgPhone.text = emgPhone;
            if (weightVal != null) _weightCtrl.text = weightVal.toString();
            if (heightVal != null && heightVal.isNotEmpty) _heightCtrl.text = heightVal;
            if (goalVal != null && goalVal.isNotEmpty) _goalCtrl.text = goalVal;
            if (physVal != null && physVal.isNotEmpty) _activityCtrl.text = physVal;
          });
        }
      }
    } catch (_) {
      // ignore prefill errors; form remains editable
    }
  }

  Future<void> _loadSavedBasics() async {
    final savedName = await getUserName();
    final savedMobile = await getMobile();
    final g = await getGender();
    final a = await getAge();
  final w = await getWeight();
  final h = await getHeight();
  final goal = await getGoal();
  final phys = await getPhysicalLevel();
    // Email, if cached locally (greeting freshness)
    try {
      final email = await getUserEmail();
      if (email != null && email.isNotEmpty) {
        _emailCtrl.text = email;
      }
    } catch (_) {}

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
  if (w != null) _weightCtrl.text = w.toString();
  if (h != null && h.isNotEmpty) _heightCtrl.text = h;
  if (goal != null && goal.isNotEmpty) _goalCtrl.text = goal;
  if (phys != null && phys.isNotEmpty) _activityCtrl.text = phys;
    });
  }

  @override
  void dispose() {
    _pincodeCtrl.removeListener(_onPincodeChanged);
  _currPincodeCtrl.removeListener(_onCurrentPincodeChanged);
  _dobTextCtrl.dispose();
  _nameCtrl.dispose();
  _mobileCtrl.dispose();
  _genderCtrl.dispose();
  _ageCtrl.dispose();
  _weightCtrl.dispose();
  _heightCtrl.dispose();
  _goalCtrl.dispose();
  _activityCtrl.dispose();
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
    // Persist newly entered extended fields locally if user typed them (basic screens may not have saved yet)
    try {
      if (_weightCtrl.text.trim().isNotEmpty) {
        final parsed = int.tryParse(_weightCtrl.text.trim());
        if (parsed != null) await saveWeight(parsed);
      }
      if (_heightCtrl.text.trim().isNotEmpty) {
        await saveHeight(_heightCtrl.text.trim());
      }
      if (_goalCtrl.text.trim().isNotEmpty) {
        await saveGoal(_goalCtrl.text.trim());
      }
      if (_activityCtrl.text.trim().isNotEmpty) {
        await savePhysicalLevel(_activityCtrl.text.trim());
      }
    } catch (_) {}

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
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/image/bg.png'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(Colors.black54, BlendMode.darken),
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 1, sigmaY: 1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withOpacity(0.15),
                            Colors.white.withOpacity(0.06),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.28), width: 0.75),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, 10)),
                        ],
                      ),
                      child: Stack(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(height: 6),
                              const Text(
                                'Fill Your Profile',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              const SizedBox(height: 12),
                              Expanded(
                                child: SingleChildScrollView(
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

                    // Name — editable if requested
                    field('Full Name', _nameCtrl, hint: 'Your full name', readOnly: !widget.editableBasics),
                    // Mobile — editable if requested
                    field('Mobile', _mobileCtrl, hint: '+91xxxxxxxxxx', readOnly: !widget.editableBasics,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)]),
                    // Gender — editable if requested
                    field('Gender', _genderCtrl, hint: 'Gender', readOnly: !widget.editableBasics),
                    // Age — editable if requested
                    field('Age', _ageCtrl, hint: 'Age in years', readOnly: !widget.editableBasics,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)]),
                    // Weight (kg)
                    field('Weight (kg)', _weightCtrl, hint: 'e.g. 72', keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)]),
                    // Height (cm or ft/in)
                    field('Height', _heightCtrl, hint: 'e.g. 178 cm'),
                    // Goal (summary, e.g. fat loss)
                    field('Goal', _goalCtrl, hint: 'e.g. fat loss / muscle gain'),
                    // Activity Level
                    field('Activity Level', _activityCtrl, hint: 'e.g. sedentary / moderate / active'),
                                      const SizedBox(height: 6),

                            // ...existing code...
field(
  'Date of Birth (DD/MM/YYYY)',
  _dobTextCtrl,
  keyboardType: TextInputType.number,
  inputFormatters: [
    FilteringTextInputFormatter.digitsOnly,
    LengthLimitingTextInputFormatter(10),
    DateSlashFormatter(),
  ],
  validator: (v) {
    final txt = (v ?? '').trim();
    if (txt.isEmpty) return 'Enter DOB';
    return RegExp(r'^\d{2}/\d{2}/\d{4}$').hasMatch(txt) ? null : 'Use DD/MM/YYYY';
  },
),
const SizedBox(height: 12),

field('Email', _emailCtrl, keyboardType: TextInputType.emailAddress, hint: 'example@you.com'),
const SizedBox(height: 6),

SubTitle('Address'),
field('Pincode', _pincodeCtrl,
    keyboardType: TextInputType.number,
    maxLength: 6,
    inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
    hint: '6-digit pin'),
field('City', _cityCtrl, readOnly: true),
// ...existing code...
                                      field('State', _stateCtrl, readOnly: true),

                                      field('Permanent Address', _permAddrCtrl, hint: 'Street / locality / landmark'),
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
                                        title: const Text('Same as permanent address', style: TextStyle(color: Colors.white)),
                                        activeColor: Colors.white,
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                      if (!sameAsPermanent) ...[
                                        field('Current Address', _currAddrCtrl, hint: 'Street / locality'),
                                        field('Current Pincode', _currPincodeCtrl,
                                            keyboardType: TextInputType.number,
                                            maxLength: 6,
                                            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                                            hint: '6-digit pin'),
                                        field('Current City', _currCityCtrl, readOnly: true),
                                        field('Current State', _currStateCtrl, readOnly: true),
                                      ],

                                      const SizedBox(height: 6),
                                      field('Any health issues / allergies', _healthCtrl, maxLength: 200, hint: 'e.g. asthma, diabetes (optional)'),
                                      const SizedBox(height: 8),

                                      const SubTitle('Emergency Contact'),
                                      field('Name', _emgName, hint: 'Contact name'),
                                      field('Relation', _emgRelation, hint: 'e.g. spouse, parent'),
                                      field('Phone', _emgPhone, keyboardType: TextInputType.phone, inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)]),

                                      const SizedBox(height: 12),
                                    ]),
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _submit,
                                  style: ElevatedButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    elevation: 0,
                                  ),
                                  child: SizedBox(
                                    height: 64,
                                    child: Center(
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(28),
                                        child: BackdropFilter(
                                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [
                                                  Colors.white.withOpacity(0.16),
                                                  Colors.white.withOpacity(0.06),
                                                ],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              ),
                                              borderRadius: BorderRadius.circular(28),
                                              border: Border.all(color: Colors.white.withOpacity(0.28), width: 0.75),
                                            ),
                                            child: Text(
                                              widget.editableBasics ? 'Save' : 'Start',
                                              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          // Glass back button (top-left)
                          Positioned(
                            top: 8,
                            left: 8,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
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
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: Colors.white.withOpacity(0.28), width: 0.75),
                                  ),
                                  child: Material(
                                    type: MaterialType.transparency,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(14),
                                      onTap: () => Navigator.pop(context),
                                      child: const SizedBox(
                                        height: 40,
                                        width: 40,
                                        child: Icon(Icons.arrow_back, color: Colors.white, size: 20),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
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
