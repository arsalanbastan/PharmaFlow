import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaflow_staff/features/sales_invoices/barcode_lookup.dart';

void main() {
  const product = '6267429502049';
  const padded = '06267429502049';

  test('EAN-13 returns lookup with optional GTIN-14 padding', () {
    final lookup = parseBarcodeLookup(product)!;
    expect(lookup.displayCode, product);
    expect(lookup.candidates, [product, padded]);
  });

  test('GS1 DataMatrix with UID, LOT, and EXP uses AI 01 only', () {
    final raw = ']d201${padded}1726123121ABC123\u001d10LOT55';
    final lookup = parseBarcodeLookup(raw)!;
    expect(lookup.displayCode, product);
    expect(lookup.candidates, [product, padded]);
  });

  test('Human readable GS1 AIs', () {
    final lookup = parseBarcodeLookup('(01)$padded(17)261231(10)B123')!;
    expect(lookup.displayCode, product);
  });

  test('Textual GTIN and Persian digit input', () {
    expect(parseBarcodeLookup('GTIN: $padded')!.displayCode, product);
    expect(parseBarcodeLookup('۶۲۶۷۴۲۹۵۰۲۰۴۹')!.displayCode, product);
  });

  test('Invalid AI 01 checksum does not guess a product', () {
    expect(parseBarcodeLookup(']d20106267429502048\u001d21UID999'), isNull);
  });

  test('Serialized UID/EXP fields without GTIN are not product codes', () {
    expect(parseBarcodeLookup('UID: 123456 LOT: 123 EXP: 261231'), isNull);
  });

  test('Manual catalog search terms remain usable', () {
    expect(parseBarcodeLookup('استامینوفن')!.candidates, ['استامینوفن']);
  });
}
