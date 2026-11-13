String normalizePersianDigitsToEnglish(String value) {
  const arabicIndic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
  const persian = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];

  var result = value;
  for (var i = 0; i < 10; i++) {
    result = result.replaceAll(arabicIndic[i], i.toString());
    result = result.replaceAll(persian[i], i.toString());
  }
  return result;
}

String toPersianDigits(String value) {
  const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
  const persian = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];

  var result = value;
  for (var i = 0; i < 10; i++) {
    result = result.replaceAll(english[i], persian[i]);
  }
  return result;
}

String extractEnglishDigits(String value) {
  final normalized = normalizePersianDigitsToEnglish(value);
  return normalized.replaceAll(RegExp(r'[^0-9]'), '');
}

String? amountToPersianWords(int? amountRial) {
  if (amountRial == null || amountRial <= 0) {
    return null;
  }

  final amountToman = amountRial ~/ 10;
  if (amountToman <= 0) {
    return null;
  }

  return '${_numberToWords(amountToman)} تومان';
}

String _numberToWords(int value) {
  if (value == 0) {
    return 'صفر';
  }

  const thousands = ['', 'هزار', 'میلیون', 'میلیارد', 'تریلیون'];
  final parts = <String>[];
  var remainder = value;
  var thousandIndex = 0;

  while (remainder > 0) {
    final chunk = remainder % 1000;
    if (chunk > 0) {
      final chunkWord = _threeDigitsToWords(chunk);
      final suffix = thousands[thousandIndex];
      parts.add(suffix.isEmpty ? chunkWord : '$chunkWord $suffix');
    }
    remainder ~/= 1000;
    thousandIndex++;
  }

  return parts.reversed.join(' و ');
}

String _threeDigitsToWords(int value) {
  const ones = [
    '',
    'یک',
    'دو',
    'سه',
    'چهار',
    'پنج',
    'شش',
    'هفت',
    'هشت',
    'نه',
  ];

  const teens = [
    'ده',
    'یازده',
    'دوازده',
    'سیزده',
    'چهارده',
    'پانزده',
    'شانزده',
    'هفده',
    'هجده',
    'نوزده',
  ];

  const tens = [
    '',
    '',
    'بیست',
    'سی',
    'چهل',
    'پنجاه',
    'شصت',
    'هفتاد',
    'هشتاد',
    'نود',
  ];

  const hundreds = [
    '',
    'صد',
    'دویست',
    'سیصد',
    'چهارصد',
    'پانصد',
    'ششصد',
    'هفتصد',
    'هشتصد',
    'نهصد',
  ];

  final parts = <String>[];
  final h = value ~/ 100;
  final remainder = value % 100;

  if (h > 0) {
    parts.add(hundreds[h]);
  }

  if (remainder >= 10 && remainder <= 19) {
    parts.add(teens[remainder - 10]);
  } else {
    final t = remainder ~/ 10;
    final o = remainder % 10;

    if (t > 0) {
      parts.add(tens[t]);
    }

    if (o > 0) {
      parts.add(ones[o]);
    }
  }

  return parts.join(' و ');
}