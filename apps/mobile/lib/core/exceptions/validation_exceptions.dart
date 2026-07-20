abstract class ValidationException implements Exception {
  const ValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class EmptyCompanyNameException extends ValidationException {
  const EmptyCompanyNameException()
      : super('Company name cannot be empty.');
}

class CompanyNameTooLongException extends ValidationException {
  const CompanyNameTooLongException()
      : super('Company name cannot exceed 100 characters.');
}

class InvalidNationalIdException extends ValidationException {
  const InvalidNationalIdException()
      : super('National ID must be exactly 11 digits.');
}

class InvalidEconomicCodeException extends ValidationException {
  const InvalidEconomicCodeException()
      : super('Economic code must be between 10 and 16 digits.');
}

class CompanyNotesTooLongException extends ValidationException {
  const CompanyNotesTooLongException()
      : super('Company notes cannot exceed 500 characters.');
}
