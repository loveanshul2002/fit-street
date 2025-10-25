// lib/screens/trainer/kyc/trainer_kyc_wizard.dart
import 'dart:typed_data';
import 'dart:io';
import 'dart:convert';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

// import '../../../config/app_colors.dart';
import '../../../widgets/glass_card.dart';
import 'steps/identity_step.dart';
import 'steps/bank_step.dart';
import 'steps/professional_step.dart';
import 'steps/consent_step.dart';
import 'models/spec_row.dart';
import '../../../state/auth_manager.dart';
import '../../../services/fitstreet_api.dart';

class TrainerKycWizard extends StatefulWidget {
  const TrainerKycWizard({super.key});

  @override
  State<TrainerKycWizard> createState() => _TrainerKycWizardState();
}

class _TrainerKycWizardState extends State<TrainerKycWizard> {
  final PageController _page = PageController();
  int _step = 0;

  // Form keys
  final GlobalKey<FormState> f1 = GlobalKey<FormState>();
  final GlobalKey<FormState> f2 = GlobalKey<FormState>();
  final GlobalKey<FormState> f3 = GlobalKey<FormState>();

  // ---------- Shared state ----------
  String? language;
  final TextEditingController fullName = TextEditingController();
  final TextEditingController dob = TextEditingController();
  final ValueNotifier<String?> gender = ValueNotifier(null);

  final TextEditingController mobile = TextEditingController();
  final TextEditingController email = TextEditingController();

  final TextEditingController pincode = TextEditingController();
  final TextEditingController city = TextEditingController();
  final TextEditingController stateCtrl = TextEditingController();

  final TextEditingController currentPincode = TextEditingController();
  final TextEditingController currentCity = TextEditingController();
  final TextEditingController currentState = TextEditingController();
  bool sameAsPermanent = true;
  final TextEditingController addrPermanent = TextEditingController();
  final TextEditingController addrCurrent = TextEditingController();

  final TextEditingController emgName = TextEditingController();
  final TextEditingController emgRelation = TextEditingController();
  final TextEditingController emgMobile = TextEditingController();

  final TextEditingController pan = TextEditingController();
  final TextEditingController aadhaar = TextEditingController();

  // ✅ Added paths here
  String? selfiePath, panPhotoPath, aadhaarPhotofrontPath, aadhaarPhotobackPath;

  // ---------- Bank ----------
  final TextEditingController accName = TextEditingController();
  final TextEditingController ifsc = TextEditingController();
  final TextEditingController bankName = TextEditingController();
  final TextEditingController branch = TextEditingController();
  final TextEditingController upi = TextEditingController();

  // ---------- Professional ----------
  String? experience;
  final Set<String> trainingLangs = {};
  final TextEditingController otherLangCtrl = TextEditingController();

  // **Parent-owned professional rows**
  final List<SpecRow> professionalRows = [SpecRow()];

  // NEW: pricing fields (kept as strings that will be sent to backend)
  String? oneSessionPrice;
  String? monthlySessionPrice;

  // ---------- Consent ----------
  bool noCriminalRecord = false;
  bool agreeHnS = false;
  bool ackTrainerAgreement = false;
  bool ackCancellationPolicy = false;
  bool ackPayoutPolicy = false;
  bool ackPrivacyPolicy = false;

  final TextEditingController esignName = TextEditingController();
  final TextEditingController esignDate = TextEditingController();

  // signature bytes (set by consent step)
  Uint8List? signaturePng;
  String? paymentScreenshotPath;

