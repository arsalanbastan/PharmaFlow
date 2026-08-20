import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shamsi_date/shamsi_date.dart';

import '../../../core/auth/staff_auth_user.dart';
import '../data/staff_order.dart';
import '../data/staff_order_api_service.dart';

typedef StaffActiveOrdersLoader = Future<List<StaffOrder>> Function();
typedef StaffOrderReceiveAction = Future<StaffOrder> Function(String orderId);
typedef StaffOrderEditAction =
    Future<StaffOrder> Function({
      required String orderId,
      required String category,
      required String itemText,
      int? requestedQuantity,
      String? suggestedCompanyText,
      String? notes,
    });
typedef StaffOrderDeleteAction = Future<void> Function(String orderId);

class StaffOrdersDashboard extends StatefulWidget {
  const StaffOrdersDashboard({
    required this.user,
    this.ordersLoader,
    this.receiveAction,
    this.editAction,
    this.deleteAction,
    super.key,
  });

  final StaffAuthUser user;
  final StaffActiveOrdersLoader? ordersLoader;
  final StaffOrderReceiveAction? receiveAction;
  final StaffOrderEditAction? editAction;
  final StaffOrderDeleteAction? deleteAction;

  @override
  State<StaffOrdersDashboard> createState() => StaffOrdersDashboardState();
}

class StaffOrdersDashboardState extends State<StaffOrdersDashboard> {
  static const _refreshInterval = Duration(seconds: 30);

