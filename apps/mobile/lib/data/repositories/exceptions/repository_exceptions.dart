abstract class RepositoryException implements Exception {
  const RepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

class DuplicateCompanyNameException extends RepositoryException {
  const DuplicateCompanyNameException()
      : super('A company with this name already exists.');
}

class InvalidNationalIdException extends RepositoryException {
  const InvalidNationalIdException()
      : super('National ID is invalid.');
}

class InvalidEconomicCodeException extends RepositoryException {
  const InvalidEconomicCodeException()
      : super('Economic code is invalid.');
}

class CompanyNotFoundException extends RepositoryException {
  const CompanyNotFoundException()
      : super('Company not found.');
}