import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:price_increases_ui/price_increases_page.dart';
import '../../core/auth/manager_app_auth_gate.dart';
import '../settings/presentation/providers/communication_settings_provider.dart';

class ManagerPriceIncreasesPage extends ConsumerWidget {
  const ManagerPriceIncreasesPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ManagerAccessScope.of(context).user;
    return PriceIncreasesPage(
      manager: user.role == 'MANAGER',
      canConfirm: user.permissions.canCreateOrders,
      request: (path, body) async {
        final api = ref.read(apiClientProvider);
        final result = body == null
            ? await api.get('/api/v1$path')
            : path.startsWith('PATCH:')
                ? await api.patch('/api/v1${path.substring(6)}', body: body)
                : await api.post('/api/v1$path', body: body);
        return Map<String, dynamic>.from(result as Map);
      },
    );
  }
}
