// lib/screens/user/age_picker_screen.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../widgets/glass_card.dart';

class AgePickerScreen extends StatefulWidget {
  final int initialAge;
  final int minAge;
  final int maxAge;

  const AgePickerScreen({super.key, this.initialAge = 25, this.minAge = 15, this.maxAge = 80});

  @override
  State<AgePickerScreen> createState() => _AgePickerScreenState();
}

class _AgePickerScreenState extends State<AgePickerScreen> {
  late FixedExtentScrollController _scrollController;
  late int _selectedAge;
  late List<int> _ages;

  @override
  void initState() {
    super.initState();
    _ages = List.generate(widget.maxAge - widget.minAge + 1, (i) => widget.minAge + i);
    _selectedAge = widget.initialAge.clamp(widget.minAge, widget.maxAge);
    final initialIndex = _ages.indexOf(_selectedAge);
    _scrollController = FixedExtentScrollController(initialItem: initialIndex >= 0 ? initialIndex : 0);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onContinue() => Navigator.pop(context, _selectedAge);

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isNarrow = width < 420;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(gradient: LinearGradient(colors: [AppColors.primary, AppColors.secondary], begin: Alignment.topLeft, end: Alignment.bottomRight)),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 18),
            child: Column(children: [
              Row(children: [IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back, color: Colors.white)), const SizedBox(width: 6), const Expanded(child: Text('How old are you?', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)))]),
              const SizedBox(height: 12),
              const Text('Age in years. This helps us personalize programs and recommendations.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 22),
              GlassCard(
                borderRadius: 30,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 60.0, horizontal: 30),
                  child: Column(children: [
                    Text('$_selectedAge', style: TextStyle(color: Colors.white, fontSize: isNarrow ? 48 : 64, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text('years', style: TextStyle(color: Colors.white70, fontSize: isNarrow ? 14 : 16)),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 160,
                      child: Stack(alignment: Alignment.center, children: [
                        CupertinoPicker.builder(
                          scrollController: _scrollController,
                          itemExtent: 34,
                          backgroundColor: Colors.transparent,
                          onSelectedItemChanged: (index) => setState(() => _selectedAge = _ages[index]),
                          childCount: _ages.length,
                          itemBuilder: (context, index) {
                            final age = _ages[index];
                            final isSelected = age == _selectedAge;
                            return Center(child: Text('$age', style: TextStyle(color: isSelected ? Colors.white : Colors.white70, fontSize: isSelected ? 50 : 50, fontWeight: FontWeight.w900)));
                          },
                        ),
                        IgnorePointer(child: Align(alignment: Alignment.center, child: Container(height: 36, margin: const EdgeInsets.symmetric(horizontal: 12), decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white.withOpacity(0.06)))))),
                      ]),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 20),
              if (widget.minAge >= 15) Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: Text('You must be ${widget.minAge}+ to use trainer-led services.', style: const TextStyle(color: Colors.white70, fontSize: 13))),
              const Spacer(),
              GlassCard(
                borderRadius: 40,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(onPressed: _onContinue, style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)), backgroundColor: Colors.transparent, shadowColor: Colors.transparent), child: Ink(decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(32)), child: Container(alignment: Alignment.center, height: 52, child: const Text('Continue', style: TextStyle(color: Colors.white, fontSize: 16))))),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ]),
          ),
        ),
      ),
    );
  }
}
