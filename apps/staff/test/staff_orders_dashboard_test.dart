import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaflow_staff/core/auth/staff_auth_user.dart';
import 'package:pharmaflow_staff/features/orders/data/staff_order.dart';
import 'package:pharmaflow_staff/features/orders/presentation/staff_orders_dashboard.dart';

void main() {
  const user = StaffAuthUser(
    userId: '11111111-1111-4111-8111-111111111111',
    username: 'maryam',
    displayName: 'مریم',
    role: 'STAFF',
    isActive: true,
  );

  final pending = StaffOrder(
    id: 'pending-order',
    category: 'DRUG',
    itemText: 'آتورواستاتین 20',
    status: 'PENDING',
    requestedByName: 'علی',
    requestedByUserId: user.userId,
    requestedQuantity: 2,
    createdAt: DateTime.utc(2026, 8, 20),
  );

  final ordered = StaffOrder(
    id: 'ordered-order',
    category: 'GOODS',
    itemText: 'شامپو فولیکا',
    status: 'ORDERED',
    requestedByName: 'سارا',
    orderedQuantity: 4,
    assignedCompanyName: 'شرکت داروپخش',
    createdAt: DateTime.utc(2026, 8, 20),
    orderedAt: DateTime.utc(2026, 8, 20, 8),
  );

  testWidgets('sorts, searches, filters and confirms active orders', (
    tester,
  ) async {
    String? receivedOrderId;

    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: StaffOrdersDashboard(
              user: user,
              ordersLoader: () async => [pending, ordered],
              receiveAction: (orderId) async {
                receivedOrderId = orderId;
                return StaffOrder(
                  id: ordered.id,
                  category: ordered.category,
                  itemText: ordered.itemText,
                  status: 'RECEIVED',
                  requestedByName: ordered.requestedByName,
                  createdAt: ordered.createdAt,
                );
              },
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.textContaining('سلام مریم'), findsOneWidget);
    expect(find.byKey(const ValueKey('staff-orders-search')), findsOneWidget);
    expect(find.text('آتورواستاتین 20'), findsOneWidget);
    expect(find.text('شامپو فولیکا'), findsOneWidget);
    expect(find.text('درخواست‌دهنده: علی'), findsOneWidget);
    expect(find.text('درخواست‌دهنده: سارا'), findsOneWidget);
    expect(find.text('تأیید رسیدن به داروخانه'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('pending-order-actions-ordered-order')),
      findsNothing,
    );

    final orderedTop = tester.getTopLeft(find.text('شامپو فولیکا')).dy;
    final pendingTop = tester.getTopLeft(find.text('آتورواستاتین 20')).dy;
    expect(orderedTop, lessThan(pendingTop));

    await tester.tap(find.byKey(const ValueKey('pending-orders-filter')));
    await tester.pumpAndSettle();
    expect(find.text('آتورواستاتین 20'), findsOneWidget);
    expect(find.text('شامپو فولیکا'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('pending-orders-filter')));
    await tester.pumpAndSettle();
    expect(find.text('شامپو فولیکا'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('staff-orders-search')),
      'فولیکا',
    );
    await tester.pumpAndSettle();
    expect(find.text('آتورواستاتین 20'), findsNothing);
    expect(find.text('شامپو فولیکا'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('clear-staff-orders-search')));
    await tester.pumpAndSettle();
    expect(find.text('آتورواستاتین 20'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const ValueKey('receive-order-ordered-order')),
    );
    await tester.tap(find.byKey(const ValueKey('receive-order-ordered-order')));
    await tester.pumpAndSettle();

    expect(find.text('تأیید دریافت سفارش'), findsOneWidget);
    await tester.tap(find.text('بله، رسیده است'));
    await tester.pumpAndSettle();

    expect(receivedOrderId, 'ordered-order');
    expect(find.text('شامپو فولیکا'), findsNothing);
    expect(find.text('آتورواستاتین 20'), findsOneWidget);
  });

  testWidgets('staff can edit and delete any pending order', (tester) async {
    const foreignRequesterId = '22222222-2222-4222-8222-222222222222';
    final ownPending = StaffOrder(
      id: 'own-pending',
      category: 'DRUG',
      itemText: 'داروی قابل ویرایش',
      status: 'PENDING',
      requestedByName: user.displayName,
      requestedByUserId: user.userId,
      requestedQuantity: 1,
      createdAt: DateTime.utc(2026, 8, 20),
    );
    final foreignPending = StaffOrder(
      id: 'foreign-pending',
      category: 'GOODS',
      itemText: 'درخواست کاربر دیگر',
      status: 'PENDING',
      requestedByName: 'علی',
      requestedByUserId: foreignRequesterId,
      createdAt: DateTime.utc(2026, 8, 20),
    );
    String? editedOrderId;
    String? deletedOrderId;

    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: StaffOrdersDashboard(
              user: user,
              ordersLoader: () async => [ownPending, foreignPending],
              receiveAction: (_) async => throw UnimplementedError(),
              editAction:
                  ({
                    required orderId,
                    required category,
                    required itemText,
                    requestedQuantity,
                    suggestedCompanyText,
                    notes,
                  }) async {
                    editedOrderId = orderId;
                    final source = orderId == ownPending.id
                        ? ownPending
                        : foreignPending;
                    return StaffOrder(
                      id: orderId,
                      category: category,
                      itemText: itemText,
                      status: 'PENDING',
                      requestedByName: source.requestedByName,
                      requestedByUserId: source.requestedByUserId,
                      requestedQuantity: requestedQuantity,
                      suggestedCompanyText: suggestedCompanyText,
                      notes: notes,
                      createdAt: source.createdAt,
                    );
                  },
              deleteAction: (orderId) async {
                deletedOrderId = orderId;
              },
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('pending-order-actions-own-pending')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('pending-order-actions-foreign-pending')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('pending-order-actions-foreign-pending')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('ویرایش'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('edit-order-item-text')),
      'درخواست ویرایش‌شده همکار',
    );
    await tester.enterText(
      find.byKey(const ValueKey('edit-order-quantity')),
      '3',
    );
    await tester.tap(find.byKey(const ValueKey('save-pending-order-edit')));
    await tester.pumpAndSettle();

    expect(editedOrderId, 'foreign-pending');
    expect(find.text('درخواست ویرایش‌شده همکار'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('pending-order-actions-own-pending')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('حذف'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('confirm-delete-order-own-pending')),
    );
    await tester.pumpAndSettle();

    expect(deletedOrderId, 'own-pending');
    expect(find.text('داروی قابل ویرایش'), findsNothing);
    expect(find.text('درخواست ویرایش‌شده همکار'), findsOneWidget);
  });
}