  List<StaffOrder> _orders = const [];
  final Set<String> _receivingOrderIds = <String>{};
  final Set<String> _changingOrderIds = <String>{};
  final TextEditingController _searchController = TextEditingController();
  Timer? _refreshTimer;
  bool _loading = true;
  bool _refreshing = false;
  bool _pendingFilterSelected = false;
  bool _orderedFilterSelected = false;
  String _searchQuery = '';
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    unawaited(refresh());
    _refreshTimer = Timer.periodic(_refreshInterval, (_) {
      unawaited(refresh(silent: true));
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  static String _normalizeSearch(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('ي', 'ی')
        .replaceAll('ك', 'ک')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  List<StaffOrder> _visibleOrders() {
    final normalizedQuery = _normalizeSearch(_searchQuery);
    final statusFilterActive = _pendingFilterSelected || _orderedFilterSelected;

    final visible = _orders
        .where((order) {
          final matchesStatus =
              !statusFilterActive ||
              (_pendingFilterSelected && order.isPending) ||
              (_orderedFilterSelected && order.isOrdered);

          if (!matchesStatus || normalizedQuery.isEmpty) {
            return matchesStatus;
          }

          final searchableText = _normalizeSearch(
            <String>[
              order.itemText,
              order.requestedByName,
              order.categoryLabel,
              order.assignedCompanyName ?? '',
              order.suggestedCompanyText ?? '',
              order.notes ?? '',
              order.requestedQuantity?.toString() ?? '',
              order.orderedQuantity?.toString() ?? '',
            ].join(' '),
          );

          return searchableText.contains(normalizedQuery);
        })
        .toList(growable: false);

    visible.sort((left, right) {
      if (left.isOrdered != right.isOrdered) {
        return left.isOrdered ? -1 : 1;
      }

      final leftDate = left.orderedAt ?? left.createdAt;
      final rightDate = right.orderedAt ?? right.createdAt;
      return rightDate.compareTo(leftDate);
    });

    return visible;
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
    });
  }

  Future<List<StaffOrder>> _loadOrders() async {
    final injectedLoader = widget.ordersLoader;

    if (injectedLoader != null) {
      return injectedLoader();
    }

    final api = StaffOrderApiService();

    try {
      return await api.fetchActiveOrders();
    } finally {
      api.close();
    }
  }

  Future<StaffOrder> _receiveOrder(String orderId) async {
    final injectedAction = widget.receiveAction;

    if (injectedAction != null) {
      return injectedAction(orderId);
    }

    final api = StaffOrderApiService();

    try {
      return await api.receiveOrder(orderId: orderId);
    } finally {
      api.close();
    }
  }

  Future<StaffOrder> _editOrder(
    String orderId,
    _StaffOrderEditDraft draft,
  ) async {
    final injectedAction = widget.editAction;

    if (injectedAction != null) {
      return injectedAction(
        orderId: orderId,
        category: draft.category,
        itemText: draft.itemText,
        requestedQuantity: draft.requestedQuantity,
        suggestedCompanyText: draft.suggestedCompanyText,
        notes: draft.notes,
      );
    }

    final api = StaffOrderApiService();

    try {
      return await api.updatePendingOrder(
        orderId: orderId,
        category: draft.category,
        itemText: draft.itemText,
        requestedQuantity: draft.requestedQuantity,
        suggestedCompanyText: draft.suggestedCompanyText,
        notes: draft.notes,
      );
    } finally {
      api.close();
    }
  }

  Future<void> _deleteOrder(String orderId) async {
    final injectedAction = widget.deleteAction;

    if (injectedAction != null) {
      await injectedAction(orderId);
      return;
    }

    final api = StaffOrderApiService();

    try {
      await api.deletePendingOrder(orderId: orderId);
    } finally {
      api.close();
    }
  }

  Future<void> _editPending(StaffOrder order) async {
    if (_changingOrderIds.contains(order.id) || !order.canBeChangedByStaff) {
      return;
    }

    final draft = await _showPendingEditDialog(order);

    if (draft == null || !mounted) {
      return;
    }

    setState(() {
      _changingOrderIds.add(order.id);
    });

    try {
      final updated = await _editOrder(order.id, draft);

      if (!mounted) {
        return;
      }

      setState(() {
        _orders = _orders
            .map((candidate) => candidate.id == order.id ? updated : candidate)
            .toList(growable: false);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('درخواست «${updated.itemText}» ویرایش شد.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ویرایش درخواست انجام نشد: $error')),
      );
      await refresh(silent: true);
    } finally {
      if (mounted) {
        setState(() {
          _changingOrderIds.remove(order.id);
        });
      }
    }
  }

  Future<void> _deletePending(StaffOrder order) async {
    if (_changingOrderIds.contains(order.id) || !order.canBeChangedByStaff) {
      return;
    }

    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف درخواست'),
        content: Text(
          'درخواست «${order.itemText}» حذف شود؟\n\n'
          'این کار فقط تا قبل از سفارش مدیر امکان‌پذیر است.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('انصراف'),
          ),
          FilledButton.icon(
            key: ValueKey('confirm-delete-order-${order.id}'),
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('حذف شود'),
          ),
        ],
      ),
    );

    if (accepted != true || !mounted) {
      return;
    }

    setState(() {
      _changingOrderIds.add(order.id);
    });

    try {
      await _deleteOrder(order.id);

      if (!mounted) {
        return;
      }

      setState(() {
        _orders = _orders
            .where((candidate) => candidate.id != order.id)
            .toList(growable: false);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('درخواست «${order.itemText}» حذف شد.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('حذف درخواست انجام نشد: $error')));
      await refresh(silent: true);
    } finally {
      if (mounted) {
        setState(() {
          _changingOrderIds.remove(order.id);
        });
      }
    }
  }

  Future<_StaffOrderEditDraft?> _showPendingEditDialog(StaffOrder order) {
    return showDialog<_StaffOrderEditDraft>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PendingOrderEditDialog(order: order),
    );
  }

  Future<void> refresh({bool silent = false}) async {
    if (_refreshing) {
      return;
    }

    _refreshing = true;

    if (!silent && mounted) {
      setState(() {
        _loading = _orders.isEmpty;
        _errorMessage = null;
      });
    }

    try {
      final orders = await _loadOrders();

      if (!mounted) {
        return;
      }

      setState(() {
        _orders = orders;
        _loading = false;
        _errorMessage = null;
      });
    } catch (_) {
      if (!mounted || silent) {
        return;
      }

      setState(() {
        _loading = false;
        _errorMessage = 'دریافت سفارش‌ها از سرور انجام نشد.';
      });
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _confirmReceived(StaffOrder order) async {
    if (_receivingOrderIds.contains(order.id)) {
      return;
    }

    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('تأیید دریافت سفارش'),
          content: Text(
            'آیا «${order.itemText}» به داروخانه رسیده است؟\n\n'
            'پس از تأیید، این مورد از سفارش‌های در جریان خارج می‌شود.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('خیر'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              icon: const Icon(Icons.inventory_2_outlined),
              label: const Text('بله، رسیده است'),
            ),
          ],
        );
      },
    );

    if (accepted != true || !mounted) {
      return;
    }

    setState(() {
      _receivingOrderIds.add(order.id);
    });

    try {
      await _receiveOrder(order.id);

      if (!mounted) {
        return;
      }

      setState(() {
        _orders = _orders
            .where((candidate) => candidate.id != order.id)
            .toList(growable: false);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('رسیدن «${order.itemText}» تأیید شد.')),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تأیید دریافت انجام نشد؛ فهرست را تازه‌سازی کنید.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _receivingOrderIds.remove(order.id);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = _orders.where((order) => order.isPending).length;
    final orderedCount = _orders.where((order) => order.isOrdered).length;
    final visibleOrders = _visibleOrders();
    final filtersActive =
        _searchQuery.trim().isNotEmpty ||
        _pendingFilterSelected ||
        _orderedFilterSelected;

    return RefreshIndicator(
      onRefresh: refresh,
      child: ListView(
        key: const ValueKey('staff-active-orders-scroll'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 18),
        children: [
          _GreetingCard(user: widget.user),
          const SizedBox(height: 8),
          _OrdersSummaryCard(
            pendingCount: pendingCount,
            orderedCount: orderedCount,
            refreshing: _refreshing,
            searchController: _searchController,
            searchQuery: _searchQuery,
            pendingSelected: _pendingFilterSelected,
            orderedSelected: _orderedFilterSelected,
            onSearchChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
            onClearSearch: _clearSearch,
            onPendingToggle: () {
              setState(() {
                _pendingFilterSelected = !_pendingFilterSelected;
              });
            },
            onOrderedToggle: () {
              setState(() {
                _orderedFilterSelected = !_orderedFilterSelected;
              });
            },
            onRefresh: refresh,
          ),
          const SizedBox(height: 7),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 64),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_errorMessage != null)
            _ErrorCard(message: _errorMessage!, onRetry: refresh)
          else if (_orders.isEmpty)
            const _EmptyOrdersCard()
          else if (visibleOrders.isEmpty)
            _NoMatchingOrdersCard(
              onClear: () {
                _searchController.clear();
                setState(() {
                  _searchQuery = '';
                  _pendingFilterSelected = false;
                  _orderedFilterSelected = false;
                });
              },
            )
          else
            for (final order in visibleOrders) ...[
              _ActiveOrderCard(
                order: order,
                receiving: _receivingOrderIds.contains(order.id),
                changing: _changingOrderIds.contains(order.id),
                canModify: order.canBeChangedByStaff,
                onReceive: () => _confirmReceived(order),
                onEdit: () => _editPending(order),
                onDelete: () => _deletePending(order),
              ),
              const SizedBox(height: 6),
            ],
          if (filtersActive && visibleOrders.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '${visibleOrders.length} مورد نمایش داده می‌شود',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}

class _GreetingCard extends StatelessWidget {
  const _GreetingCard({required this.user});

  final StaffAuthUser user;

  @override
  Widget build(BuildContext context) {
    final today = Jalali.now();
    const green = Color(0xFF1B8A4B);

    return Card(
      elevation: 0.3,
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0x120F172A), width: 0.8),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [Color(0xFFEAF7EE), Colors.white],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -22,
              left: -22,
              child: Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0x26FFFFFF),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 18,
                    backgroundColor: Color(0xFFDFF4E6),
                    foregroundColor: green,
                    child: Icon(Icons.badge_outlined, size: 21),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'سلام ${user.displayName} 👋',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            const Icon(
                              Icons.calendar_month_outlined,
                              size: 15,
                              color: green,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${today.year}/${today.month.toString().padLeft(2, '0')}/${today.day.toString().padLeft(2, '0')}',
                              textDirection: TextDirection.ltr,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF334155),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrdersSummaryCard extends StatelessWidget {
  const _OrdersSummaryCard({
    required this.pendingCount,
    required this.orderedCount,
    required this.refreshing,
    required this.searchController,
    required this.searchQuery,
    required this.pendingSelected,
    required this.orderedSelected,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onPendingToggle,
    required this.onOrderedToggle,
    required this.onRefresh,
  });

  final int pendingCount;
  final int orderedCount;
  final bool refreshing;
  final TextEditingController searchController;
  final String searchQuery;
  final bool pendingSelected;
  final bool orderedSelected;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final VoidCallback onPendingToggle;
  final VoidCallback onOrderedToggle;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0.2,
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0x120F172A), width: 0.8),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 7, 8, 7),
        child: Column(
          children: [
            SizedBox(
              height: 42,
              child: TextField(
                key: const ValueKey('staff-orders-search'),
                controller: searchController,
                onChanged: onSearchChanged,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'جستجو در سفارش‌ها',
                  prefixIcon: const Icon(Icons.search, size: 21),
                  suffixIcon: searchQuery.trim().isEmpty
                      ? null
                      : IconButton(
                          key: const ValueKey('clear-staff-orders-search'),
                          onPressed: onClearSearch,
                          tooltip: 'پاک کردن جستجو',
                          icon: const Icon(Icons.close, size: 19),
                        ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 6),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: _StatusFilterButton(
                    key: const ValueKey('pending-orders-filter'),
                    label: 'در انتظار',
                    count: pendingCount,
                    selected: pendingSelected,
                    color: const Color(0xFFC77710),
                    onTap: onPendingToggle,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _StatusFilterButton(
                    key: const ValueKey('ordered-orders-filter'),
                    label: 'تأییدشده',
                    count: orderedCount,
                    selected: orderedSelected,
                    color: const Color(0xFF1B8A4B),
                    onTap: onOrderedToggle,
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: refreshing ? null : onRefresh,
                  tooltip: 'تازه‌سازی',
                  visualDensity: VisualDensity.compact,
                  icon: refreshing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusFilterButton extends StatelessWidget {
  const _StatusFilterButton({
    required this.label,
    required this.count,
    required this.selected,
    required this.color,
    required this.onTap,
    super.key,
  });

  final String label;
  final int count;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color : color.withValues(alpha: 0.09),
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 35,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Text(
            '$label ($count)',
            style: TextStyle(
              color: selected ? Colors.white : color,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _ActiveOrderCard extends StatelessWidget {
  const _ActiveOrderCard({
    required this.order,
    required this.receiving,
    required this.changing,
    required this.canModify,
    required this.onReceive,
    required this.onEdit,
    required this.onDelete,
  });

  final StaffOrder order;
  final bool receiving;
  final bool changing;
  final bool canModify;
  final VoidCallback onReceive;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ordered = order.isOrdered;
    final statusColor = ordered
        ? const Color(0xFF1B8A4B)
        : const Color(0xFFC77710);
    final statusBackground = ordered
        ? const Color(0xFFEAF7EE)
        : const Color(0xFFFFF0DB);
    final quantity = order.orderedQuantity ?? order.requestedQuantity;

    return Card(
      key: ValueKey('staff-order-${order.id}'),
      elevation: 0.2,
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(13),
        side: BorderSide(color: statusColor.withValues(alpha: 0.22)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(9, 8, 9, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: statusBackground,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    ordered ? 'سفارش‌شده' : 'در انتظار سفارش',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    order.itemText,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  order.categoryLabel,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                  ),
                ),
                if (canModify) ...[
                  const SizedBox(width: 2),
                  if (changing)
                    const Padding(
                      padding: EdgeInsets.all(7),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else
                    PopupMenuButton<_PendingOrderAction>(
                      key: ValueKey('pending-order-actions-${order.id}'),
                      tooltip: 'عملیات درخواست',
                      padding: EdgeInsets.zero,
                      onSelected: (action) {
                        switch (action) {
                          case _PendingOrderAction.edit:
                            onEdit();
                            break;
                          case _PendingOrderAction.delete:
                            onDelete();
                            break;
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: _PendingOrderAction.edit,
                          child: ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.edit_outlined),
                            title: Text('ویرایش'),
                          ),
                        ),
                        PopupMenuItem(
                          value: _PendingOrderAction.delete,
                          child: ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                            ),
                            title: Text(
                              'حذف',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ),
                      ],
                      icon: const Icon(Icons.more_vert, size: 20),
                    ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 9,
              runSpacing: 4,
              children: [
                _OrderMeta(
                  icon: Icons.person_outline,
                  text: 'درخواست‌دهنده: ${order.requestedByName}',
                ),
                if (quantity != null)
                  _OrderMeta(
                    icon: Icons.numbers_outlined,
                    text: 'تعداد: $quantity',
                  ),
                if (order.assignedCompanyName != null)
                  _OrderMeta(
                    icon: Icons.apartment_outlined,
                    text: order.assignedCompanyName!,
                  ),
              ],
            ),
            if (order.notes != null) ...[
              const SizedBox(height: 5),
              Text(
                order.notes!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ],
            if (ordered) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  height: 34,
                  child: FilledButton.icon(
                    key: ValueKey('receive-order-${order.id}'),
                    onPressed: receiving ? null : onReceive,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: receiving
                        ? const SizedBox(
                            width: 15,
                            height: 15,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.inventory_2_outlined, size: 18),
                    label: Text(
                      receiving ? 'در حال ثبت...' : 'تأیید رسیدن به داروخانه',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

enum _PendingOrderAction { edit, delete }

class _PendingOrderEditDialog extends StatefulWidget {
  const _PendingOrderEditDialog({required this.order});

  final StaffOrder order;

  @override
  State<_PendingOrderEditDialog> createState() =>
      _PendingOrderEditDialogState();
}

class _PendingOrderEditDialogState extends State<_PendingOrderEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _itemController;
  late final TextEditingController _quantityController;
  late final TextEditingController _companyController;
  late final TextEditingController _notesController;
  late String _category;

  @override
  void initState() {
    super.initState();
    _category = widget.order.category;
    _itemController = TextEditingController(text: widget.order.itemText);
    _quantityController = TextEditingController(
      text: widget.order.requestedQuantity?.toString() ?? '',
    );
    _companyController = TextEditingController(
      text: widget.order.suggestedCompanyText ?? '',
    );
    _notesController = TextEditingController(text: widget.order.notes ?? '');
  }

  @override
  void dispose() {
    _itemController.dispose();
    _quantityController.dispose();
    _companyController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final quantityText = _quantityController.text.trim();
    Navigator.of(context).pop(
      _StaffOrderEditDraft(
        category: _category,
        itemText: _itemController.text.trim(),
        requestedQuantity: quantityText.isEmpty
            ? null
            : int.parse(quantityText),
        suggestedCompanyText: _companyController.text,
        notes: _notesController.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('ویرایش درخواست'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  key: const ValueKey('edit-order-category'),
                  initialValue: _category,
                  decoration: const InputDecoration(
                    labelText: 'دسته‌بندی',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'DRUG', child: Text('دارو')),
                    DropdownMenuItem(value: 'GOODS', child: Text('کالا')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _category = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey('edit-order-item-text'),
                  controller: _itemController,
                  autofocus: true,
                  maxLength: 300,
                  decoration: const InputDecoration(
                    labelText: 'نام دارو یا کالا',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'نام درخواست را وارد کنید.'
                      : null,
                ),
                const SizedBox(height: 4),
                TextFormField(
                  key: const ValueKey('edit-order-quantity'),
                  controller: _quantityController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'تعداد (اختیاری)',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';

                    if (text.isEmpty) {
                      return null;
                    }

                    final quantity = int.tryParse(text);
                    return quantity == null ||
                            quantity < 1 ||
                            quantity > 1000000
                        ? 'تعداد باید عددی بین ۱ تا ۱٬۰۰۰٬۰۰۰ باشد.'
                        : null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey('edit-order-company'),
                  controller: _companyController,
                  maxLength: 200,
                  decoration: const InputDecoration(
                    labelText: 'شرکت پیشنهادی (اختیاری)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 4),
                TextFormField(
                  key: const ValueKey('edit-order-notes'),
                  controller: _notesController,
                  minLines: 2,
                  maxLines: 4,
                  maxLength: 1000,
                  decoration: const InputDecoration(
                    labelText: 'توضیحات (اختیاری)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('انصراف'),
        ),
        FilledButton.icon(
          key: const ValueKey('save-pending-order-edit'),
          onPressed: _submit,
          icon: const Icon(Icons.save_outlined),
          label: const Text('ذخیره تغییرات'),
        ),
      ],
    );
  }
}

class _StaffOrderEditDraft {
  const _StaffOrderEditDraft({
    required this.category,
    required this.itemText,
    this.requestedQuantity,
    this.suggestedCompanyText,
    this.notes,
  });

  final String category;
  final String itemText;
  final int? requestedQuantity;
  final String? suggestedCompanyText;
  final String? notes;
}

class _OrderMeta extends StatelessWidget {
  const _OrderMeta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: const Color(0xFF64748B)),
        const SizedBox(width: 3),
        Text(
          text,
          style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569)),
        ),
      ],
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFFFE8E6),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            const Icon(Icons.cloud_off_outlined, size: 36),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('تلاش دوباره'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyOrdersCard extends StatelessWidget {
  const _EmptyOrdersCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 44),
        child: Column(
          children: [
            Icon(Icons.task_alt, size: 44, color: Color(0xFF1B8A4B)),
            SizedBox(height: 12),
            Text(
              'در حال حاضر سفارش فعالی وجود ندارد.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _NoMatchingOrdersCard extends StatelessWidget {
  const _NoMatchingOrdersCard({required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
        child: Column(
          children: [
            const Icon(Icons.search_off_outlined, size: 36),
            const SizedBox(height: 8),
            const Text('موردی مطابق جستجو یا فیلتر پیدا نشد.'),
            const SizedBox(height: 6),
            TextButton(onPressed: onClear, child: const Text('حذف فیلترها')),
          ],
        ),
      ),
    );
  }
}
