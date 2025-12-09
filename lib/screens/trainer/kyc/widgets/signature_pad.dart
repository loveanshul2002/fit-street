import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:signature/signature.dart';

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
  bool _saved = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _export() async {
    final bytes = await _controller.toPngBytes();
    widget.onBytes(bytes);
    if (mounted) {
      setState(() => _saved = true);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Signature saved")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white70)),
        height: 180,
        child:
            Signature(controller: _controller, backgroundColor: Colors.white),
      ),
      const SizedBox(height: 8),
      Row(children: [
        OutlinedButton(
            onPressed: () {
              _controller.clear();
              if (mounted) setState(() => _saved = false);
            },
            child: const Text("Clear")),
        const SizedBox(width: 12),
        ElevatedButton(
            onPressed: _export,
            child: Text(_saved ? "Saved" : "Save Signature")),
        const SizedBox(width: 12),
      ]),
    ]);
  }
}
