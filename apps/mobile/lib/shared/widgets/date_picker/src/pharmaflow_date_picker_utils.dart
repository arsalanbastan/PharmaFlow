import 'package:shamsi_date/shamsi_date.dart';

const List<String> jalaliMonthNames = <String>[
  'فروردین',
  'اردیبهشت',
  'خرداد',
  'تیر',
  'مرداد',
  'شهریور',
  'مهر',
  'آبان',
  'آذر',
  'دی',
  'بهمن',
  'اسفند',
];

const List<String> jalaliWeekdayNames = <String>[
  'ش',
  'ی',
  'د',
  'س',
  'چ',
  'پ',
  'ج',
];

Jalali toDateOnly(Jalali date) => Jalali(date.year, date.month, date.day);

int compareJalali(Jalali a, Jalali b) {
  if (a.year != b.year) {
    return a.year.compareTo(b.year);
  }
  if (a.month != b.month) {
    return a.month.compareTo(b.month);
  }
  return a.day.compareTo(b.day);
}

bool isBeforeJalali(Jalali a, Jalali b) => compareJalali(a, b) < 0;
bool isAfterJalali(Jalali a, Jalali b) => compareJalali(a, b) > 0;
bool isSameJalali(Jalali a, Jalali b) => compareJalali(a, b) == 0;

String toPersianDigits(String input) {
  const english = <String>['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
  const persian = <String>['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];

  var result = input;
  for (var i = 0; i < english.length; i++) {
    result = result.replaceAll(english[i], persian[i]);
  }
  return result;
}

String formatJalaliYmd(Jalali date) {
  final raw = '${date.year.toString().padLeft(4, '0')}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  return toPersianDigits(raw);
}