  // Uploading flag
  bool _uploading = false;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    esignDate.text =
    "${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(
        2, '0')}/${now.year}";
    if (professionalRows.isEmpty) professionalRows.add(SpecRow());
    _loadSavedProfile();
  }

  Future<void> _loadSavedProfile() async {
    final sp = await SharedPreferences.getInstance();
    fullName.text = sp.getString('fitstreet_trainer_name') ?? '';
    mobile.text = sp.getString('fitstreet_trainer_mobile') ??
        sp.getString('fitstreet_user_mobile') ??
        '';
    email.text = sp.getString('fitstreet_trainer_email') ?? '';

    try {
      final auth = context.read<AuthManager>();
      final id = await auth.getApiTrainerId();
      if (id != null && id.isNotEmpty) {
        final res = await auth.fetchTrainerProfile(id);
        if (res['success'] == true && res['body'] is Map) {
          final data = res['body']['data'] ?? res['body'];
          if (data['fullName'] != null) fullName.text = data['fullName'];
          if (data['mobileNumber'] != null) mobile.text = data['mobileNumber'];
          if (data['email'] != null) email.text = data['email'];
          if (data['gender'] != null) gender.value = data['gender'];

          // If backend returns pricing, prefill them
          if (data['oneSessionPrice'] != null)
            oneSessionPrice = data['oneSessionPrice'].toString();
          if (data['monthlySessionPrice'] != null)
            monthlySessionPrice = data['monthlySessionPrice'].toString();
        }
      }
    } catch (e) {
      debugPrint('loadSavedProfile failed: $e');
    }
  }

  @override
  void dispose() {
    _page.dispose();
    fullName.dispose();
    dob.dispose();
    gender.dispose();
    mobile.dispose();
    email.dispose();
    pincode.dispose();
    city.dispose();
    stateCtrl.dispose();
    currentPincode.dispose();
    currentCity.dispose();
    currentState.dispose();
    addrPermanent.dispose();
    addrCurrent.dispose();
    emgName.dispose();
    emgRelation.dispose();
    emgMobile.dispose();
    pan.dispose();
    aadhaar.dispose();
    accName.dispose();
    ifsc.dispose();
    bankName.dispose();
    branch.dispose();
    upi.dispose();
    otherLangCtrl.dispose();
    esignName.dispose();
    esignDate.dispose();
    for (final r in professionalRows) {
      r.certificateName.dispose();
    }
    super.dispose();
  }

  void _toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  // ignore: unused_element
  Future<String?> _captureSelfie() async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 80,
      );
      if (picked == null) return null;

      final tmpDir = await getTemporaryDirectory();
      final fileName =
          'selfie_${DateTime
          .now()
          .millisecondsSinceEpoch}${p.extension(picked.path)}';
      final saved = File('${tmpDir.path}/$fileName');
      final bytes = await picked.readAsBytes();
      await saved.writeAsBytes(bytes);

      return saved.path;
    } catch (e, st) {
      debugPrint('captureSelfie error: $e\n$st');
      return null;
    }
  }

  Future<void> _next() async {
    if (_step == 0) {
      if (f1.currentState!.validate() &&
          IdentityStep.validateAge(dob, _toast) &&
          IdentityStep.validateIDs(pan, aadhaar, _toast)) {
  setState(() => _step = 1);
  _page.jumpToPage(1);
      }
      return;
    }

    if (_step == 1) {
      if (f2.currentState!.validate()) {
  setState(() => _step = 2);
  _page.jumpToPage(2);
      }
      return;
    }

    if (_step == 2) {
      if (f3.currentState!.validate() &&
          ProfessionalStep.validateProfessionalRows(
              professionalRows, _toast)) {
  setState(() => _step = 3);
  _page.jumpToPage(3);
      }
      return;
    }

    if (_step == 3) {
      // First: check required uploads
      if (selfiePath == null ||
          selfiePath!.isEmpty ||
          panPhotoPath == null ||
          panPhotoPath!.isEmpty ||
          aadhaarPhotofrontPath == null ||
          aadhaarPhotofrontPath!.isEmpty ||
          aadhaarPhotobackPath == null ||
          aadhaarPhotobackPath!.isEmpty) {
        _toast("Please upload Selfie, PAN, Aadhaar front and back.");
        return;
      }

      // Then: check consent
      final consentOk = ConsentStep.validateConsent(
        signaturePng: signaturePng,
        fullName: fullName.text,
        esignName: esignName.text,
        esignDate: esignDate.text,
        noCriminalRecord: noCriminalRecord,
        agreeHnS: agreeHnS,
        ackTrainerAgreement: ackTrainerAgreement,
        ackCancellationPolicy: ackCancellationPolicy,
        ackPayoutPolicy: ackPayoutPolicy,
        ackPrivacyPolicy: ackPrivacyPolicy,
        paymentScreenshotPath: paymentScreenshotPath,
        toast: _toast,
      );

      if (consentOk) {
        if (!mounted) return;

        // Call your KYC upload API here
        final ok = await _uploadKyc();
        if (!ok) return;

        _toast("KYC submitted! We’ll verify it shortly.");
        Navigator.pop(context, true);
      }

      return;
    }
  }

  void _back() {
    // Custom back order:
    // Consent(3) -> Professional(2)
    // Professional(2) -> Bank(1)
    // Bank(1) -> Identity(0)
    // Identity(0) -> pop to Trainer Dashboard
    if (_step == 3) {
      setState(() => _step = 2);
      _page.jumpToPage(2);
      return;
    }
    if (_step == 2) {
      setState(() => _step = 1);
      _page.jumpToPage(1);
      return;
    }
    if (_step == 1) {
      setState(() => _step = 0);
      _page.jumpToPage(0);
      return;
    }
    // step 0: exit wizard
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
  final bool keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0.0;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        leadingWidth: 120,
        leading: Row(
          children: [
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
              onPressed: _back,
              tooltip: 'Back',
            ),
            const SizedBox(width: 4),
            Image.asset(
              'assets/image/fitstreet-bull-logo.png',
              height: 36,
              fit: BoxFit.contain,
            ),
          ],
        ),
        title: const Text(
          "Trainer KYC",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
            child: Container(color: Colors.black.withOpacity(0.15)),
          ),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/image/bg.png', fit: BoxFit.cover),
          Container(color: Colors.black.withOpacity(0.35)),
          SafeArea(
            child: Column(
              children: [
                if (!keyboardOpen)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: GlassCard(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            _stepPill(0, "Identity"),
                            const SizedBox(width: 8),
                            _stepPill(1, "Bank"),
                            const SizedBox(width: 8),
                            _stepPill(2, "Professional"),
                            const SizedBox(width: 8),
                            _stepPill(3, "Consent"),
                          ],
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Expanded(
                  child: PageView(
                    controller: _page,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      IdentityStep(
                        formKey: f1,
                        language: language,
                        onLanguageChanged: (v) => setState(() => language = v),
                        fullName: fullName,
                        dob: dob,
                        gender: gender,
                        mobile: mobile,
                        email: email,
                        pincode: pincode,
                        city: city,
                        stateCtrl: stateCtrl,
                        currentPincode: currentPincode,
                        currentCity: currentCity,
                        currentState: currentState,
                        sameAsPermanent: sameAsPermanent,
                        onSameAsPermanentChanged: (v) => setState(() {
                          sameAsPermanent = v;
                          if (v) {
                            addrCurrent.text = addrPermanent.text;
                            currentPincode.text = pincode.text;
                            currentCity.text = city.text;
                            currentState.text = stateCtrl.text;
                          } else {
                            addrCurrent.clear();
                            currentPincode.clear();
                            currentCity.clear();
                            currentState.clear();
                          }
                        }),
                        addrPermanent: addrPermanent,
                        addrCurrent: addrCurrent,
                        emgName: emgName,
                        emgRelation: emgRelation,
                        emgMobile: emgMobile,
                        pan: pan,
                        aadhaar: aadhaar,
                        panPhotoPath: panPhotoPath,
                        aadhaarPhotofrontPath: aadhaarPhotofrontPath,
                        aadhaarPhotobackPath: aadhaarPhotobackPath,
                        selfiePath: selfiePath,
                        pickPanPhoto: (p) => setState(() => panPhotoPath = p),
                        pickAadhaarPhotofront: (p) => setState(() => aadhaarPhotofrontPath = p),
                        pickAadhaarPhotoback: (p) => setState(() => aadhaarPhotobackPath = p),
                        pickSelfie: (p) => setState(() => selfiePath = p),
                        onPincodeChanged: _onPincodeChanged,
                        onCurrentPincodeChanged: _onCurrentPincodeChanged,
                        readOnlyFullName: true,
                        readOnlyMobile: true,
                      ),
                      BankStep(
                        formKey: f2,
                        accName: accName,
                        ifsc: ifsc,
                        bankName: bankName,
                        branch: branch,
                        upi: upi,
                      ),
                      ProfessionalStep(
                        formKey: f3,
                        experience: experience,
                        onExperienceChanged: (v) => setState(() => experience = v),
                        trainingLangs: trainingLangs,
                        otherLangCtrl: otherLangCtrl,
                        rows: professionalRows,
                        onOneSessionPriceChanged: (v) => setState(() => oneSessionPrice = v),
                        onMonthlySessionPriceChanged: (v) => setState(() => monthlySessionPrice = v),
                        oneSessionPriceInitial: oneSessionPrice,
                        monthlySessionPriceInitial: monthlySessionPrice,
                      ),
                      ConsentStep(
                        noCriminalRecord: noCriminalRecord,
                        agreeHnS: agreeHnS,
                        ackTrainerAgreement: ackTrainerAgreement,
                        ackCancellationPolicy: ackCancellationPolicy,
                        ackPayoutPolicy: ackPayoutPolicy,
                        ackPrivacyPolicy: ackPrivacyPolicy,
                        onChange: ({
                          bool? noCrime,
                          bool? hns,
                          bool? agr,
                          bool? cancel,
                          bool? payout,
                          bool? privacy,
                        }) {
                          setState(() {
                            if (noCrime != null) noCriminalRecord = noCrime;
                            if (hns != null) agreeHnS = hns;
                            if (agr != null) ackTrainerAgreement = agr;
                            if (cancel != null) ackCancellationPolicy = cancel;
                            if (payout != null) ackPayoutPolicy = payout;
                            if (privacy != null) ackPrivacyPolicy = privacy;
                          });
                        },
                        esignName: esignName,
                        esignDate: esignDate,
                        onSignatureBytes: (bytes) => signaturePng = bytes,
                        initialPaymentScreenshotPath: paymentScreenshotPath,
                        onPaymentScreenshotSelected: (p) => setState(() => paymentScreenshotPath = p),
                      ),
                    ],
                  ),
                ),
                if (!keyboardOpen)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: BorderSide(color: Colors.white.withOpacity(0.6)),
                            ),
                            onPressed: _back,
                            child: Text(_step == 0 ? "Exit" : "Back"),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white.withOpacity(0.2),
                            ),
                            onPressed: _next,
                            child: Text(
                              _step < 3 ? "Continue" : "Submit KYC",
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepPill(int i, String label) {
    final active = i == _step;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color:
          active ? Colors.white.withOpacity(0.25) : Colors.white.withOpacity(
              0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.25)),
        ),
        alignment: Alignment.center,
        child: Text(label,
            style: TextStyle(
              color: Colors.white,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            )),
      ),
    );
  }

  void _onPincodeChanged(String v) {
    if (v.length == 6 && RegExp(r'^\d{6}$').hasMatch(v)) {
      () async {
        try {
          final auth = context.read<AuthManager>();
          final d = await auth.getCityState(v);
          if (!mounted) return;
          setState(() {
            city.text = (d != null && (d['city'] ?? '').isNotEmpty) ? d['city']! : '—';
            stateCtrl.text = (d != null && (d['state'] ?? '').isNotEmpty) ? d['state']! : '—';
            if (sameAsPermanent) {
              addrCurrent.text = addrPermanent.text;
              currentPincode.text = pincode.text;
              currentCity.text = city.text;
              currentState.text = stateCtrl.text;
            }
          });
        } catch (_) {
          if (!mounted) return;
          setState(() {
            city.text = '—';
            stateCtrl.text = '—';
            if (sameAsPermanent) {
              currentCity.text = '—';
              currentState.text = '—';
              currentPincode.text = pincode.text;
            }
          });
        }
      }();
    } else {
      setState(() {
        city.clear();
        stateCtrl.clear();
        if (sameAsPermanent) {
          currentCity.clear();
          currentState.clear();
          currentPincode.text = pincode.text;
        }
      });
    }
  }

  void _onCurrentPincodeChanged(String v) {
    if (v.length == 6 && RegExp(r'^\d{6}$').hasMatch(v)) {
      () async {
        try {
          final auth = context.read<AuthManager>();
          final d = await auth.getCityState(v);
          if (!mounted) return;
          setState(() {
            currentCity.text = (d != null && (d['city'] ?? '').isNotEmpty) ? d['city']! : '—';
            currentState.text = (d != null && (d['state'] ?? '').isNotEmpty) ? d['state']! : '—';
          });
        } catch (_) {
          if (!mounted) return;
          setState(() {
            currentCity.text = '—';
            currentState.text = '—';
          });
        }
      }();
    } else {
      setState(() {
        currentCity.clear();
        currentState.clear();
      });
    }
  }


  // removed mock pincode lookup; now using AuthManager.getCityState

  /// _uploadKyc
  /// - collects fields and files
  /// - calls FitstreetApi.updateTrainerProfileMultipart(trainerId, ...)
  /// - then uploads specialization proofs individually via createSpecializationProof()
  Future<bool> _uploadKyc() async {
    if (_uploading) return false;
    setState(() => _uploading = true);

    try {
      final auth = context.read<AuthManager>();
      String? trainerId;
      try {
        trainerId = await auth.getApiTrainerId();
      } catch (_) {
        trainerId = null;
      }

      final sp = await SharedPreferences.getInstance();
      trainerId ??= sp.getString('fitstreet_trainer_db_id') ??
          sp.getString('fitstreet_trainer_id');

      if (trainerId == null || trainerId.isEmpty) {
        _toast("Trainer id not found. Complete signup (OTP) first.");
        return false;
      }

      // Convert DOB from DD/MM/YYYY to YYYY-MM-DD (if possible)
      String? dobIso;
      try {
        final txt = dob.text.trim();
        if (txt.isNotEmpty && RegExp(r'^\d{2}/\d{2}/\d{4}$').hasMatch(txt)) {
          final parts = txt.split('/');
          dobIso =
          "${parts[2]}-${parts[1].padLeft(2, '0')}-${parts[0].padLeft(2, '0')}";
        } else if (txt.isNotEmpty) {
          dobIso = txt;
        }
      } catch (_) {
        dobIso = dob.text.trim();
      }

      // Combine languages: selected chips + typed "Other" value(s)
      final List<String> langs = trainingLangs
          .where((l) => l.toLowerCase() != 'other')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      if (trainingLangs.any((l) => l.toLowerCase() == 'other') &&
          otherLangCtrl.text
              .trim()
              .isNotEmpty) {
        // support comma/semicolon separated additional other languages
        langs.addAll(otherLangCtrl.text
            .split(RegExp(r'[,;]'))
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty));
      }

      // Build fields exactly as backend expects
      final Map<String, String> fields = {
        if (fullName.text
            .trim()
            .isNotEmpty) 'fullName': fullName.text.trim(),
        if (mobile.text
            .trim()
            .isNotEmpty) 'mobileNumber': mobile.text.trim(),
        if (dobIso != null && dobIso.isNotEmpty) 'dob': dobIso,
        if (email.text
            .trim()
            .isNotEmpty) 'email': email.text.trim(),
        if (pincode.text
            .trim()
            .isNotEmpty) 'pincode': pincode.text.trim(),
        if (city.text.trim().isNotEmpty && city.text.trim() != '—') 'city': city.text.trim(),
        if (stateCtrl.text.trim().isNotEmpty && stateCtrl.text.trim() != '—') 'state': stateCtrl.text.trim(),

    // indicate whether current = permanent (parity with user profile form)
    'isAddressSame': sameAsPermanent ? 'true' : 'false',

        // current address pincode/city/state when different from permanent
  if (!sameAsPermanent && currentPincode.text.trim().isNotEmpty) 'currentPincode': currentPincode.text.trim(),
  if (!sameAsPermanent && currentCity.text.trim().isNotEmpty && currentCity.text.trim() != '—') 'currentCity': currentCity.text.trim(),
  if (!sameAsPermanent && currentState.text.trim().isNotEmpty && currentState.text.trim() != '—') 'currentState': currentState.text.trim(),
    // when same, mirror permanent into current*
    if (sameAsPermanent && pincode.text
      .trim()
      .isNotEmpty) 'currentPincode': pincode.text.trim(),
  if (sameAsPermanent && city.text.trim().isNotEmpty && city.text.trim() != '—') 'currentCity': city.text.trim(),
  if (sameAsPermanent && stateCtrl.text.trim().isNotEmpty && stateCtrl.text.trim() != '—') 'currentState': stateCtrl.text.trim(),

        if (addrPermanent.text
            .trim()
            .isNotEmpty) 'address': addrPermanent.text.trim(),
    if (!sameAsPermanent && addrCurrent.text
      .trim()
      .isNotEmpty) 'currentAddress': addrCurrent.text.trim(),
    if (sameAsPermanent && addrPermanent.text
      .trim()
      .isNotEmpty) 'currentAddress': addrPermanent.text.trim(),
        if (emgName.text
            .trim()
            .isNotEmpty) 'emergencyPersonName': emgName.text.trim(),
        if (emgMobile.text
            .trim()
            .isNotEmpty) 'emergencyPersonMobile': emgMobile.text.trim(),
        if (emgRelation.text
            .trim()
            .isNotEmpty) 'emergencyPersonRelation': emgRelation.text.trim(),
        if (pan.text
            .trim()
            .isNotEmpty) 'panCard': pan.text.trim(),
        if (aadhaar.text
            .trim()
            .isNotEmpty) 'aadhaarCard': aadhaar.text.replaceAll(' ', '').trim(),
        if (accName.text
            .trim()
            .isNotEmpty) 'accountNumber': accName.text.trim(),
        if (ifsc.text
            .trim()
            .isNotEmpty) 'ifscCode': ifsc.text.trim(),
        if (bankName.text
            .trim()
            .isNotEmpty) 'bankName': bankName.text.trim(),
        if (upi.text
            .trim()
            .isNotEmpty) 'upiId': upi.text.trim(),
        if (langs.isNotEmpty) 'languages': langs.toSet().join(','),
        if (experience != null &&
            experience!.isNotEmpty) 'experience': experience!,
        if (gender.value != null && (gender.value ?? '')
            .toString()
            .isNotEmpty) 'gender': gender.value ?? '',
        // pricing fields (only include if non-null/non-empty)
        if (oneSessionPrice != null &&
            oneSessionPrice!.isNotEmpty) 'oneSessionPrice': oneSessionPrice!,
        if (monthlySessionPrice != null && monthlySessionPrice!
            .isNotEmpty) 'monthlySessionPrice': monthlySessionPrice!,
        // operational flags / defaults expected by API:
        'isAvailable': 'true',
        'mode': 'offline',
        'isKyc': 'true',
        'commission': '10',
      };

      // Build files map with backend file keys
      final Map<String, File> files = {};
      try {
        if (selfiePath != null && selfiePath!.isNotEmpty) {
          final f = File(selfiePath!);
          if (await f.exists()) files['trainerImageURL'] = f;
        }
        if (panPhotoPath != null && panPhotoPath!.isNotEmpty) {
          final f = File(panPhotoPath!);
          if (await f.exists()) files['panFrontImageURL'] = f;
        }
        if (aadhaarPhotofrontPath != null &&
            aadhaarPhotofrontPath!.isNotEmpty) {
          final f = File(aadhaarPhotofrontPath!);
          if (await f.exists()) files['aadhaarFrontImageURL'] = f;
        }
        if (aadhaarPhotobackPath != null && aadhaarPhotobackPath!.isNotEmpty) {
          final f = File(aadhaarPhotobackPath!);
          if (await f.exists()) files['aadhaarBackImageURL'] = f;
        }

        // signature bytes -> temp file and send as esignImageURL
        if (signaturePng != null && signaturePng!.isNotEmpty) {
          final dir = await getTemporaryDirectory();
          final tmp = File('${dir.path}/esign_${DateTime
              .now()
              .millisecondsSinceEpoch}.png');
          await tmp.writeAsBytes(signaturePng!);
          files['esignImageURL'] = tmp;
        }
      } catch (e) {
        debugPrint('Error preparing files for KYC: $e');
      }

      debugPrint('KYC submit - trainerId (raw): $trainerId');
      debugPrint('KYC submit - fields keys: ${fields.keys.toList()}');
      debugPrint('KYC submit - files: ${files.keys.toList()}');

      final savedToken = (await SharedPreferences.getInstance()).getString(
          'fitstreet_token') ?? '';
      final fitApi = FitstreetApi(
          'https://api.fitstreet.in', token: savedToken);

      // Call multipart update
    final streamed = await fitApi.updateTrainerProfileMultipart(
      trainerId, fields: fields, files: files.isEmpty ? null : files);
      final resp = await http.Response.fromStream(streamed);

      debugPrint(
          'KYC submit -> status: ${resp.statusCode}, body: ${resp.body}');
      dynamic body;
      try {
        body = jsonDecode(resp.body);
      } catch (_) {
        body = resp.body;
      }

      if (resp.statusCode == 200 || resp.statusCode == 201) {
        // Update local cached profile (IDs, name, email etc.)
        try {
          await auth.fetchTrainerProfile(trainerId);
        } catch (e) {
          debugPrint('fetchTrainerProfile after KYC failed: $e');
        }

        // Now upload specialization proofs (only those rows that have an image)
        // Now upload specialization proofs (only those rows that have an image OR spec only)
        try {
          for (final row in professionalRows) {
            final spec = row.specialization?.trim();
            if (spec == null || spec.isEmpty) {
              debugPrint('Skipping specialization row (empty specialization).');
              continue;
            }

            final certPath = row.certificatePhotoPath;
            final certName = row.certificateName.text.trim();
            if (certPath != null && certPath.isNotEmpty) {
              final f = File(certPath);
              if (await f.exists()) {
                debugPrint('Uploading specialization proof (multipart) for "$spec" with file $certPath');
                try {
                  final proofResp = await fitApi.createSpecializationProof(
                    trainerId,
                    spec,
                    f,
                    certificateName: certName.isEmpty ? null : certName,
                  );
                  debugPrint('Specialization proof (multipart) -> status: ${proofResp.statusCode}, body: ${proofResp.body}');
                } catch (e) {
                  debugPrint('Error uploading specialization proof (multipart) for $spec: $e');
                }
              } else {
                debugPrint('Spec photo file missing for "$spec": $certPath — will try create minimal entry.');
                // fallback to minimal create without image
                try {
                  final proofResp = await fitApi.createSpecializationProofMinimal(trainerId, spec, certificateName: certName.isEmpty ? null : certName);
                  debugPrint('Specialization proof (minimal fallback) -> status: ${proofResp.statusCode}, body: ${proofResp.body}');
                } catch (e) {
                  debugPrint('Error creating minimal specialization proof fallback for $spec: $e');
                }
              }
            } else {
              // No photo: create minimal entry with certificateName null if empty
              debugPrint('Creating minimal specialization proof for "$spec" (no photo).');
              try {
                final proofResp = await fitApi.createSpecializationProofMinimal(trainerId, spec, certificateName: certName.isEmpty ? null : certName);
                debugPrint('Specialization proof (minimal) -> status: ${proofResp.statusCode}, body: ${proofResp.body}');
              } catch (e) {
                debugPrint('Error creating minimal specialization proof for $spec: $e');
              }
            }
          }
        } catch (e) {
          debugPrint('Error while uploading specialization proofs: $e');
        }


        _toast('KYC uploaded successfully.');
        return true;
      } else {
        String msg = 'Failed to submit KYC (${resp.statusCode})';
        try {
          if (body is Map)
            msg = (body['message'] ?? body['error'] ?? body['msg'] ?? msg)
                .toString();
          else if (resp.body.isNotEmpty) msg = resp.body;
        } catch (_) {}
        _toast(msg);
        return false;
      }
    } catch (e, st) {
      debugPrint('KYC upload exception: $e\n$st');
      _toast('Error uploading KYC: ${e.toString()}');
      return false;
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }
}
