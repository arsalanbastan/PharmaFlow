import 'package:freezed_annotation/freezed_annotation.dart';

part 'company.freezed.dart';
part 'company.g.dart';

@freezed
abstract class Company with _$Company {
  const factory Company({
    int? id,
    required String name,
    String? nationalId,
    String? economicCode,
    String? notes,
    DateTime? archivedAt,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Company;

  factory Company.fromJson(Map<String, dynamic> json) =>
      _$CompanyFromJson(json);
}