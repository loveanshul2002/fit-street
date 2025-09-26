// lib/screens/user/height_picker_screen.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../widgets/glass_card.dart';
import '../../config/app_colors.dart';

class HeightPickerScreen extends StatefulWidget {
  const HeightPickerScreen({super.key});

  @override
  State<HeightPickerScreen> createState() => _HeightPickerScreenState();
}

class _HeightPickerScreenState extends State<HeightPickerScreen> {
  // We'll allow user to pick either cm or ft/in.
  bool useCm = false;
  late FixedExtentScrollController _cmController;
  late FixedExtentScrollController _ftController;
  late FixedExtentScrollController _inchController;

  int minCm = 120;
  int maxCm = 220;
  int selectedCm = 175;

  int minFt = 3; // 3ft
  int maxFt = 7; // 7ft
  int selectedFt = 5;
  int selectedInch = 9;

  @override
  void initState() {
    super.initState();
    selectedCm = 175;
    _cmController = FixedExtentScrollController(initialItem: selectedCm - minCm);
    selectedFt = 5;
    selectedInch = 9;
    _ftController = FixedExtentScrollController(initialItem: selectedFt - minFt);
    _inchController = FixedExtentScrollController(initialItem: selectedInch);
  }

  @override
  void dispose() {
    _cmController.dispose();
    _ftController.dispose();
    _inchController.dispose();
    super.dispose();
  }

  void _onContinue() {
    if (useCm) {
      Navigator.pop(context, {'cm': selectedCm});
    } else {
      Navigator.pop(context, {'ft': selectedFt, 'in': selectedInch});
    }
  }

  Widget _pickerTile(Widget child) {
    return SizedBox(width: 100, height: 160, child: child);
  }

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
              Row(children: [IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back, color: Colors.white)), const SizedBox(width: 6), const Expanded(child: Text('What is Your Height?', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)))]),
              const SizedBox(height: 12),
              const Text("Height in cm or ft/in. You can change later.", textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 22),

              GlassCard(
                borderRadius: 30,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 12),
                  child: Column(children: [
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      ChoiceChip(label: const Text('cm'), selected: useCm, onSelected: (v) => setState(() => useCm = v), selectedColor: Colors.white24, backgroundColor: Colors.white12),
                      const SizedBox(width: 12),
                      ChoiceChip(label: const Text('ft / in'), selected: !useCm, onSelected: (v) => setState(() => useCm = !v), selectedColor: Colors.white24, backgroundColor: Colors.white12),
                    ]),

                    const SizedBox(height: 14),

                    if (useCm)
                      SizedBox(
                        height: 160,
                        child: CupertinoPicker(
                          scrollController: _cmController,
                          itemExtent: 34,
                          onSelectedItemChanged: (index) => setState(() => selectedCm = minCm + index),
                          children: List.generate(maxCm - minCm + 1, (i) => Center(child: Text('${minCm + i}', style: TextStyle(color: (minCm + i) == selectedCm ? Colors.white : Colors.white70, fontSize: (minCm + i) == selectedCm ? 40 : 20)))),
                        ),
                      )
                    else
                      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        _pickerTile(CupertinoPicker(scrollController: _ftController, itemExtent: 34, onSelectedItemChanged: (i) => setState(() => selectedFt = minFt + i), children: List.generate(maxFt - minFt + 1, (i) => Center(child: Text('${minFt + i}', style: TextStyle(color: (minFt + i) == selectedFt ? Colors.white : Colors.white70, fontSize: (minFt + i) == selectedFt ? 40 : 20)))))),
                        const SizedBox(width: 6),
                        _pickerTile(CupertinoPicker(scrollController: _inchController, itemExtent: 34, onSelectedItemChanged: (i) => setState(() => selectedInch = i), children: List.generate(12, (i) => Center(child: Text('${i}', style: TextStyle(color: i == selectedInch ? Colors.white : Colors.white70, fontSize: i == selectedInch ? 40 : 20)))))),
                      ]),

                    const SizedBox(height: 18),
                    Text(useCm ? '$selectedCm cm' : '$selectedFt ft $selectedInch in', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                  ]),
                ),
              ),

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
