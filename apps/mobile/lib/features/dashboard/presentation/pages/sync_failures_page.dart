import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/sync_failures_provider.dart';

class SyncFailuresPage extends ConsumerStatefulWidget {
  const SyncFailuresPage({super.key});

  @override
  ConsumerState<SyncFailuresPage> createState() => _SyncFailuresPageState();
}

class _SyncFailuresPageState extends ConsumerState<SyncFailuresPage> {
  SyncFailuresFilter _filter = SyncFailuresFilter.failed;
  final Set<int> _busyQueueIds = <int>{};

  Future<void> _refresh() async {
    ref.invalidate(syncFailuresProvider(_filter));
    await ref.read(syncFailuresProvider(_filter).future);
  }

  Future<void> _retry(SyncFailureEntry item) async {
    setState(() {
      _busyQueueIds.add(item.queueId);
    });

    try {
      await ref.read(syncFailureActionsProvider).retry(item.queueId);
      if (!mounted) {
        return;
      }
      await _refresh();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Retry failed: $error', textAlign: TextAlign.right),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busyQueueIds.remove(item.queueId);
        });
      }
    }
  }

  Future<void> _deleteError(SyncFailureEntry item) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Failed Queue Item'),
          content: Text(
            'Queue item #${item.queueId} will be removed. Underlying data will not be deleted.',
            textAlign: TextAlign.right,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete Error'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }

    setState(() {
      _busyQueueIds.add(item.queueId);
    });

    try {
      await ref.read(syncFailureActionsProvider).deleteError(item.queueId);
      if (!mounted) {
        return;
      }
      await _refresh();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Delete failed: $error', textAlign: TextAlign.right),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busyQueueIds.remove(item.queueId);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final failuresAsync = ref.watch(syncFailuresProvider(_filter));

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('Sync Failures')),
        body: Column(
          children: [
            const SizedBox(height: 8),
            _FilterStrip(
              selected: _filter,
              onChanged: (value) {
                setState(() {
                  _filter = value;
                });
              },
            ),
            const SizedBox(height: 8),
            Expanded(
              child: failuresAsync.when(
                data: (items) {
                  if (items.isEmpty) {
                    return RefreshIndicator(
                      onRefresh: _refresh,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          SizedBox(height: 120),
                          Center(
                            child: Text(
                              'No synchronization errors',
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                      itemCount: items.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final isBusy = _busyQueueIds.contains(item.queueId);

                        return _FailureCard(
                          item: item,
                          isBusy: isBusy,
                          onRetry: () => _retry(item),
                          onDeleteError: () => _deleteError(item),
                        );
                      },
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      'Failed to load synchronization errors: $error',
                      textAlign: TextAlign.right,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterStrip extends StatelessWidget {
  const _FilterStrip({required this.selected, required this.onChanged});

  final SyncFailuresFilter selected;
  final ValueChanged<SyncFailuresFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Wrap(
        spacing: 8,
        children: [
          ChoiceChip(
            label: const Text('Failed'),
            selected: selected == SyncFailuresFilter.failed,
            onSelected: (_) => onChanged(SyncFailuresFilter.failed),
          ),
          ChoiceChip(
            label: const Text('Pending'),
            selected: selected == SyncFailuresFilter.pending,
            onSelected: null,
          ),
          ChoiceChip(
            label: const Text('Completed'),
            selected: selected == SyncFailuresFilter.completed,
            onSelected: null,
          ),
        ],
      ),
    );
  }
}

class _FailureCard extends StatelessWidget {
  const _FailureCard({
    required this.item,
    required this.isBusy,
    required this.onRetry,
    required this.onDeleteError,
  });

  final SyncFailureEntry item;
  final bool isBusy;
  final VoidCallback onRetry;
  final VoidCallback onDeleteError;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _entityTypeLabel(item.entityType),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(
                    item.operation,
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(item.entityTitle, textAlign: TextAlign.right),
            const SizedBox(height: 6),
            Text(
              item.lastError ?? '-',
              textAlign: TextAlign.right,
              style: TextStyle(color: Colors.red.shade700, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Text(
              'Retry: ${item.retryCount} | Created: ${_formatDateTime(item.createdAt)} | Updated: ${_formatDateTime(item.updatedAt)}',
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: isBusy ? null : onRetry,
                    child: isBusy
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Retry'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: isBusy ? null : onDeleteError,
                    child: const Text('Delete Error'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('View Details', textAlign: TextAlign.right),
              children: [
                _detailRow('Queue ID', item.queueId.toString()),
                _detailRow('Entity ID', item.entityId.toString()),
                _detailRow('Server UUID', item.serverUuid ?? '-'),
                _detailRow('Operation', item.operation),
                _detailRow('Status', item.status),
                _detailRow('Retry Count', item.retryCount.toString()),
                _detailRow('Last Error', item.lastError ?? '-'),
                _detailRow('Created At', _formatDateTime(item.createdAt)),
                _detailRow('Updated At', _formatDateTime(item.updatedAt)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String key, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(child: Text(value, textAlign: TextAlign.right)),
          const SizedBox(width: 8),
          Text('$key:', style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  String _entityTypeLabel(String raw) {
    switch (raw.trim().toUpperCase()) {
      case 'CHEQUE':
        return 'Cheque';
      case 'COMPANY':
        return 'Company';
      case 'BANK_ACCOUNT':
        return 'Bank Account';
      default:
        return raw;
    }
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) {
      return '-';
    }

    final local = value.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');

    return '${local.year}/$month/$day $hour:$minute';
  }
}
