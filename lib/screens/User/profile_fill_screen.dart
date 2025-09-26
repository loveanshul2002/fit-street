// lib/screens/user/profile_fill_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../widgets/glass_card.dart';
import '../../config/app_colors.dart';
import '../home/home_screen.dart';
import '../../utils/role_storage.dart';

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
  final _pincodeCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _permAddrCtrl = TextEditingController();
  final _currAddrCtrl = TextEditingController();
  final _healthCtrl = TextEditingController();
  final _emgName = TextEditingController();
  final _emgRelation = TextEditingController();
  final _emgPhone = TextEditingController();

  bool sameAsPermanent = true;
  String? _photoPath;

  @override
  void initState() {
    super.initState();
    _pincodeCtrl.addListener(_onPincodeChanged);
    _loadSavedName();
  }

  Future<void> _loadSavedName() async {
    final saved = await getUserName();
    if (saved != null && saved.isNotEmpty) {
      setState(() {
        _nameCtrl.text = saved;
      });
    }
  }

  @override
  void dispose() {
    _pincodeCtrl.removeListener(_onPincodeChanged);
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _pincodeCtrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _permAddrCtrl.dispose();
    _currAddrCtrl.dispose();
    _healthCtrl.dispose();
    _emgName.dispose();
    _emgRelation.dispose();
    _emgPhone.dispose();
    super.dispose();
  }

  void _onPincodeChanged() {
    final v = _pincodeCtrl.text.trim();
    if (v.length == 6 && RegExp(r'^\d{6}$').hasMatch(v)) {
      final d = _mockPincodeLookup(v);
      setState(() {
        _cityCtrl.text = d['city']!;
        _stateCtrl.text = d['state']!;
      });
    } else {
      setState(() {
        _cityCtrl.clear();
        _stateCtrl.clear();
      });
    }
  }

  Map<String, String> _mockPincodeLookup(String pin) {
    switch (pin) {
      case "110001":
        return {"city": "New Delhi", "state": "Delhi"};
      case "400001":
        return {"city": "Mumbai", "state": "Maharashtra"};
      case "560001":
        return {"city": "Bengaluru", "state": "Karnataka"};
      default:
        return {"city": "—", "state": "—"};
    }
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty) {
      _show('Enter name');
      return;
    }
    if (sameAsPermanent) _currAddrCtrl.text = _permAddrCtrl.text;

    // Save name to storage (if changed)
    await saveUserName(_nameCtrl.text.trim());

    // Mark profile complete
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
                              onTap: () {
                                // demo: just toggle selected photo
                                setState(() {
                                  _photoPath = _photoPath == null ? "demo_profile" : null;
                                });
                                _show("Photo (demo) selected.");
                              },
                              child: CircleAvatar(
                                  radius: 36,
                                  backgroundColor: Colors.white12,
                                  child: _photoPath == null ? const Icon(Icons.camera_alt, color: Colors.white70) : null),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Name — prefilled and read-only
                          field("Full Name", _nameCtrl, hint: "Your full name", readOnly: true),
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
                                if (v) _currAddrCtrl.text = _permAddrCtrl.text;
                              });
                            },
                            title: const Text("Same as permanent address", style: TextStyle(color: Colors.white)),
                            activeColor: Colors.white,
                            contentPadding: EdgeInsets.zero,
                          ),
                          if (!sameAsPermanent) field("Current Address", _currAddrCtrl, hint: "Street / locality"),

                          const SizedBox(height: 6),
                          field("Any health issues / allergies", _healthCtrl, maxLength: 200, hint: "e.g. asthma, diabetes (optional)"),
                          const SizedBox(height: 8),

                          const SubTitle("Emergency Contact"),
                          field("Name", _emgName, hint: "Contact name"),
                          field("Relation", _emgRelation, hint: "e.g. spouse, parent"),
                          field("Phone", _emgPhone, keyboardType: TextInputType.phone, hint: "+91xxxxxxxxxx", inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(15)]),

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
