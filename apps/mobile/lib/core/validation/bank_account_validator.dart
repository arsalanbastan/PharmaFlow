class BankAccountValidator {
  const BankAccountValidator._();

  static String normalizeText(String value) {
    return value.trim().replaceAll(
      RegExp(r'\s+'),
      ' ',
    );
  }

  static String? normalizeOptionalText(String value) {
    final normalized = normalizeText(value);
    return normalized.isEmpty ? null : normalized;
  }

  static String normalizeDigits(String value) {
    return value.replaceAll(RegExp(r'\D'), '');
  }

  static String normalizeIban(String value) {
    return value.trim().toUpperCase();
  }

  static String? validateBankName(String? value) {
    if (value == null || normalizeText(value).isEmpty) {
      return 'نام بانک الزامی است.';
    }

    return null;
  }

  static String? validateAccountTitle(String? value) {
    if (value == null || normalizeText(value).isEmpty) {
      return 'عنوان حساب الزامی است.';
    }

    return null;
  }

  static String? validateAccountHolder(String? value) {
    if (value == null || normalizeText(value).isEmpty) {
      return 'صاحب حساب الزامی است.';
    }

    return null;
  }

  static String? validateAccountNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    final digits = normalizeDigits(value);

    if (digits.isEmpty) {
      return 'شماره حساب معتبر نیست.';
    }

    return null;
  }

  static String? validateCardNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    final digits = normalizeDigits(value);

    if (digits.length != 16) {
      return 'شماره کارت باید ۱۶ رقم باشد.';
    }

    return null;
  }

  static String? validateIban(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    final iban = normalizeIban(value);

    if (!RegExp(r'^IR\d{24}$').hasMatch(iban)) {
      return 'شماره شبا باید با IR شروع شود و ۲۴ رقم داشته باشد.';
    }

    return null;
  }
}