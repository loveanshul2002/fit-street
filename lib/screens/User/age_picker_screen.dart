// lib/screens/user/age_picker_screen.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:ui' show ImageFilter;

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
    final isNarrow = MediaQuery.of(context).size.width < 420;

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
              padding: const EdgeInsets.all(15.0),
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 6),
                          const Text(
                            'How old are you?',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Age in years. This helps us personalize programs and recommendations.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(height: 16),
                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Column(
                                children: [
                                  Text(
                                    '$_selectedAge',
                                    style: TextStyle(color: Colors.white, fontSize: isNarrow ? 48 : 64, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 6),
                                  Text('years', style: TextStyle(color: Colors.white70, fontSize: isNarrow ? 14 : 16)),
                                  const SizedBox(height: 12),
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
                                            alignment: Alignment.center,
                                            children: [
                                              CupertinoPicker.builder(
                                                scrollController: _scrollController,
                                                itemExtent: 60,
                                                backgroundColor: Colors.transparent,
                                                onSelectedItemChanged: (index) => setState(() => _selectedAge = _ages[index]),
                                                childCount: _ages.length,
                                                itemBuilder: (context, index) {
                                                  final age = _ages[index];
                                                  final isSelected = age == _selectedAge;
                                                  return Center(
                                                    child: Text(
                                                      '$age',
                                                      style: TextStyle(
                                                        color: isSelected ? Colors.white : Colors.white70,
                                                        fontSize: 50,
                                                        fontWeight: FontWeight.w900,
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),

                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  if (widget.minAge >= 15)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 6),
                                      child: Text(
                                        'You must be ${widget.minAge}+ to use trainer-led services.',
                                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                                      ),
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
