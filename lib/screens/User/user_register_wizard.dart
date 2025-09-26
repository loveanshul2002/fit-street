

import 'package:flutter/material.dart';
import '../../widgets/glass_card.dart';
import '../../config/app_colors.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../utils/role_storage.dart';
import '../../utils/user_role.dart';
import '../home/home_screen.dart';
import '../User/gender_selection_screen.dart';



class UserRegisterWizard extends StatefulWidget {
  const UserRegisterWizard({super.key});

  @override
  State<UserRegisterWizard> createState() => _UserRegisterWizardState();
}

enum Gender { male, female, other }
enum HeightUnit { cm, feet }

class _UserRegisterWizardState extends State<UserRegisterWizard> {
  final PageController _pageController = PageController();
  int _page = 0;

  bool _loading = false;

  // Step fields
  final _nameCtrl = TextEditingController();
  DateTime? _dob;
  Gender? _gender;
  HeightUnit _heightUnit = HeightUnit.cm;
  final _heightCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _healthCtrl = TextEditingController();
  final _emergencyNameCtrl = TextEditingController();
  final _emergencyRelationCtrl = TextEditingController();
  final _emergencyPhoneCtrl = TextEditingController();
  final _goalCtrl = TextEditingController();


  void _next() {
    if (_page == 0) {
      if (_gender == null) {
        _showMsg('Please select a gender to continue');
        return;
      }
      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.ease);
      return;
    }

