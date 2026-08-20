import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pharmaflow/features/cheques/presentation/utils/cheque_input_formatters.dart';
import 'package:pharmaflow/features/cheques/presentation/utils/cheque_text_utils.dart';

void main() {
  test('amount formatter groups digits in thousands while typing', () {
    const formatter = ChequeAmountFormatter();
    const raw = TextEditingValue(
      text: '123456789',
      selection: TextSelection.collapsed(offset: 9),
    );

    final formatted = formatter.formatEditUpdate(const TextEditingValue(), raw);

    expect(formatted.text, '123,456,789');
  });

  test('rial amount is divided by ten and written in Persian toman words', () {
    expect(
      amountToPersianWords(1234560),
      'صد و بیست و سه هزار و چهارصد و پنجاه و شش تومان',
    );
  });
}
