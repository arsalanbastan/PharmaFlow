import 'package:flutter/material.dart';

import 'cheque_form_page.dart';

class ChequeDetailsPage extends StatelessWidget {
  const ChequeDetailsPage({super.key, required this.chequeId});

  final int chequeId;

  @override
  Widget build(BuildContext context) {
    return ChequeFormPage(chequeId: chequeId, pageTitle: 'جزئیات چک');
  }
}
