// lib/screens/trainer/kyc/widgets/upload_image_field.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class UploadImageField extends StatefulWidget {
  final String label;
  final String? initialPath;
  final void Function(String path) onPicked;
  final bool required;

  const UploadImageField({
    super.key,
    required this.label,
    this.initialPath,
    required this.onPicked,
    this.required = false,
  });

  @override
  State<UploadImageField> createState() => _UploadImageFieldState();
}

class _UploadImageFieldState extends State<UploadImageField> {
  String? _path;

  @override
  void initState() {
    super.initState();
    _path = widget.initialPath;
  }

  Future<void> _pick() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _path = picked.path);
      widget.onPicked(picked.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label,
            style: const TextStyle(color: Colors.white70, fontSize: 14)),
        const SizedBox(height: 8),
        _path == null
            ? InkWell(
          onTap: _pick,
          child: Container(
            height: 140,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white24),
            ),
            child: const Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.upload_file, color: Colors.white70),
                  SizedBox(width: 6),
                  Text("Tap to upload",
                      style: TextStyle(color: Colors.white70)),
                ],
              ),
            ),
          ),
        )
            : Stack(
          children: [
            Container(
              height: 140,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white24),
                image: DecorationImage(
                  image: FileImage(File(_path!)),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Positioned(
              top: 6,
              right: 6,
              child: InkWell(
                onTap: () {
                  setState(() => _path = null);
                  widget.onPicked('');
                },
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(6),
                  child: const Icon(Icons.close,
                      color: Colors.white, size: 18),
                ),
              ),
            ),
          ],
        ),
        if (widget.required && _path == null)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text("Required",
                style: TextStyle(color: Colors.redAccent, fontSize: 12)),
          ),
        const SizedBox(height: 12),
      ],
    );
  }
}
