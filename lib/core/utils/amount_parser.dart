/// Parses user-typed monetary amounts robustly:
/// trims whitespace, converts Arabic-Indic (٠-٩) and Persian (۰-۹) digits
/// to Latin digits, and returns null when the value is not a valid number.
/// Without this, keyboards producing non-Latin digits make payments fail
/// silently (`double.tryParse` returns null and dialogs just stay open).
double? parseAmount(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return null;
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    final code = s.codeUnitAt(i);
    if (code >= 0x0660 && code <= 0x0669) {
      // Arabic-Indic digits ٠-٩.
      buf.writeCharCode(0x30 + (code - 0x0660));
    } else if (code >= 0x06F0 && code <= 0x06F9) {
      // Extended Arabic-Indic (Persian/Urdu) digits ۰-۹.
      buf.writeCharCode(0x30 + (code - 0x06F0));
    } else {
      buf.writeCharCode(code);
    }
  }
  return double.tryParse(buf.toString());
}
