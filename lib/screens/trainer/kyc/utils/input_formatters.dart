  import 'package:flutter/services.dart';


// Uppercase
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) =>
      newValue.copyWith(text: newValue.text.toUpperCase());
}

// Aadhaar -> "XXXX XXXX XXXX"
class AadhaarFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue nv) {
    final digits = nv.text.replaceAll(" ", "");
    final b = StringBuffer();
    for (int i=0;i<digits.length;i++){ b.write(digits[i]); if (i==3 || i==7) b.write(' '); }
    final t = b.toString();
    return TextEditingValue(text: t, selection: TextSelection.collapsed(offset: t.length));
  }
}

  /// Auto adds `/` in DD/MM/YYYY format while typing.
  class DateSlashFormatter extends TextInputFormatter {
    @override
    TextEditingValue formatEditUpdate(
        TextEditingValue oldValue, TextEditingValue newValue) {
      var text = newValue.text.replaceAll('/', '');

      if (text.length > 8) {
        text = text.substring(0, 8); // limit to 8 digits
      }

      var newText = '';
      for (int i = 0; i < text.length; i++) {
        newText += text[i];
        if (i == 1 || i == 3) newText += '/'; // add slash after DD and MM
      }

      return TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newText.length),
      );
    }
  }

// Date DD/MM/YYYY helpers
List<TextInputFormatter> dateDDMMYYYYFormatters() => [
  FilteringTextInputFormatter.allow(RegExp(r'[\d/]')),
  LengthLimitingTextInputFormatter(10),
];
