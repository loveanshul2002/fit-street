// lib/screens/trainer/kyc/steps/professional_step.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../../../widgets/glass_card.dart';
import '../models/spec_row.dart';
import '../utils/ui_helpers.dart';

class ProfessionalStep extends StatefulWidget {
  final GlobalKey<FormState> formKey;
  final String? experience;
  final ValueChanged<String?> onExperienceChanged;

  // languages
  final Set<String> trainingLangs;
  final TextEditingController otherLangCtrl;

  // rows owned by parent (wizard)
  final List<SpecRow> rows;

  // NEW: callbacks for session pricing
  final ValueChanged<String?>? onOneSessionPriceChanged;
  final ValueChanged<String?>? onMonthlySessionPriceChanged;
  final String? oneSessionPriceInitial;
  final String? monthlySessionPriceInitial;

  const ProfessionalStep({
    super.key,
    required this.formKey,
    required this.experience,
    required this.onExperienceChanged,
    required this.trainingLangs,
    required this.otherLangCtrl,
    required this.rows,
    this.onOneSessionPriceChanged,
    this.onMonthlySessionPriceChanged,
    this.oneSessionPriceInitial,
    this.monthlySessionPriceInitial,
  });

  /// Validator requires only specialization for each row (certificate fields optional)
  static bool validateProfessionalRows(List<SpecRow> rows, void Function(String) toast) {
    if (rows.isEmpty) {
      toast("Add at least one specialisation.");
      return false;
    }
    for (final r in rows) {
      if ((r.specialization ?? "").isEmpty) {
        toast("Please select a specialisation for each row or remove the empty row.");
        return false;
      }
    }
    return true;
  }

  @override
  State<ProfessionalStep> createState() => _ProfessionalStepState();
}

class _ProfessionalStepState extends State<ProfessionalStep> {
  final ImagePicker _picker = ImagePicker();

  // controllers for the new price fields
  late final TextEditingController _oneSessionCtrl;
  late final TextEditingController _monthlySessionCtrl;

