import 'dart:math';

final Random _secureUuidRandom = Random.secure();

String generateUuidV4() {
  final bytes = List<int>.generate(
    16,
    (_) => _secureUuidRandom.nextInt(256),
    growable: false,
  );

  // RFC 4122 / UUID v4
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;

  String byteHex(int value) => value.toRadixString(16).padLeft(2, '0');

  final hex = bytes.map(byteHex).toList(growable: false);

  return '${hex[0]}${hex[1]}${hex[2]}${hex[3]}-'
      '${hex[4]}${hex[5]}-'
      '${hex[6]}${hex[7]}-'
      '${hex[8]}${hex[9]}-'
      '${hex[10]}${hex[11]}${hex[12]}${hex[13]}${hex[14]}${hex[15]}';
}
