// lib/screens/trainer/kyc/steps/identity_step.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../../../widgets/glass_card.dart';
import '../utils/ui_helpers.dart';
import '../utils/input_formatters.dart';

class IdentityStep extends StatelessWidget {
  final GlobalKey<FormState> formKey;

  final String? language;
  final ValueChanged<String?> onLanguageChanged;

  final TextEditingController fullName;
  final TextEditingController dob;
  final ValueNotifier<String?> gender;

  final TextEditingController mobile;
  final TextEditingController email;

  final TextEditingController pincode; // permanent pincode
  final TextEditingController city; // permanent city
  final TextEditingController stateCtrl; // permanent state

  // NEW: controllers for current address lookup
  final TextEditingController currentPincode;
  final TextEditingController currentCity;
  final TextEditingController currentState;

  final bool sameAsPermanent;
  final ValueChanged<bool> onSameAsPermanentChanged;
  final TextEditingController addrPermanent;
  final TextEditingController addrCurrent;

  final TextEditingController emgName;
  final TextEditingController emgRelation;
  final TextEditingController emgMobile;

  final TextEditingController pan;
  final TextEditingController aadhaar;

  // image props (passed from parent wizard)
  final String? panPhotoPath;
  final String? aadhaarPhotofrontPath;
  final String? aadhaarPhotobackPath;
  final String? selfiePath;

  // callbacks to set / clear paths in parent
  final void Function(String) pickPanPhoto;
  final void Function(String) pickAadhaarPhotofront;
  final void Function(String) pickAadhaarPhotoback;
  final void Function(String) pickSelfie;

  final void Function(String) onPincodeChanged;

  // NEW: callback for current pincode change
  final void Function(String) onCurrentPincodeChanged;

  // NEW: readOnly flags for fields that should not be editable
  final bool readOnlyFullName;
  final bool readOnlyMobile;

  const IdentityStep({
    super.key,
    required this.formKey,
    required this.language,
    required this.onLanguageChanged,
    required this.fullName,
    required this.dob,
    required this.gender,
    required this.mobile,
    required this.email,
    required this.pincode,
    required this.city,
    required this.stateCtrl,
    required this.currentPincode,
    required this.currentCity,
    required this.currentState,
    required this.sameAsPermanent,
    required this.onSameAsPermanentChanged,
    required this.addrPermanent,
    required this.addrCurrent,
    required this.emgName,
    required this.emgRelation,
    required this.emgMobile,
    required this.pan,
    required this.aadhaar,
    required this.pickPanPhoto,
    required this.pickAadhaarPhotofront,
    required this.pickAadhaarPhotoback,
    required this.pickSelfie,
    required this.onPincodeChanged,
    required this.onCurrentPincodeChanged,
    this.readOnlyFullName = false,
    this.readOnlyMobile = false,
    this.panPhotoPath,
    this.aadhaarPhotofrontPath,
    this.aadhaarPhotobackPath,
    this.selfiePath,
  });

  static bool validateAge(TextEditingController dobCtrl, void Function(String) toast) {
    final txt = dobCtrl.text.trim();
    final parts = txt.split("/");
    if (parts.length != 3) { toast("Enter DOB as DD/MM/YYYY"); return false; }
    final d = int.tryParse(parts[0]), m = int.tryParse(parts[1]), y = int.tryParse(parts[2]);
    if (d == null || m == null || y == null) { toast("Enter a valid DOB"); return false; }
    final now = DateTime.now();
    final dobDate = DateTime(y, m, d);
    final ageYears = now.year - dobDate.year - ((now.month < m || (now.month == m && now.day < d)) ? 1 : 0);
    if (ageYears < 18) { toast("You must be at least 18 years old."); return false; }
    return true;
  }