  @override
  void initState() {
    super.initState();
    if (widget.rows.isEmpty) widget.rows.add(SpecRow());
    _oneSessionCtrl = TextEditingController(text: widget.oneSessionPriceInitial ?? '');
    _monthlySessionCtrl = TextEditingController(text: widget.monthlySessionPriceInitial ?? '');

    // callbacks to notify parent about initial values (in case parent relies on them)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onOneSessionPriceChanged?.call(_oneSessionCtrl.text.isNotEmpty ? _oneSessionCtrl.text : null);
      widget.onMonthlySessionPriceChanged?.call(_monthlySessionCtrl.text.isNotEmpty ? _monthlySessionCtrl.text : null);
    });
  }

  @override
  void dispose() {
    _oneSessionCtrl.dispose();
    _monthlySessionCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickCertPhotoForRow(SpecRow r) async {
    try {
      final XFile? picked = await _picker.pickImage(source: ImageSource.gallery);
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      final tmpDir = await getTemporaryDirectory();
      final filename = 'cert_${DateTime.now().millisecondsSinceEpoch}${p.extension(picked.path)}';
      final f = File('${tmpDir.path}/$filename');
      await f.writeAsBytes(bytes);
      setState(() => r.certificatePhotoPath = f.path);
    } catch (e, st) {
      debugPrint('pickCertPhoto error: $e\n$st');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: GlassCard(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: widget.formKey,
            child: SingleChildScrollView(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Section("3. Professional Proof"),
                const SizedBox(height: 8),

                // header labels (kept for reference)
                Row(children: const [
                  Expanded(child: Text("Specialisation", style: TextStyle(color: Colors.white70))),
                ]),
                const SizedBox(height: 6),

                // Dynamic rows - each row stacked vertically: 1) Specialisation 2) Certificate name 3) Certificate photo
                ...widget.rows.asMap().entries.map((e) {
                  final index = e.key;
                  final row = e.value;
                  return KeyedSubtree(
                    key: ValueKey(row),
                    child: _stackedSpecRow(row, index),
                  );
                }).toList(),

                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => setState(() {
                      widget.rows.add(SpecRow());
                    }),
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: const Text("Add more", style: TextStyle(color: Colors.white)),
                  ),
                ),

                const SizedBox(height: 16),
                const SubTitle("Training Languages"),
                Wrap(spacing: 10, runSpacing: 8, children: [
                  _langChip("English"),
                  _langChip("Hindi"),
                  _langChip("Other"),
                ]),
                const SizedBox(height: 8),
                if (widget.trainingLangs.contains("Other"))
                  field("Other language", widget.otherLangCtrl, validator: (v) {
                    if (widget.trainingLangs.contains("Other") && (v == null || v.trim().isEmpty)) {
                      return "Enter the other language";
                    }
                    return null;
                  }),

                const SizedBox(height: 16),
                const SubTitle("Experience"),
                DropdownButtonFormField<String>(
                  dropdownColor: Colors.black87,
                  style: const TextStyle(color: Colors.white),
                  decoration: glassInput(),
                  value: widget.experience,
                  onChanged: widget.onExperienceChanged,
                  items: const [
                    DropdownMenuItem(value: "0-6 months", child: Text("0–6 months")),
                    DropdownMenuItem(value: "6-12 months", child: Text("6–12 months")),
                    DropdownMenuItem(value: "1-3 years", child: Text("1–3 years")),
                    DropdownMenuItem(value: "3-5 years", child: Text("3–5 years")),
                    DropdownMenuItem(value: "5+ years", child: Text("5+ years")),
                  ],
                  validator: (v) => v == null ? "Select experience" : null,
                ),

                const SizedBox(height: 16),
                const SubTitle("Pricing (per session / monthly)"),
                // One session price
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: TextFormField(
                    controller: _oneSessionCtrl,
                    keyboardType: TextInputType.numberWithOptions(decimal: false),
                    inputFormatters: const [],
                    style: const TextStyle(color: Colors.white),
                    decoration: glassInput().copyWith(labelText: "One session price (₹)"),
                    validator: (v) {
                      // optional field; if you want to make required change here
                      if (v != null && v.trim().isNotEmpty) {
                        if (!RegExp(r'^\d{1,7}$').hasMatch(v.trim())) return "Enter valid price";
                      }
                      return null;
                    },
                    onChanged: (v) => widget.onOneSessionPriceChanged?.call(v.trim().isEmpty ? null : v.trim()),
                  ),
                ),

                // Monthly session price
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TextFormField(
                    controller: _monthlySessionCtrl,
                    keyboardType: TextInputType.numberWithOptions(decimal: false),
                    inputFormatters: const [],
                    style: const TextStyle(color: Colors.white),
                    decoration: glassInput().copyWith(labelText: "Monthly sessions price (₹)"),
                    validator: (v) {
                      if (v != null && v.trim().isNotEmpty) {
                        if (!RegExp(r'^\d{1,7}$').hasMatch(v.trim())) return "Enter valid price";
                      }
                      return null;
                    },
                    onChanged: (v) => widget.onMonthlySessionPriceChanged?.call(v.trim().isEmpty ? null : v.trim()),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _stackedSpecRow(SpecRow r, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: Specialisation + remove button
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  dropdownColor: Colors.black87,
                  style: const TextStyle(color: Colors.white),
                  decoration: glassInput().copyWith(labelText: "Specialisation"),
                  value: r.specialization,
                  onChanged: (v) => setState(() => r.specialization = v),
                  items: const [
                    DropdownMenuItem(value: "Strength", child: Text("Strength")),
                    DropdownMenuItem(value: "HIIT", child: Text("HIIT")),
                    DropdownMenuItem(value: "Yoga", child: Text("Yoga")),
                    DropdownMenuItem(value: "Pilates", child: Text("Pilates")),
                    DropdownMenuItem(value: "Rehab", child: Text("Rehab")),
                    DropdownMenuItem(value: "Zumba", child: Text("Zumba")),
                    DropdownMenuItem(value: "Prenatal Yoga", child: Text("Prenatal Yoga")),
                    DropdownMenuItem(value: "Postnatal Yoga", child: Text("Postnatal Yoga")),
                    DropdownMenuItem(value: "Recreational Yoga", child: Text("Recreational Yoga")),
                    DropdownMenuItem(value: "Nutrition", child: Text("Nutrition")),
                    DropdownMenuItem(value: "Counselors", child: Text("Counselors")),
                 //   DropdownMenuItem(value: "Cardio", child: Text("Cardio")),
                //    DropdownMenuItem(value: "CrossFit", child: Text("CrossFit")),
                 //   DropdownMenuItem(value: "Aerobics", child: Text("Aerobics")),
                 //   DropdownMenuItem(value: "Bodybuilding", child: Text("Bodybuilding")),
                 //   DropdownMenuItem(value: "Weight Loss", child: Text("Weight Loss")),
                 //   DropdownMenuItem(value: "Weight Gain", child: Text("Weight Gain")),
                 //   DropdownMenuItem(value: "Yoga Therapy", child: Text("Yoga Therapy")),
                   // DropdownMenuItem(value: "Functional Training", child: Text("Functional Training")),
                  //  DropdownMenuItem(value: "Martial Arts", child: Text("Martial Arts")),
                //    DropdownMenuItem(value: "Dance Fitness", child: Text("Dance Fitness")),
                   // DropdownMenuItem(value: "Sports Conditioning", child: Text("Sports Conditioning")),
                 //   DropdownMenuItem(value: "Martial Arts", child: Text("Martial Arts")),
                  ],
                  validator: (v) => v == null ? "Choose" : null,
                ),
              ),

              const SizedBox(width: 8),

              // Remove button
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                tooltip: widget.rows.length == 1 ? "Cannot remove last row" : "Remove this row",
                onPressed: widget.rows.length == 1
                    ? null
                    : () {
                  setState(() {
                    // dispose only when removing a row (parent wizard must not also dispose again)
                    try {
                      r.certificateName.dispose();
                    } catch (_) {}
                    widget.rows.removeAt(index);
                  });
                },
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Certificate name (optional) - second line
          field(
            "Certificate Name (optional)",
            r.certificateName,
            validator: (v) {
              // optional: no validation required
              return null;
            },
          ),

          // Certificate photo (optional) - third line
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: InkWell(
              onTap: () => _pickCertPhotoForRow(r),
              child: InputDecorator(
                decoration: glassInput().copyWith(labelText: "Certificate Photo (optional)"),
                child: Row(
                  children: [
                    if (r.certificatePhotoPath == null) ...[
                      const Icon(Icons.photo, color: Colors.white70),
                      const SizedBox(width: 8),
                      Expanded(child: Text("Tap to upload (optional)", style: const TextStyle(color: Colors.white70))),
                    ] else ...[
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          image: DecorationImage(
                            image: FileImage(File(r.certificatePhotoPath!)),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(p.basename(r.certificatePhotoPath!), style: const TextStyle(color: Colors.white70), overflow: TextOverflow.ellipsis)),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.white70, size: 18),
                        onPressed: () {
                          setState(() {
                            r.certificatePhotoPath = null;
                          });
                        },
                        tooltip: "Remove file",
                      )
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _langChip(String label) {
    final selected = widget.trainingLangs.contains(label);
    return ChoiceChip(
      label: Text(label, style: const TextStyle(color: Colors.white)),
      selected: selected,
      selectedColor: Colors.white.withOpacity(0.25),
      backgroundColor: Colors.white.withOpacity(0.12),
      onSelected: (_) {
        setState(() {
          if (selected) {
            widget.trainingLangs.remove(label);
          } else {
            widget.trainingLangs.add(label);
          }
        });
      },
      shape: StadiumBorder(side: BorderSide(color: Colors.white.withOpacity(0.3))),
    );
  }
}
