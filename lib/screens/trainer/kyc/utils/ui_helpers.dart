import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

InputDecoration glassInput() => InputDecoration(
  filled: true, fillColor: Colors.white.withOpacity(0.10),
  enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.white.withOpacity(0.25))),
  focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.white)),
);

String? req(String? v) => notEmpty(v) ? null : "Required";
bool notEmpty(String? v) => v != null && v.trim().isNotEmpty;

Widget field(
    String label,
    TextEditingController c, {
      String? Function(String?)? validator,
      TextInputType? keyboardType,
      bool readOnly = false,
      List<TextInputFormatter>? inputFormatters,
      int? maxLength,
      void Function(String)? onChanged,
    }) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextFormField(
      controller: c, readOnly: readOnly,
      style: const TextStyle(color: Colors.white),
      validator: validator, keyboardType: keyboardType,
      inputFormatters: inputFormatters, maxLength: maxLength, onChanged: onChanged,
      decoration: glassInput().copyWith(
          labelText: label, labelStyle: const TextStyle(color: Colors.white70), counterText: ""),
    ),
  );
}

Widget uploadStub(String label, void Function(String path) onSaved) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: InkWell(
      onTap: () { onSaved("demo_path.jpg"); },
      child: InputDecorator(
        decoration: glassInput().copyWith(labelText: label, labelStyle: const TextStyle(color: Colors.white70)),
        child: const Row(children: [
          Icon(Icons.upload, color: Colors.white70), SizedBox(width: 8),
          Text("Tap to upload", style: TextStyle(color: Colors.white70))]),
      ),
    ),
  );
}

// Simple section headers
class Section extends StatelessWidget {
  final String text;
  const Section(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
  );
}

class SubTitle extends StatelessWidget {
  final String text;
  const SubTitle(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8, top: 8),
    child: Text(text, style: const TextStyle(color: Colors.white70)),
  );
}
