// lib/screens/user/height_picker_screen.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:ui' show ImageFilter;
import '../../utils/profile_storage.dart' show saveHeight;

class HeightPickerScreen extends StatefulWidget {
  const HeightPickerScreen({super.key});

  @override
  State<HeightPickerScreen> createState() => _HeightPickerScreenState();
}

class _HeightPickerScreenState extends State<HeightPickerScreen> {
  // Only ft/in picker
  late FixedExtentScrollController _ftController;
  late FixedExtentScrollController _inchController;

  int minFt = 3; // 3ft
  int maxFt = 7; // 7ft
  int selectedFt = 5;
  int selectedInch = 9;

  @override
  void initState() {
    super.initState();
    selectedFt = 5;
    selectedInch = 9;
    _ftController = FixedExtentScrollController(initialItem: selectedFt - minFt);
    _inchController = FixedExtentScrollController(initialItem: selectedInch);
  }

  @override
  void dispose() {
    _ftController.dispose();
    _inchController.dispose();
    super.dispose();
  }

  void _onContinue() {
  // Save as ft.in string, e.g., '5.9' for 5 ft 9 in
  final numeric = '${selectedFt}.${selectedInch}';
  saveHeight(numeric); // fire and forget
  Navigator.pop(context, {'ft': selectedFt, 'in': selectedInch});
  }

  // removed _pickerTile after refactor; inlined pickers into glass container

  @override
  Widget build(BuildContext context) {
  // final width = MediaQuery.of(context).size.width; // not used currently

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
                constraints: const BoxConstraints(maxWidth: 480),
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
                          // Main content column
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                          const SizedBox(height: 6),
                          const Text(
                            'What is Your Height?',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Height in ft/in. You can change later.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(height: 16),
                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Column(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: BackdropFilter(
                                      filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Colors.white.withOpacity(0.12),
                                              Colors.white.withOpacity(0.04),
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(color: Colors.white.withOpacity(0.24), width: 0.75),
                                        ),
                                        child: SizedBox(
                                          height: 400,
                                          child: Stack(
                                            children: [
                                              Positioned.fill(
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    SizedBox(
                                                      width: 110,
                                                      child: CupertinoPicker(
                                                        scrollController: _ftController,
                                                        itemExtent: 60,
                                                        useMagnifier: false,
                                                        magnification: 1.0,
                                                        selectionOverlay: const SizedBox.shrink(),
                                                        onSelectedItemChanged: (i) => setState(() => selectedFt = minFt + i),
                                                        children: List.generate(
                                                          maxFt - minFt + 1,
                                                          (i) {
                                                            final v = minFt + i;
                                                            final isCenter = v == selectedFt;
                                                            return Center(
                                                              child: Text(
                                                                '$v',
                                                                style: TextStyle(
                                                                  color: isCenter ? Colors.white : Colors.white70,
                                                                  fontSize: isCenter ? 50 : 30,
                                                                  fontWeight: isCenter ? FontWeight.w700 : FontWeight.w500,
                                                                ),
                                                              ),
                                                            );
                                                          },
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    SizedBox(
                                                      width: 110,
                                                      child: CupertinoPicker(
                                                        scrollController: _inchController,
                                                        itemExtent: 60,
                                                        useMagnifier: false,
                                                        magnification: 1.0,
                                                        selectionOverlay: const SizedBox.shrink(),
                                                        onSelectedItemChanged: (i) => setState(() => selectedInch = i),
                                                        children: List.generate(
                                                          12,
                                                          (i) {
                                                            final isCenter = i == selectedInch;
                                                            return Center(
                                                              child: Text(
                                                                '$i',
                                                                style: TextStyle(
                                                                  color: isCenter ? Colors.white : Colors.white70,
                                                                  fontSize: isCenter ? 50 : 30,
                                                                  fontWeight: isCenter ? FontWeight.w700 : FontWeight.w500,
                                                                ),
                                                              ),
                                                            );
                                                          },
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Align(
                                                alignment: Alignment.center,
                                                child: Container(
                                                  height: 20,
                                                  margin: const EdgeInsets.symmetric(horizontal: 30),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white24,
                                                    borderRadius: BorderRadius.circular(2),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 80),
                                  Text(
                                    '$selectedFt ft $selectedInch in',
                                    style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _onContinue,
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
                                      filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
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
                                        child: const Text(
                                          'Continue',
                                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
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
                            top: 1,
                            left: 1,





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
