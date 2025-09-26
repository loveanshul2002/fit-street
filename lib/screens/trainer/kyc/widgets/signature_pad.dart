import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:signature/signature.dart';
import '../utils/ui_helpers.dart';

class SignaturePad extends StatefulWidget {
  final ValueChanged<Uint8List?> onBytes;
  const SignaturePad({super.key, required this.onBytes});

  @override
  State<SignaturePad> createState() => _SignaturePadState();
}

class _SignaturePadState extends State<SignaturePad> {
  final _controller = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _export() async {
    final bytes = await _controller.toPngBytes();
    widget.onBytes(bytes);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Signature captured")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white70)),
        height: 180,
        child: Signature(controller: _controller, backgroundColor: Colors.white),
      ),
      const SizedBox(height: 8),
      Row(children: [
        OutlinedButton(onPressed: ()=> _controller.clear(), child: const Text("Clear")),
        const SizedBox(width: 12),
        ElevatedButton(onPressed: _export, child: const Text("Save Signature")),
        const SizedBox(width: 12),
        const Flexible(child: Text("Sign inside the box with your finger", style: TextStyle(color: Colors.white70))),
      ]),
    ]);
  }
}