    // existing behavior for other pages
    if (_page < 4) {
      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.ease);
    } else {
      _submit();
    }
  }


  void _back() {
    if (_page > 0) _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.ease);
  }

  void _submit() {
    // Simple validation example; add server call here
    if (_nameCtrl.text.trim().isEmpty) {
      _showMsg('Please enter your name');
      _pageController.jumpToPage(0);
      return;
    }
    if (_dob == null || _gender == null) {
      _showMsg('Please select DOB and gender');
      _pageController.jumpToPage(1);
      return;
    }
    // inside _UserRegisterWizardState class:

    void _submit() async {
      // Simple validation example; add more validation if needed
      if (_nameCtrl.text.trim().isEmpty) {
        _showMsg('Please enter your name');
        _pageController.jumpToPage(0);
        return;
      }
      if (_dob == null || _gender == null) {
        _showMsg('Please select DOB and gender');
        _pageController.jumpToPage(1);
        return;
      }

      // Demo: registration success flow
      // TODO: Replace with real backend call to create user

      setState(() => _loading = true);

      try {
        // simulate network
        await Future.delayed(const Duration(milliseconds: 700));

        // Save role locally so next time app opens HomeScreen
        await saveUserRole(UserRole.member);

        // Navigate to HomeScreen and clear backstack
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
              (route) => false,
        );
      } finally {
        setState(() => _loading = false);
      }
    }
    // all good for demo
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Registration complete'),
        content: const Text('Demo registration saved locally. Connect to backend to persist.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))
        ],
      ),
    );
  }

  void _showMsg(String s) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));

  @override
  void initState() {
    super.initState();
    _pageController.addListener(() {
      final p = _pageController.page?.round() ?? 0;
      if (p != _page) setState(() => _page = p);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    _emailCtrl.dispose();
    _healthCtrl.dispose();
    _emergencyNameCtrl.dispose();
    _emergencyRelationCtrl.dispose();
    _emergencyPhoneCtrl.dispose();
    _goalCtrl.dispose();
    super.dispose();
  }

  Widget _stepHeader(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 8),
      ],
    );
  }
  Widget _genderCircle(String label, IconData icon, Gender g) {
    final selected = _gender == g;
    final double diameter = MediaQuery.of(context).size.width * 0.42; // large circle; adjust if needed

    return GestureDetector(
      onTap: () => setState(() => _gender = g),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: selected ? AppColors.primaryGradient : null,
          color: selected ? null : Colors.white.withOpacity(0.18),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
          boxShadow: selected ? [BoxShadow(color: Colors.black26, blurRadius: 14, offset: const Offset(0, 8))] : [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: diameter * 0.28, color: Colors.white),
            const SizedBox(height: 12),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }


  Widget _page0() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // title area
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: const [
              Text(
                'Tell Us About Yourself',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              SizedBox(height: 8),
              Text(
                'To give you a better experience and results\nwe need to know your gender.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),

        const SizedBox(height: 28),

        // Big circular gender options
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _genderCircle('Male', Icons.male, Gender.male),
              const SizedBox(height: 28),
              _genderCircle('Female', Icons.female, Gender.female),
              const SizedBox(height: 28),
              // Optional "Other" - uncomment if you want it
              // _genderCircle('Other', Icons.transgender, Gender.other),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Continue button (disabled until gender selected)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6.0),
          child: GlassCard(
            borderRadius: 40,
            child: Container(
              padding: const EdgeInsets.all(6),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _gender == null ? null : () {
                    // move to next page
                    _next();
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                  ),
                  child: Ink(
                    decoration: BoxDecoration(
                      gradient: _gender == null
                          ? const LinearGradient(colors: [Colors.grey, Colors.grey])
                          : AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(32),
                    ),
                    child: Container(
                      alignment: Alignment.center,
                      height: 52,
                      child: Text('Continue', style: const TextStyle(color: Colors.white, fontSize: 16)),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }


  Widget _page1() {
    return Column(
      children: [
        _stepHeader('Height & Weight'),
        GlassCard(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _heightUnit = HeightUnit.cm),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _heightUnit == HeightUnit.cm ? Colors.white24 : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(child: Text('cm')),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _heightUnit = HeightUnit.feet),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _heightUnit == HeightUnit.feet ? Colors.white24 : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(child: Text('ft / in')),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _heightCtrl,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: _heightUnit == HeightUnit.cm ? 'Height (cm) e.g., 175' : 'Height (ft.in) e.g., 5.9',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _weightCtrl,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(border: InputBorder.none, hintText: 'Weight (kg)'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _page2() {
    return Column(
      children: [
        _stepHeader('Contact & Health'),
        GlassCard(
          child: Column(
            children: [
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(border: InputBorder.none, hintText: 'Email address (optional)'),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _healthCtrl,
                minLines: 1,
                maxLines: 3,
                decoration: const InputDecoration(border: InputBorder.none, hintText: 'Any health issues / allergies'),
              ),
              const SizedBox(height: 8),
              const Divider(color: Colors.white54),
              const SizedBox(height: 8),
              const Text('Emergency contact', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _emergencyNameCtrl,
                decoration: const InputDecoration(border: InputBorder.none, hintText: 'Name'),
              ),
              TextFormField(
                controller: _emergencyRelationCtrl,
                decoration: const InputDecoration(border: InputBorder.none, hintText: 'Relation'),
              ),
              TextFormField(
                controller: _emergencyPhoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(border: InputBorder.none, hintText: 'Phone e.g., +91xxxxxxxxxx'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _page3() {
    return Column(
      children: [
        _stepHeader('Fitness Goal'),
        GlassCard(
          child: Column(
            children: [
              const Text('Choose goal (tap multiple if needed)'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: ['Fat loss', 'Build muscle', 'Strength', 'Endurance', 'Flexibility', 'General fitness']
                    .map((g) => FilterChip(
                  label: Text(g),
                  selected: _goalCtrl.text.split(',').contains(g),
                  onSelected: (sel) {
                    final list = _goalCtrl.text.isEmpty ? <String>[] : _goalCtrl.text.split(',');
                    if (sel) {
                      list.add(g);
                    } else {
                      list.remove(g);
                    }
                    setState(() => _goalCtrl.text = list.join(','));
                  },
                ))
                    .toList(),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _goalCtrl,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(border: InputBorder.none, hintText: 'Tell us in detail about your goal'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _page4() {
    return Column(
      children: [
        _stepHeader('Preview & Start'),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Name: ${_nameCtrl.text}'),
              const SizedBox(height: 6),
              Text('DOB: ${_dob == null ? '-' : DateFormat.yMMMd().format(_dob!)}'),
              const SizedBox(height: 6),
              Text('Gender: ${_gender == null ? '-' : _gender!.name}'),
              const SizedBox(height: 6),
              Text('Height: ${_heightCtrl.text} ${_heightUnit == HeightUnit.cm ? 'cm' : 'ft'}'),
              const SizedBox(height: 6),
              Text('Weight: ${_weightCtrl.text} kg'),
              const SizedBox(height: 6),
              Text('Email: ${_emailCtrl.text}'),
              const SizedBox(height: 6),
              Text('Health: ${_healthCtrl.text}'),
              const SizedBox(height: 6),
              Text('Emergency: ${_emergencyNameCtrl.text} - ${_emergencyPhoneCtrl.text} (${_emergencyRelationCtrl.text})'),
              const SizedBox(height: 6),
              Text('Goal: ${_goalCtrl.text}'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _bottomBar() {
    return Row(
      children: [
        if (_page > 0)
          ElevatedButton(
            onPressed: _loading ? null : _back,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white24,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: Text('Back'),
            ),
          ),
        const Spacer(),
        ElevatedButton(
          onPressed: _loading ? null : (_page < 4 ? _next : _submit),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: _loading
              ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          )
              : Text(_page < 4 ? 'Next' : 'Start'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // background same gradient
      body: Container(
        decoration: BoxDecoration(gradient:AppColors.primaryGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 18),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.person, color: Colors.white)),
                    const SizedBox(width: 12),
                    const Text('Create your profile', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      SingleChildScrollView(child: _page0()),
                      SingleChildScrollView(child: _page1()),
                      SingleChildScrollView(child: _page2()),
                      SingleChildScrollView(child: _page3()),
                      SingleChildScrollView(child: _page4()),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _bottomBar(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

