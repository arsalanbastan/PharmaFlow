import 'package:shamsi_date/shamsi_date.dart';
import '../../shared/widgets/date_picker/pharmaflow_date_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:price_increases_ui/price_increases_page.dart';
import '../../core/auth/manager_app_auth_gate.dart';
import '../settings/presentation/providers/communication_settings_provider.dart';

class ManagerPriceIncreasesPage extends ConsumerWidget {
  const ManagerPriceIncreasesPage({super.key, this.openCreate = false});
  final bool openCreate;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ManagerAccessScope.of(context).user;
    return PriceIncreasesPage(
      pickDate: (context, initial) => PharmaFlowDatePicker.show(
        context: context,
        initialDate: initial,
        firstDate: Jalali(1390, 1, 1),
        lastDate: Jalali(1450, 12, 29),
      ),
      openCreate: openCreate,
      manager: user.role == 'MANAGER',
      canConfirm: user.permissions.canCreateOrders,
      request: (path, body) async {
        final api = ref.read(apiClientProvider);
        final patch = path.startsWith('PATCH:');
        final uri = Uri.parse(patch ? path.substring(6) : path);
        final result = body == null
            ? await api.get(
                uri.path,
                queryParameters: uri.hasQuery ? uri.queryParameters : null,
              )
            : patch
            ? await api.patch(uri.path, body: body)
            : await api.post(
                uri.path,
                body: body,
                timeout: uri.path.endsWith('/extract-image')
                    ? const Duration(seconds: 75)
                    : null,
              );
        return Map<String, dynamic>.from(result as Map);
      },
    );
  }
}
