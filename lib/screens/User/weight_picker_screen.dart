// lib/screens/user/weight_picker_screen.dart
import 'package:flutter/material.dart';
import '../../widgets/glass_card.dart';
import '../../config/app_colors.dart';

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
    return Center(child: Text(weight.toString(), style: TextStyle(color: color, fontSize: fontSize, fontWeight: fontWeight)));
  }

  @override
  Widget build(BuildContext context) {
    final itemCount = maxWeight - minWeight + 1;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(gradient: LinearGradient(colors: [AppColors.primary, AppColors.secondary], begin: Alignment.topLeft, end: Alignment.bottomRight)),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 8),
                const Text("What is Your Weight?", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 8),
                const Text("Weight in kg. Don't worry, you can always change it later.", textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 36),

                Expanded(
                  child: Center(
                    child: GlassCard(
                      borderRadius: 20,
                      child: SizedBox(
                        height: 220,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: ListWheelScrollView.useDelegate(
                                controller: _controller,
                                physics: const FixedExtentScrollPhysics(),
                                itemExtent: 60,
                                diameterRatio: 1.2,
                                perspective: 0.0015,
                                onSelectedItemChanged: (index) => setState(() => _selectedWeight = minWeight + index),
                                childDelegate: ListWheelChildBuilderDelegate(
                                  builder: (context, index) {
                                    final weight = minWeight + index;
                                    final centerIndex = _controller.selectedItem;
                                    final isCenter = index == centerIndex;
                                    return _numberItem(weight, isCenter);
                                  },
                                  childCount: itemCount,
                                ),
                              ),
                            ),
                            Align(alignment: Alignment.center, child: Container(height: 3, margin: const EdgeInsets.symmetric(horizontal: 30), decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
                            Align(alignment: const Alignment(0, 0.45), child: Icon(Icons.arrow_drop_up, color: AppColors.secondary, size: 28)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 18),
                Text("${_selectedWeight.toString()} kg", style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                const SizedBox(height: 18),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: BorderSide(color: Colors.white.withOpacity(0.25)), padding: const EdgeInsets.symmetric(vertical: 14)),
                        child: const Text("Back"),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          widget.onDone?.call(_selectedWeight);
                          Navigator.pop(context, _selectedWeight);
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.white.withOpacity(0.12), padding: const EdgeInsets.symmetric(vertical: 14)),
                        child: const Text("Continue", style: TextStyle(color: Colors.white)),
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
