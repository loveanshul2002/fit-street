// lib/screens/user/weight_picker_screen.dart
import 'package:flutter/material.dart';
import 'dart:ui' show ImageFilter;
import '../../utils/profile_storage.dart' show saveWeight;

class WeightPickerScreen extends StatefulWidget {
  final int initialWeight;
  final ValueChanged<int>? onDone;

  const WeightPickerScreen({super.key, this.initialWeight = 65, this.onDone});

  @override
  State<WeightPickerScreen> createState() => _WeightPickerScreenState();
}

class _WeightPickerScreenState extends State<WeightPickerScreen> {
  late FixedExtentScrollController _controller;
  late int _selectedWeight;

  final int minWeight = 30;
  final int maxWeight = 150;

  @override
  void initState() {
    super.initState();
    _selectedWeight = widget.initialWeight.clamp(minWeight, maxWeight);
    _controller = FixedExtentScrollController(initialItem: _selectedWeight - minWeight);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _numberItem(int weight, bool isCenter) {
    final color = isCenter ? Colors.white : Colors.white70;
    final fontSize = isCenter ? 44.0 : 18.0;
    final fontWeight = isCenter ? FontWeight.w700 : FontWeight.w500;
    return Center(
      child: Text(
        weight.toString(),
        style: TextStyle(color: color, fontSize: fontSize, fontWeight: fontWeight),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final itemCount = maxWeight - minWeight + 1;

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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 6),
                          const Text(
                            'What is Your Weight?',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            "Weight in kg. Don't worry, you can always change it later.",
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
                                          height: 450,
                                          child: Stack(
                                            children: [
                                              Positioned.fill(
                                                child: ListWheelScrollView.useDelegate(
                                                  controller: _controller,
                                                  physics: const FixedExtentScrollPhysics(),
                                                  itemExtent: 60,
                                                  diameterRatio: 9,
                                                  perspective: 0.0015,
                                                  onSelectedItemChanged: (index) => setState(() => _selectedWeight = minWeight + index),
                                                  childDelegate: ListWheelChildBuilderDelegate(
                                                    builder: (context, index) {
                                                      final weight = minWeight + index;
                                                      final isCenter = weight == _selectedWeight;
                                                      return _numberItem(weight, isCenter);
                                                    },
                                                    childCount: itemCount,
                                                  ),
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
                                  const SizedBox(height: 40),
                                  Text(
                                    '${_selectedWeight.toString()} kg',
                                    style: const TextStyle(color: Colors.white, fontSize: 35, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () async {
                                await saveWeight(_selectedWeight);
                                widget.onDone?.call(_selectedWeight);
                                Navigator.pop(context, _selectedWeight);
                              },
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
