import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/models/company.dart';
import 'company_provider.dart';

final companyDuplicateProvider =
    FutureProvider.family<List<Company>, String>(
  (ref, companyName) async {
    final notifier = ref.read(companyProvider.notifier);

    if (companyName.trim().isEmpty) {
      return [];
    }

    return notifier.findSimilar(companyName);
  },
);