import 'dart:convert';
import 'dart:typed_data';

import 'package:freezed_annotation/freezed_annotation.dart';

part 'cheque.freezed.dart';
part 'cheque.g.dart';

Uint8List? _imageDataFromJson(String? value) {
  if (value == null) {
    return null;
  }

  return base64Decode(value);
}

String? _imageDataToJson(Uint8List? value) {
  if (value == null) {
    return null;
  }

  return base64Encode(value);
}

enum ChequeStatus { issued, registered, cancelled }

@freezed
abstract class Cheque with _$Cheque {
  const factory Cheque({
    required int id,
    String? serverUuid,
    required int companyId,
    required int bankAccountId,
    required String chequeNumber,
    required int amountRial,
    required DateTime issueDate,
    required DateTime dueDate,
    required ChequeStatus status,
    required bool isRegisteredInSayad,
    String? sayadId,
    String? receiverName,
    String? description,
    DateTime? archivedAt,
    DateTime? deleteRequestedAt,
    @JsonKey(fromJson: _imageDataFromJson, toJson: _imageDataToJson)
    Uint8List? imageData,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Cheque;

  factory Cheque.fromJson(Map<String, dynamic> json) => _$ChequeFromJson(json);
}
