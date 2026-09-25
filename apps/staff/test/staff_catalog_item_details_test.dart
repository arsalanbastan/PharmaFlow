import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaflow_staff/features/sales_invoices/catalog_item_details.dart';

void main() {
  test('tablet and suppository show their own shape and strength', () {
    expect(catalogItemDetails(category: 'DRUG', name: 'استامینوفن ۵۰۰ میلی گرم',
        shape: 'قرص'), contains('شکل: قرص • دوز/حجم: ۵۰۰ میلی گرم'));
    expect(catalogItemDetails(category: 'DRUG', name: 'استامینوفن ۳۲۵ میلی گرم',
        shape: 'شیاف'), contains('شکل: شیاف • دوز/حجم: ۳۲۵ میلی گرم'));
  });
  test('goods retain different package weights', () {
    expect(catalogItemDetails(category: 'GOODS', name: 'کالاندولا ۱۵ گرمی'),
        contains('حجم/وزن: ۱۵ گرمی'));
    expect(catalogItemDetails(category: 'GOODS', name: 'کالاندولا ۳۰ گرمی'),
        contains('حجم/وزن: ۳۰ گرمی'));
  });
  test('does not guess the unit for a bare number', () {
    expect(catalogItemDetails(category: 'DRUG', name: 'استامینوفن 500',
        shape: 'قرص'), contains('عدد درج‌شده در نام: 500'));
  });

  test('sorts all selected search matches by numeric dose, then by shape', () {
  final rows = [
    (name: 'استامینوفن ۵۰۰ میلی گرم', shape: 'قرص'),
    (name: 'استامینوفن ۳۲۵ میلی گرم', shape: 'شیاف'),
    (name: 'استامینوفن ۱۰۰ میلی گرم', shape: 'قرص'),
  ];
  final doses = sortCatalogMatches(rows, field: CatalogSortField.dose,
      descending: false, name: (row) => row.name, shape: (row) => row.shape);
  expect(doses.map((row) => row.name), [rows[2].name, rows[1].name, rows[0].name]);
  final shapes = sortCatalogMatches(rows, field: CatalogSortField.shape,
      descending: false, name: (row) => row.name, shape: (row) => row.shape);
  expect(shapes.first.shape, 'شیاف');
});
}