  static bool validateIDs(TextEditingController pan, TextEditingController aadhaar, void Function(String) toast) {
    if (!RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$').hasMatch(pan.text.trim())) { toast("Invalid PAN format (AAAAA9999A)"); return false; }
    final aad = aadhaar.text.replaceAll(" ", "");
    if (!RegExp(r'^\d{12}$').hasMatch(aad)) { toast("Aadhaar must be 12 digits"); return false; }
    return true;
  }

  // helper: pick from gallery and save to temp, then call parent callback with path
  Future<void> _pickImageAndSend(BuildContext ctx, Future<void> Function(String) sendCallback) async {
    try {
      final picker = ImagePicker();
      final XFile? picked = await picker.pickImage(source: ImageSource.gallery);
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      final tmpDir = await getTemporaryDirectory();
      final filename = 'img_${DateTime.now().millisecondsSinceEpoch}${p.extension(picked.path)}';
      final file = File('${tmpDir.path}/$filename');
      await file.writeAsBytes(bytes);
      await sendCallback.call(file.path);
    } catch (e, st) {
      debugPrint('IdentityStep._pickImageAndSend error: $e\n$st');
      // don't rethrow; just silently fail
    }
  }

  Widget _imageRow(String label, String? path, VoidCallback onPick, VoidCallback onRemove, {bool required = false}) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: InkWell(
        onTap: onPick,
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: required ? '$label *' : label,
            filled: true,
            fillColor: Colors.white10,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.white24)),
          ),
          child: Row(
            children: [
              if (path == null || path.isEmpty) ...[
                const Icon(Icons.photo, color: Colors.white70),
                const SizedBox(width: 10),
                Expanded(child: Text("Tap to choose photo", style: const TextStyle(color: Colors.white70))),
              ] else ...[
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    image: DecorationImage(image: FileImage(File(path)), fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(p.basename(path), style: const TextStyle(color: Colors.white70), overflow: TextOverflow.ellipsis)),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.white70),
                  onPressed: onRemove,
                )
              ]
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: GlassCard(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Section("1. Identity & Contact"),
                const SizedBox(height: 10),

                // Full Name - now supports readOnly via constructor flag
                field("Full Name", fullName, validator: req, readOnly: readOnlyFullName),

                field(
                  "Date of Birth (DD/MM/YYYY)",
                  dob,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10), // dd/mm/yyyy → max 10
                    DateSlashFormatter(), // 👈 auto adds slashes
                  ],
                  validator: (v) {
                    if (!notEmpty(v)) return "Enter DOB";
                    return RegExp(r'^\d{2}/\d{2}/\d{4}$').hasMatch(v!.trim())
                        ? null
                        : "Use DD/MM/YYYY";
                  },
                ),


                const SizedBox(height: 6),
                const Text("Gender", style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 6),
                ValueListenableBuilder<String?>(
                  valueListenable: gender,
                  builder: (_, val, __) => Wrap(
                    spacing: 10,
                    children: ["Male", "Female", "Other"].map((g) {
                      final sel = val == g;
                      return ChoiceChip(
                        label: Text(g, style: const TextStyle(color: Colors.white)),
                        selected: sel,
                        selectedColor: Colors.white.withOpacity(0.25),
                        backgroundColor: Colors.white.withOpacity(0.12),
                        onSelected: (_) => gender.value = g,
                        shape: StadiumBorder(side: BorderSide(color: Colors.white.withOpacity(0.3))),
                      );
                    }).toList(),
                  ),
                ),

                // Mobile - readOnly flag applied
                field("Mobile Number", mobile,
                    keyboardType: TextInputType.number,
                    maxLength: 10,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                    validator: (v) => RegExp(r'^\d{10}$').hasMatch(v ?? "") ? null : "Enter 10-digit mobile",
                    readOnly: readOnlyMobile),

                // Email - prefilled but editable by default
                field("Email (optional)", email, keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v == null || v.isEmpty) return null;
                      return RegExp(r".+@.+\..+").hasMatch(v) ? null : "Invalid email";
                    }),

                const SizedBox(height: 10),
                const SubTitle("Address"),

                // Permanent pincode (existing)
                field("Pincode", pincode, keyboardType: TextInputType.number, maxLength: 6,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                    onChanged: (v) {
                      if (v.length == 6 && RegExp(r'^\d{6}$').hasMatch(v)) onPincodeChanged(v);
                      else {
                        city.clear();
                        stateCtrl.clear();
                      }
                    },
                    validator: (v) => RegExp(r'^\d{6}$').hasMatch(v ?? "") ? null : "6-digit pincode"),

                // Allow manual edit of City/State and require values (reject placeholder '—')
                field(
                  "City",
                  city,
                  validator: (v) {
                    final t = (v ?? '').trim();
                    if (t.isEmpty || t == '—') return "Enter city";
                    return null;
                  },
                ),
                field(
                  "State",
                  stateCtrl,
                  validator: (v) {
                    final t = (v ?? '').trim();
                    if (t.isEmpty || t == '—') return "Enter state";
                    return null;
                  },
                ),
                field("Permanent Address", addrPermanent, validator: req),

                SwitchListTile(
                    value: sameAsPermanent,
                    onChanged: onSameAsPermanentChanged,
                    title: const Text("Same as permanent address", style: TextStyle(color: Colors.white))),

                // If not same, show CURRENT pincode + city/state + address
                if (!sameAsPermanent) ...[
                  const SizedBox(height: 8),
                  field("Current Pincode", currentPincode, keyboardType: TextInputType.number, maxLength: 6,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                      onChanged: (v) {
                        if (v.length == 6 && RegExp(r'^\d{6}$').hasMatch(v)) onCurrentPincodeChanged(v);
                        else {
                          currentCity.clear();
                          currentState.clear();
                        }
                      },
                      validator: (v) => RegExp(r'^\d{6}$').hasMatch(v ?? "") ? null : "6-digit pincode"),
                  // Allow manual edit of current City/State and require values (reject placeholder '—')
                  field(
                    "Current City",
                    currentCity,
                    validator: (v) {
                      final t = (v ?? '').trim();
                      if (t.isEmpty || t == '—') return "Enter current city";
                      return null;
                    },
                  ),
                  field(
                    "Current State",
                    currentState,
                    validator: (v) {
                      final t = (v ?? '').trim();
                      if (t.isEmpty || t == '—') return "Enter current state";
                      return null;
                    },
                  ),
                  field("Current Address", addrCurrent, validator: req),
                ],

                const SubTitle("Emergency Contact"),
                field("Name", emgName, validator: req),
                field("Relation", emgRelation, validator: req),
                field("Mobile", emgMobile, keyboardType: TextInputType.number, maxLength: 10,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                    validator: (v) => RegExp(r'^\d{10}$').hasMatch(v ?? "") ? null : "Enter 10-digit number"),

                const SubTitle("Govt ID Proof"),
                field("PAN (AAAAA9999A)", pan,
                    inputFormatters: [UpperCaseTextFormatter(), LengthLimitingTextInputFormatter(10)],
                    validator: (v) => RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$').hasMatch(v ?? "") ? null : "Invalid PAN format"),

                field("Aadhaar (XXXX XXXX XXXX)", aadhaar, keyboardType: TextInputType.number,
                    inputFormatters: [AadhaarFormatter(), FilteringTextInputFormatter.allow(RegExp(r'[\d ]')), LengthLimitingTextInputFormatter(14)],
                    validator: (v) => RegExp(r'^\d{12}$').hasMatch((v ?? "").replaceAll(" ", "")) ? null : "Enter 12-digit Aadhaar"),

                const SizedBox(height: 8),

                // Images: PAN front, Aadhaar front/back, selfie
                // Each tap opens gallery picker and calls parent's callback with path (or empty string to clear)
                _imageRow(
                  "PAN Photo (clear, readable)",
                  panPhotoPath,
                      () => _pickImageAndSend(context, (path) async => pickPanPhoto(path)),
                      () => pickPanPhoto(''),
                  required: true,
                ),

                _imageRow(
                  "Aadhaar Photo (front)",
                  aadhaarPhotofrontPath,
                      () => _pickImageAndSend(context, (path) async => pickAadhaarPhotofront(path)),
                      () => pickAadhaarPhotofront(''),
                  required: true,
                ),

                _imageRow(
                  "Aadhaar Photo (back)",
                  aadhaarPhotobackPath,
                      () => _pickImageAndSend(context, (path) async => pickAadhaarPhotoback(path)),
                      () => pickAadhaarPhotoback(''),
                  required: true,
                ),

                _imageRow(
                  "Self-verification selfie (plain bg, no mask/glass)",
                  selfiePath,
                      () => _pickImageAndSend(context, (path) async => pickSelfie(path)),
                      () => pickSelfie(''),
                  required: true,
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
