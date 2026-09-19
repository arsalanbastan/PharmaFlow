import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'cheque_text_utils.dart';

class ChequeDigitOnlyFormatter extends TextInputFormatter {
  const ChequeDigitOnlyFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final normalized = normalizePersianDigitsToEnglish(newValue.text);
    final selectionOffset = newValue.selection.baseOffset;
    final selectionClamped = selectionOffset.clamp(0, normalized.length);

    final buffer = StringBuffer();
    var digitCursor = 0;

    for (var i = 0; i < normalized.length; i++) {
      final char = normalized[i];
      final isDigit = char.codeUnitAt(0) >= 48 && char.codeUnitAt(0) <= 57;
      if (isDigit) {
        buffer.write(char);
        if (i < selectionClamped) {
          digitCursor++;
        }
      }
    }

    final text = buffer.toString();

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: digitCursor.clamp(0, text.length)),
    );
  }
}

class ChequeAmountFormatter extends TextInputFormatter {
  const ChequeAmountFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final normalized = normalizePersianDigitsToEnglish(newValue.text);
    final selectionOffset = newValue.selection.baseOffset;
    final selectionClamped = selectionOffset.clamp(0, normalized.length);

    final digitBuffer = StringBuffer();
    var digitCursor = 0;

    for (var i = 0; i < normalized.length; i++) {
      final char = normalized[i];
      final isDigit = char.codeUnitAt(0) >= 48 && char.codeUnitAt(0) <= 57;
      if (isDigit) {
        digitBuffer.write(char);
        if (i < selectionClamped) {
          digitCursor++;
        }
      }
    }

    final digits = digitBuffer.toString();

    if (digits.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    final parsed = int.tryParse(digits);
    if (parsed == null) {
      return oldValue;
    }

    final formatted = NumberFormat.decimalPattern('en').format(parsed);
    final caret = _caretPositionFromDigitIndex(formatted, digitCursor);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: caret),
    );
  }
}

class SayadIdFormatter extends TextInputFormatter {
  const SayadIdFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final normalized = normalizePersianDigitsToEnglish(newValue.text);
    final selectionOffset = newValue.selection.baseOffset;
    final selectionClamped = selectionOffset.clamp(0, normalized.length);

    final digitBuffer = StringBuffer();
    var digitCursor = 0;

    for (var i = 0; i < normalized.length; i++) {
      final char = normalized[i];
      final isDigit = char.codeUnitAt(0) >= 48 && char.codeUnitAt(0) <= 57;
      if (isDigit) {
        if (digitBuffer.length >= 16) {
          continue;
        }

        digitBuffer.write(char);
        if (i < selectionClamped) {
          digitCursor++;
        }
      }
    }

    final digits = digitBuffer.toString();
    final grouped = _groupDigitsByFour(digits);
    final caret = _caretPositionFromDigitIndex(grouped, digitCursor);

    return TextEditingValue(
      text: grouped,
      selection: TextSelection.collapsed(offset: caret),
    );
  }
}

String _groupDigitsByFour(String digits) {
  if (digits.isEmpty) {
    return '';
  }

  final parts = <String>[];
  for (var i = 0; i < digits.length; i += 4) {
    final end = (i + 4) > digits.length ? digits.length : i + 4;
    parts.add(digits.substring(i, end));
  }

  return parts.join(' ');
}

int _caretPositionFromDigitIndex(String formatted, int digitIndex) {
  if (digitIndex <= 0) {
    return 0;
  }

  var seenDigits = 0;
  for (var i = 0; i < formatted.length; i++) {
    final char = formatted[i];
    final isDigit = char.codeUnitAt(0) >= 48 && char.codeUnitAt(0) <= 57;

    if (isDigit) {
      seenDigits++;
      if (seenDigits == digitIndex) {
        return i + 1;
      }
    }
  }

  return formatted.length;
}