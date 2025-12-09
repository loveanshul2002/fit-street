// lib/screens/trainer/kyc/steps/professional_step.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/spec_row.dart';
import '../utils/ui_helpers.dart';

// Grouped Specializations
const Map<String, List<String>> kGroupedSpecializations = {
  'Fitness Training': [
    'Strength Training',
    'HIIT',
    'CrossFit',
    'Functional Training',
    'Cardio',
    'Aerobics',
    'Zumba',
    'Strength and Conditioning',
    'Endurance Training',
    'Circuit Training',
    'Dance Fitness',
  ],
  'Body Transformation': [
    'Weight Loss',
    'Weight Gain',
    'Bodybuilding',
    'Muscle Gain Expert',
    'Body Transformation',
    'Female Fitness',
    'Physique Enhancement Specialist',
  ],
  'Health & Rehabilitation': [
    'Rehabilitation Trainer',
    'Pain Management',
    'Injury Prevention',
    'Posture Correction',
    'Lifestyle Disorders',
    'Stretching Specialist',
    'Mobility & Flexibility Coach',
    'Physical Therapist Support',
  ],
  'Yoga & Meditation': [
    'Yoga',
    'Hatha Yoga',
    'Vinyasa Yoga',
    'Prenatal Yoga',
    'Postnatal Yoga',
    'Recreational Yoga',
    'Meditation',
    'Breathwork & Pranayama',
    'Sound Healing',
    'Mindfulness Trainer',
  ],
  'Specialized Fitness': [
    'Pilates Instructor',
    'Calisthenics Coach',
    'Core Strength Trainer',
    'Balance & Stability Training',
    'Sports Performance Coach',
  ],
  'Nutrition & Diet Planning': [
    'Nutrition',
    'Sports Nutritionist',
    'Weight Management Expert',
    'Diet Planning Specialist',
    'Clinical Nutritionist',
    'PCOS/PCOD Nutrition Expert',
    'Diabetes Nutrition Specialist',
    'Thyroid Nutrition Specialist',
    'Cholesterol Management Nutritionist',
    'Holistic Nutrition Coach',
    'Pediatric Nutritionist',
  ],
  'Mental Health & Counseling': [
    'Counselors',
    'Mental Counselor',
    'Psychologist',
    'Depression Support',
    'Stress Management',
    'Art Therapy',
    'Suicide Prevention',
    'Psychological First Aid',
    'Solution-Focused Brief Therapy',
    'Career Counseling',
    'Neuro-Linguistic Programming',
    'Relationship Therapist',
    'Martial Discord',
    'Reproductive Health Counselor',
  ],
  'Sports & Athletics': [
    'Cricket Coach',
    'Boxing Coach',
    'Martial Arts Instructor',
    'Football Trainer',
    'Tennis Coach',
    'Badminton Coach',
    'Athletic Performance Trainer',
  ],
  'Physiotherapist': [
    'Orthopedic Physiotherapy',
    'Neurological Physiotherapy',
    'Sports Physiotherapy',
    'Pediatric Physiotherapy',
    'Geriatric Physiotherapy',
    'Cardiopulmonary Physiotherapy',
    'Women’s Health Physiotherapy',
    'Manual Therapy',
    'Rehabilitation Therapy',
    'Ergonomic & Posture Physiotherapy'
  ]
};

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
  static bool validateProfessionalRows(
      List<SpecRow> rows, void Function(String) toast) {
    if (rows.isEmpty) {
      toast("Add at least one specialisation.");
      return false;
    }
    for (final r in rows) {
      if ((r.specialization ?? "").isEmpty) {
        toast(
            "Please select a specialisation for each row or remove the empty row.");
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
    _oneSessionCtrl =
        TextEditingController(text: widget.oneSessionPriceInitial ?? '');
    _monthlySessionCtrl =
        TextEditingController(text: widget.monthlySessionPriceInitial ?? '');

    // callbacks to notify parent about initial values (in case parent relies on them)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onOneSessionPriceChanged
          ?.call(_oneSessionCtrl.text.isNotEmpty ? _oneSessionCtrl.text : null);
      widget.onMonthlySessionPriceChanged?.call(
          _monthlySessionCtrl.text.isNotEmpty
              ? _monthlySessionCtrl.text
              : null);
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
      final XFile? picked =
          await _picker.pickImage(source: ImageSource.gallery);
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      final tmpDir = await getTemporaryDirectory();
      final filename =
          'cert_${DateTime.now().millisecondsSinceEpoch}${p.extension(picked.path)}';
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
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Padding(
        padding: EdgeInsets.zero,
        child: Form(
          key: widget.formKey,
          child: SingleChildScrollView(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Section("3. Professional Proof"),
              const SizedBox(height: 8),

              // header labels (kept for reference)
              Row(children: const [
                Expanded(
                    child: Text("Specialisation",
                        style: TextStyle(color: Colors.white70))),
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
                  label: const Text("Add more",
                      style: TextStyle(color: Colors.white)),
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
                  if (widget.trainingLangs.contains("Other") &&
                      (v == null || v.trim().isEmpty)) {
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
                  DropdownMenuItem(
                      value: "0-6 months", child: Text("0–6 months")),
                  DropdownMenuItem(
                      value: "6-12 months", child: Text("6–12 months")),
                  DropdownMenuItem(
                      value: "1-3 years", child: Text("1–3 years")),
                  DropdownMenuItem(
                      value: "3-5 years", child: Text("3–5 years")),
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
                  decoration:
                      glassInput().copyWith(labelText: "One session price (₹)"),
                  validator: (v) {
                    // optional field; if you want to make required change here
                    if (v != null && v.trim().isNotEmpty) {
                      if (!RegExp(r'^\d{1,7}$').hasMatch(v.trim()))
                        return "Enter valid price";
                    }
                    return null;
                  },
                  onChanged: (v) => widget.onOneSessionPriceChanged
                      ?.call(v.trim().isEmpty ? null : v.trim()),
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
                  decoration: glassInput()
                      .copyWith(labelText: "Monthly sessions price (₹)"),
                  validator: (v) {
                    if (v != null && v.trim().isNotEmpty) {
                      if (!RegExp(r'^\d{1,7}$').hasMatch(v.trim()))
                        return "Enter valid price";
                    }
                    return null;
                  },
                  onChanged: (v) => widget.onMonthlySessionPriceChanged
                      ?.call(v.trim().isEmpty ? null : v.trim()),
                ),
              ),
            ]),
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
        color: Color.fromARGB((0.04 * 255).round(), 255, 255, 255),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: Color.fromARGB((0.12 * 255).round(), 255, 255, 255)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: Specialisation + remove button
          Row(
            children: [
              Expanded(
                child: FormField<String>(
                  validator: (_) => (r.specialization == null ||
                          r.specialization!.trim().isEmpty)
                      ? "Choose"
                      : null,
                  builder: (formState) => InkWell(
                    onTap: () =>
                        _openSpecializationPicker(row: r, formState: formState),
                    child: InputDecorator(
                      decoration: glassInput().copyWith(
                        labelText: "Specialisation",
                        errorText: formState.errorText,
                      ),
                      child: Text(
                        (r.specialization == null || r.specialization!.isEmpty)
                            ? "Tap to select"
                            : r.specialization!,
                        style: TextStyle(
                          color: (r.specialization == null ||
                                  r.specialization!.isEmpty)
                              ? Colors.white70
                              : Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Remove button
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                tooltip: widget.rows.length == 1
                    ? "Cannot remove last row"
                    : "Remove this row",
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
                decoration: glassInput()
                    .copyWith(labelText: "Certificate Photo (optional)"),
                child: Row(
                  children: [
                    if (r.certificatePhotoPath == null) ...[
                      const Icon(Icons.photo, color: Colors.white70),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text("Tap to upload (optional)",
                              style: const TextStyle(color: Colors.white70))),
                    ] else ...[
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          image: DecorationImage(
                            image: _providerFor(r.certificatePhotoPath!),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Text(p.basename(r.certificatePhotoPath!),
                              style: const TextStyle(color: Colors.white70),
                              overflow: TextOverflow.ellipsis)),
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.white70, size: 18),
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

  ImageProvider _providerFor(String path) {
    final lower = path.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      return NetworkImage(path);
    }
    return FileImage(File(path));
  }

  void _openSpecializationPicker(
      {required SpecRow row, required FormFieldState<String> formState}) {
    // Helper: derive selected groups from current rows
    String? _groupForSpec(String? spec) {
      if (spec == null || spec.isEmpty) return null;
      for (final entry in kGroupedSpecializations.entries) {
        if (entry.value.contains(spec)) return entry.key;
      }
      return null;
    }

    List<String> _getSelectedSpecializationGroups() {
      final groups = <String>[];
      for (final r in widget.rows) {
        final g = _groupForSpec(r.specialization);
        if (g != null) groups.add(g);
      }
      return groups;
    }

    bool _isGroupDisabled(String group) {
      const exclusiveGroups = [
        'Nutrition & Diet Planning',
        'Mental Health & Counseling',
        'Sports & Athletics',
        'Physiotherapist',
      ];
      final selectedGroups = _getSelectedSpecializationGroups();

      final selectedExclusive =
          selectedGroups.where((g) => exclusiveGroups.contains(g)).toList();
      if (selectedExclusive.isNotEmpty) {
        // Only allow the selected exclusive group; disable others
        return group != selectedExclusive.first;
      }

      final selectedNonExclusive =
          selectedGroups.where((g) => !exclusiveGroups.contains(g)).toList();
      if (selectedNonExclusive.isNotEmpty) {
        // If any non-exclusive group is selected, disable all exclusive groups
        return exclusiveGroups.contains(group);
      }

      return false; // No selection yet; allow all
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black87,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Container(
            constraints: const BoxConstraints(maxHeight: 500),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text('Select Specialisation',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView(
                    children: [
                      for (final entry in kGroupedSpecializations.entries)
                        Builder(builder: (context) {
                          final disabled = _isGroupDisabled(entry.key);
                          final titleStyle = TextStyle(
                              color: disabled ? Colors.white24 : Colors.white,
                              fontWeight: FontWeight.w700);
                          return Theme(
                            data: Theme.of(ctx)
                                .copyWith(dividerColor: Colors.white24),
                            child: IgnorePointer(
                              ignoring: disabled,
                              child: Opacity(
                                opacity: disabled ? 0.5 : 1.0,
                                child: ExpansionTile(
                                  initiallyExpanded: false,
                                  title: Text(entry.key, style: titleStyle),
                                  childrenPadding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 6),
                                  children: [
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        for (final spec in entry.value)
                                          GestureDetector(
                                            onTap: () {
                                              Navigator.pop(ctx);
                                              setState(() {
                                                row.specialization = spec;
                                              });
                                              formState.didChange(spec);
                                            },
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 6),
                                              decoration: BoxDecoration(
                                                color: const Color.fromARGB(
                                                    31, 255, 255, 255),
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                                border: Border.all(
                                                    color: Colors.white24),
                                              ),
                                              child: Text(spec,
                                                  style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 12)),
                                            ),
                                          ),
                                      ],
                                    )
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      setState(() {
                        row.specialization = null;
                      });
                      formState.didChange(null);
                    },
                    child: const Text('Clear',
                        style: TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _langChip(String label) {
    final selected = widget.trainingLangs.contains(label);
    return ChoiceChip(
      label: Text(label, style: const TextStyle(color: Colors.white)),
      selected: selected,
      selectedColor: Color.fromARGB((0.25 * 255).round(), 255, 255, 255),
      backgroundColor: Color.fromARGB((0.12 * 255).round(), 255, 255, 255),
      onSelected: (_) {
        setState(() {
          if (selected) {
            widget.trainingLangs.remove(label);
          } else {
            widget.trainingLangs.add(label);
          }
        });
      },
      shape: StadiumBorder(
          side: BorderSide(
              color: Color.fromARGB((0.3 * 255).round(), 255, 255, 255))),
    );
  }
}
