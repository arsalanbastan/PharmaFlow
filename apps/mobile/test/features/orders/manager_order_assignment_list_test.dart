import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaflow/core/network/api_client.dart';
import 'package:pharmaflow/features/orders/data/manager_orders_repository.dart';
import 'package:pharmaflow/features/orders/domain/manager_order.dart';
import 'package:pharmaflow/features/orders/presentation/pages/orders_dashboard_page.dart';

class _OrdersRepository extends ManagerOrdersRepository {
  _OrdersRepository(this.orders) : super(ApiClient());

  final List<ManagerOrder> orders;
  int loads = 0;

  @override
  Future<List<ManagerOrder>> getAll({String? status, String? category}) async {
    loads++;
    return orders;
  }
}

ManagerOrder _order(String id, {String status = 'PENDING'}) => ManagerOrder(
  id: id,
  category: 'DRUG',
  itemText: 'داروی تست',
  status: status,
  possibleDuplicate: false,
  requestedByName: 'مریم',
  createdAt: DateTime.utc(2026, 11, 13),
);

void main() {
  test(
    'confirmed assignments update the existing list without a reload',
    () async {
      final first = _order('first');
      final second = _order('second');
      final third = _order('third');
      final repository = _OrdersRepository([first, second, third]);
      final container = ProviderContainer(
        overrides: [
          managerOrdersRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      await container.read(managerOrdersProvider.future);

      final notifier = container.read(managerOrdersProvider.notifier);
      final assignedFirst = _order(first.id, status: 'ORDERED');
      final assignedSecond = _order(second.id, status: 'ORDERED');
      notifier.applyAssignment(assignedSecond);
      notifier.applyAssignment(assignedFirst);

      expect(container.read(managerOrdersProvider).requireValue, [
        assignedFirst,
        assignedSecond,
        third,
      ]);
      expect(repository.loads, 1);
    },
  );
}
