class CompanyNameNormalizer {
  CompanyNameNormalizer._();

  static const List<String> _prefixes = [
    'شرکت',
    'پخش',
    'دارویی',
    'داروئی',
    'گروه',
    'بازرگانی',
    'تعاونی',
  ];

  static String normalize(String value) {
    var text = value.trim();

    // تبدیل عربی به فارسی
    text = text
        .replaceAll('ي', 'ی')
        .replaceAll('ك', 'ک');

    // حذف نیم‌فاصله
    text = text.replaceAll('\u200c', ' ');

    // حذف فاصله‌های اضافه
    text = text.replaceAll(RegExp(r'\s+'), ' ');

    // حذف پیشوندها
    for (final prefix in _prefixes) {
      if (text.startsWith('$prefix ')) {
        text = text.substring(prefix.length).trim();
      }
    }

    return text.toLowerCase();
  }

  static bool isSimilar(
    String first,
    String second,
  ) {
    return normalize(first) == normalize(second);
  }
}