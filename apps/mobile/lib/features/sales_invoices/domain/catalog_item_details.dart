/// Formats only details actually present in the catalog. Arsen does not provide
/// separate dose/volume columns, so those values are extracted from item names.
String catalogItemDetails({
  required String category,
  required String name,
  String? alternateName,
  String? shape,
  String? unit,
  int? packetQuantity,
}) {
  final details = <String>[];
  if (category == 'DRUG' && shape != null && shape.trim().isNotEmpty) {
    details.add('شکل: ${shape.trim()}');
  }

  final names = [name, if (alternateName != null) alternateName];
  final measure = RegExp(
    r'([0-9۰-۹٠-٩]+(?:[.,٫/][0-9۰-۹٠-٩]+)?)\s*(میلی\s*گرم|میلی\s*لیتر|میکرو\s*گرم|گرمی|گرم|لیتری|لیتر|mg|mcg|µg|g|ml|l|cc|٪|%)',
    caseSensitive: false,
  );
  final matches = <String>{};
  for (final text in names) {
    for (final match in measure.allMatches(text)) {
      matches.add(match.group(0)!.trim());
    }
  }
  if (matches.isNotEmpty) {
    details.add('${category == 'DRUG' ? 'دوز/حجم' : 'حجم/وزن'}: ${matches.join('، ')}');
  } else if (category == 'DRUG') {
    // A bare number may be the dose, but could also be a package count.
    final bareNumber = RegExp(r'(?<![0-9۰-۹٠-٩])([0-9۰-۹٠-٩]{2,})(?![0-9۰-۹٠-٩])')
        .firstMatch(name)?.group(1);
    if (bareNumber != null) details.add('عدد درج‌شده در نام: $bareNumber');
  }
  if (packetQuantity != null && packetQuantity > 1) {
    details.add('بسته: $packetQuantity');
  }
  if (unit != null && unit.trim().isNotEmpty &&
      unit.trim() != 'عدد' && unit.trim() != 'بسته') {
    details.add('واحد: ${unit.trim()}');
  }
  return details.isEmpty ? 'مشخصات تکمیلی در کاتالوگ ثبت نشده' : details.join(' • ');
}

enum CatalogSortField { relevance, dose, shape }

double? catalogSortDose(String name, {String? alternateName}) {
  final text = '$name ${alternateName ?? ''}';
  final match = RegExp(
    r'([0-9۰-۹٠-٩]+(?:[.,٫][0-9۰-۹٠-٩]+)?)\s*(میکرو\s*گرم|میلی\s*گرم|میلی\s*لیتر|گرمی|گرم|لیتر|mg|mcg|µg|g|ml|l|cc|٪|%)?',
    caseSensitive: false,
  ).firstMatch(text);
  if (match == null) return null;
  var raw = match.group(1)!;
  const persian = '۰۱۲۳۴۵۶۷۸۹';
  const arabic = '٠١٢٣٤٥٦٧٨٩';
  for (var i = 0; i < 10; i++) {
    raw = raw.replaceAll(persian[i], '$i').replaceAll(arabic[i], '$i');
  }
  final number = double.tryParse(raw.replaceAll('٫', '.').replaceAll(',', '.'));
  if (number == null) return null;
  final unit = (match.group(2) ?? '').replaceAll(' ', '').toLowerCase();
  if (unit == 'g' || unit == 'گرم' || unit == 'گرمی') return number * 1000;
  if (unit == 'mcg' || unit == 'µg' || unit == 'میکروگرم') return number / 1000;
  if (unit == 'l' || unit == 'لیتر') return number * 1000;
  return number;
}

List<T> sortCatalogMatches<T>(
  List<T> items, {
  required CatalogSortField field,
  required bool descending,
  required String Function(T) name,
  required String? Function(T) shape,
  String? Function(T)? alternateName,
}) {
  if (field == CatalogSortField.relevance) return List<T>.of(items);
  final indexed = items.asMap().entries.toList();
  indexed.sort((a, b) {
    final left = a.value, right = b.value;
    int comparison;
    if (field == CatalogSortField.dose) {
      final first = catalogSortDose(name(left), alternateName: alternateName?.call(left));
      final second = catalogSortDose(name(right), alternateName: alternateName?.call(right));
      if (first == null && second == null) return a.key.compareTo(b.key);
      if (first == null) return 1;
      if (second == null) return -1;
      comparison = first.compareTo(second);
    } else {
      final first = shape(left)?.trim() ?? '';
      final second = shape(right)?.trim() ?? '';
      if (first.isEmpty && second.isEmpty) return a.key.compareTo(b.key);
      if (first.isEmpty) return 1;
      if (second.isEmpty) return -1;
      comparison = first.compareTo(second);
    }
    return comparison == 0 ? a.key.compareTo(b.key) : (descending ? -comparison : comparison);
  });
  return indexed.map((entry) => entry.value).toList();
}
