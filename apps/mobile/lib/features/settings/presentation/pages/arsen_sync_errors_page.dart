import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/communication_settings_provider.dart';

class ArsenSyncErrorsPage extends ConsumerStatefulWidget {
  const ArsenSyncErrorsPage({super.key});

  @override
  ConsumerState<ArsenSyncErrorsPage> createState() => _ArsenSyncErrorsPageState();
}

class _ArsenSyncErrorsPageState extends ConsumerState<ArsenSyncErrorsPage> {
  static const _endpoint = '/api/v1/integrations/arsen/sync-errors';
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ref.read(apiClientProvider).get(_endpoint);
      if (result is! List) throw Exception('پاسخ نامعتبر سرور');
      if (!mounted) return;
      setState(() {
        _items = result.whereType<Map<String, dynamic>>().toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'دریافت گزارش خطاها ناموفق بود.';
      });
    }
  }

  Future<void> _clear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف گزارش خطاها'),
        content: const Text('فقط گزارش‌های خطای همگام‌سازی پاک می‌شوند؛ اطلاعات فاکتورها تغییر نمی‌کند.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('انصراف')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف گزارش')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(apiClientProvider).delete(_endpoint);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('گزارش خطاها پاک شد.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('حذف گزارش خطاها ناموفق بود.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('خطاهای همگام‌سازی آرسن'),
          actions: [
            IconButton(onPressed: _load, tooltip: 'بروزرسانی', icon: const Icon(Icons.refresh)),
            IconButton(onPressed: _items.isEmpty ? null : _clear, tooltip: 'حذف گزارش', icon: const Icon(Icons.delete_outline)),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(_error!),
                    const SizedBox(height: 8),
                    FilledButton(onPressed: _load, child: const Text('تلاش مجدد')),
                  ]))
                : _items.isEmpty
                    ? const Center(child: Text('خطای ثبت‌شده‌ای وجود ندارد.'))
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('فاکتور آرسن: ${item['arsenFactorId'] ?? '-'}',
                                      style: Theme.of(context).textTheme.titleMedium),
                                  const SizedBox(height: 6),
                                  Text('${item['message'] ?? 'علت خطا ثبت نشده است.'}'),
                                  const SizedBox(height: 8),
                                  Text('نوع خطا: ${item['errorKind'] ?? '-'}'),
                                  Text('تعداد تکرار: ${item['occurrences'] ?? 1}'),
                                  Text('آخرین مشاهده: ${item['lastSeenAt'] ?? '-'}'),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}
