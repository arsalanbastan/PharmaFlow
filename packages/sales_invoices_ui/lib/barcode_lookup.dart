/// Normalizes an EAN / GTIN / GS1 DataMatrix scan to catalog lookup keys.
///
/// Never guesses an identity from arbitrary numbers inside a serialized code:
/// only AI (01) and explicit GTIN labels qualify as GS1 identifiers.
class BarcodeLookup {
  const BarcodeLookup(this.displayCode, this.candidates);

  /// Product identifier shown to the user (13 digits for a zero-padded GTIN-14).
  final String displayCode;

  /// Database lookup keys in priority order, including the other GTIN width.
  final List<String> candidates;
}

String _englishDigits(String value) => value.replaceAllMapped(
      RegExp(r'[\u06F0-\u06F9\u0660-\u0669]'),
      (match) {
        final unit = match.group(0)!.codeUnitAt(0);
        return '${unit >= 0x06F0 ? unit - 0x06F0 : unit - 0x0660}';
      },
    );

bool _validGtin(String value) {
  if (!RegExp(r'^\d{13,14}$').hasMatch(value)) return false;
  var sum = 0;
  for (var i = value.length - 2, weight = 3; i >= 0; i--, weight = 4 - weight) {
    sum += int.parse(value[i]) * weight;
  }
  return (10 - sum % 10) % 10 == int.parse(value[value.length - 1]);
}

BarcodeLookup _lookupForCode(String code) {
  // AI (01) encodes GTIN-13 as 14 digits with a leading zero.
  final display = code.length == 14 && code.startsWith('0') ? code.substring(1) : code;
  return BarcodeLookup(display, {
    display,
    code,
    if (code.length == 13) '0$code',
  }.toList());
}

BarcodeLookup? parseBarcodeLookup(String input) {
  final raw = _englishDigits(input.trim());
  if (raw.isEmpty) return null;
  final noSymbologyPrefix = raw.replaceFirst(RegExp(r'^\]d2'), '');

  // Human-readable GS1 form: (01)06267429502049(17)261231(21)...
  // Also handles labels that explicitly name GTIN/GTN.
  final labelled = RegExp(r'\(01\)\s*(\d{14})|\b(?:GTIN|GTN)\s*[:=\s-]*\s*(\d{13,14})',
          caseSensitive: false)
      .firstMatch(noSymbologyPrefix);
  if (labelled != null) {
    final gtin = labelled.group(1) ?? labelled.group(2)!;
    return _validGtin(gtin) ? _lookupForCode(gtin) : null;
  }

  // Machine-readable GS1 DataMatrix: ]d2 01 + 14 GTIN digits + other AIs.
  // A few TTAC labels place ASCII GS (FNC1) between their field markers.
  final gs1 = RegExp(r'^01[\u001d\u001e]?\s*(\d{14})').firstMatch(noSymbologyPrefix);
  if (gs1 != null) {
    final gtin = gs1.group(1)!;
    return _validGtin(gtin) ? _lookupForCode(gtin) : null;
  }

  // Standalone EAN-13, GTIN-14 or other numeric retail barcode.
  if (RegExp(r'^\d{8,14}$').hasMatch(noSymbologyPrefix)) {
    return _lookupForCode(noSymbologyPrefix);
  }

  // Do not mistake serialized UID/LOT/EXP fields for product barcodes.
  if (raw.contains('\u001d') || raw.contains('\u001e') || raw.startsWith(']d2') ||
      RegExp(r'\b(?:UID|LOT|EXP)\s*:', caseSensitive: false).hasMatch(raw)) {
    return null;
  }

  // Preserve existing behavior for simple alphanumeric retail codes and
  // human-entered catalog search terms.
  if (raw.length <= 80 && !raw.contains(RegExp(r'[\r\n\x00-\x1f]'))) {
    return BarcodeLookup(raw, [raw]);
  }
  return null;
}
