import '../../data/models/company.dart';
import '../exceptions/validation_exceptions.dart';

class CompanyValidator {
  const CompanyValidator._();

  static Company validate(Company company) {
    final name = _normalize(company.name);

    if (name.isEmpty) {
      throw const EmptyCompanyNameException();
    }

    if (name.length > 100) {
      throw const CompanyNameTooLongException();
    }

    final nationalId = company.nationalId?.trim();
    if (nationalId != null && nationalId.isNotEmpty) {
      if (!RegExp(r'^\d{11}$').hasMatch(nationalId)) {
        throw const InvalidNationalIdException();
      }
    }

    final economicCode = company.economicCode?.trim();
    if (economicCode != null && economicCode.isNotEmpty) {
      if (!RegExp(r'^\d{10,16}$').hasMatch(economicCode)) {
        throw const InvalidEconomicCodeException();
      }
    }

    final notes = company.notes?.trim();
    if (notes != null && notes.length > 500) {
      throw const CompanyNotesTooLongException();
    }

    return company.copyWith(
      name: name,
      nationalId: nationalId?.isEmpty == true ? null : nationalId,
      economicCode: economicCode?.isEmpty == true ? null : economicCode,
      notes: notes?.isEmpty == true ? null : notes,
    );
  }

  static String _normalize(String value) =>
      value.trim().replaceAll(RegExp(r'\s+'), ' ');
}
