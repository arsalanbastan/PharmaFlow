import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../settings/presentation/providers/communication_settings_provider.dart';
import '../../data/manager_invoices_repository.dart';
import '../../domain/manager_invoice.dart';

class InvoicesPage extends ConsumerStatefulWidget {
  const InvoicesPage({super.key});

  @override
  ConsumerState<InvoicesPage> createState() => _InvoicesPageState();
}

class _InvoicesPageState extends ConsumerState<InvoicesPage> {
  final _searchController = TextEditingController();
  final List<ManagerInvoiceSummary> _items = [];
  final Set<String> _updatingPaymentStatus = <String>{};

  bool _loading = true;
  bool _loadingMore = false;

  String? _error;
  String _query = '';

  int _page = 1;
  int _totalPages = 1;
  int _totalCount = 0;

  ManagerInvoicesRepository get _repository =>
      ManagerInvoicesRepository(ref.read(apiClientProvider));

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _load(reset: true));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({required bool reset}) async {
    if (reset) {
      if (mounted) {
        setState(() {
          _loading = true;
          _error = null;
          _page = 1;
        });
      }
    } else {
      if (_loadingMore || _page >= _totalPages) {
        return;
      }

      setState(() {
        _loadingMore = true;
      });
    }

    try {
      final requestedPage = reset ? 1 : _page + 1;

      final result = await _repository.getPage(
        query: _query,
        page: requestedPage,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        if (reset) {
          _items
            ..clear()
            ..addAll(result.items);
        } else {
          _items.addAll(result.items);
        }

        _page = result.page;
        _totalPages = result.totalPages;
        _totalCount = result.totalCount;
        _error = null;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = 'دریافت فاکتورها انجام نشد. اتصال به سرور را بررسی کنید.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  Future<void> _search() async {
    FocusScope.of(context).unfocus();

    setState(() {
      _query = _searchController.text.trim();
    });

    await _load(reset: true);
  }

  Future<void> _clearSearch() async {
    _searchController.clear();

    setState(() {
      _query = '';
    });

    await _load(reset: true);
  }

  Future<void> _setPaid(ManagerInvoiceSummary invoice, bool isPaid) async {
    if (_updatingPaymentStatus.contains(invoice.id)) {
      return;
    }

    setState(() {
      _updatingPaymentStatus.add(invoice.id);
    });

    try {
      await _repository.setPaid(invoiceId: invoice.id, isPaid: isPaid);

      if (!mounted) {
        return;
      }

      final index = _items.indexWhere((item) => item.id == invoice.id);

      if (index >= 0) {
        setState(() {
          _items[index] = _items[index].copyWith(isPaid: isPaid);
        });
      }
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تغییر وضعیت پرداخت فاکتور انجام نشد.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _updatingPaymentStatus.remove(invoice.id);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('فاکتورها'),
          actions: [
            IconButton(
              tooltip: 'بروزرسانی',
              onPressed: _loading ? null : () => _load(reset: true),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _search(),
                decoration: InputDecoration(
                  labelText: 'جستجو در فاکتورها',
                  hintText: 'شماره فاکتور یا نام شرکت',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isEmpty
                      ? IconButton(
                          tooltip: 'جستجو',
                          onPressed: _search,
                          icon: const Icon(Icons.arrow_back),
                        )
                      : IconButton(
                          tooltip: 'پاک کردن',
                          onPressed: _clearSearch,
                          icon: const Icon(Icons.close),
                        ),
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            if (!_loading && _error == null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'نمایش ${_items.length} از $_totalCount فاکتور',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _items.isEmpty) {
      return _InvoiceErrorView(
        message: _error!,
        onRetry: () => _load(reset: true),
      );
    }

    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _load(reset: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 120),
            Icon(Icons.receipt_long_outlined, size: 60),
            SizedBox(height: 12),
            Center(child: Text('فاکتوری پیدا نشد.')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _load(reset: true),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(10, 4, 10, 24),
        itemCount: _items.length + 1,
        itemBuilder: (context, index) {
          if (index == _items.length) {
            if (_page >= _totalPages) {
              return const SizedBox(height: 12);
            }

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: _loadingMore
                    ? const CircularProgressIndicator()
                    : OutlinedButton.icon(
                        onPressed: () => _load(reset: false),
                        icon: const Icon(Icons.expand_more),
                        label: const Text('نمایش فاکتورهای بیشتر'),
                      ),
              ),
            );
          }

          final invoice = _items[index];

          return _InvoiceCard(
            invoice: invoice,
            paymentStatusUpdating: _updatingPaymentStatus.contains(invoice.id),
            onPaidChanged: (value) => _setPaid(invoice, value),
            onTap: () async {
              await Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => InvoiceDetailsPage(
                    invoiceId: invoice.id,
                    repository: _repository,
                  ),
                ),
              );

              if (mounted) {
                await _load(reset: true);
              }
            },
          );
        },
      ),
    );
  }
}

class _InvoiceCard extends StatelessWidget {
  const _InvoiceCard({
    required this.invoice,
    required this.paymentStatusUpdating,
    required this.onPaidChanged,
    required this.onTap,
  });

  final ManagerInvoiceSummary invoice;
  final bool paymentStatusUpdating;
  final ValueChanged<bool> onPaidChanged;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final invoiceNumber =
        invoice.invoiceNumber ?? invoice.arsenFactorId.toString();

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      invoice.company.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (invoice.isDeletedInArsen)
                    const _InvoiceBadge(
                      text: 'حذف‌شده در آرسن',
                      icon: Icons.warning_amber_rounded,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 14,
                runSpacing: 7,
                children: [
                  _InvoiceInfo(icon: Icons.tag, text: 'شماره: $invoiceNumber'),
                  _InvoiceInfo(
                    icon: Icons.calendar_today_outlined,
                    text: 'تاریخ: ${invoice.invoiceDate ?? '-'}',
                  ),
                  _InvoiceInfo(
                    icon: Icons.inventory_2_outlined,
                    text: '${invoice.itemCount} قلم',
                  ),
                  if (invoice.paymentDays != null)
                    _InvoiceInfo(
                      icon: Icons.schedule,
                      text: 'مهلت ${invoice.paymentDays} روز',
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Checkbox(
                    value: invoice.isPaid,
                    onChanged: paymentStatusUpdating
                        ? null
                        : (value) {
                            if (value != null) {
                              onPaidChanged(value);
                            }
                          },
                  ),
                  Text(
                    invoice.isPaid ? 'پرداخت شده' : 'پرداخت نشده',
                    style: TextStyle(
                      fontWeight: invoice.isPaid
                          ? FontWeight.w700
                          : FontWeight.w400,
                    ),
                  ),
                  if (paymentStatusUpdating) ...[
                    const SizedBox(width: 8),
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ],
                ],
              ),
              const Divider(height: 12),
              Row(
                children: [
                  const Icon(Icons.payments_outlined, size: 19),
                  const SizedBox(width: 6),
                  const Text('مبلغ قابل پرداخت:'),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      _formatAmount(invoice.factorPayablePrice),
                      textAlign: TextAlign.left,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.chevron_left),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class InvoiceDetailsPage extends StatefulWidget {
  const InvoiceDetailsPage({
    required this.invoiceId,
    required this.repository,
    super.key,
  });

  final String invoiceId;
  final ManagerInvoicesRepository repository;

  @override
  State<InvoiceDetailsPage> createState() => _InvoiceDetailsPageState();
}

class _InvoiceDetailsPageState extends State<InvoiceDetailsPage> {
  late Future<ManagerInvoiceDetails> _future;

  @override
  void initState() {
    super.initState();

    _future = widget.repository.getById(widget.invoiceId);
  }

  void _retry() {
    setState(() {
      _future = widget.repository.getById(widget.invoiceId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('جزئیات فاکتور')),
        body: FutureBuilder<ManagerInvoiceDetails>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError || snapshot.data == null) {
              return _InvoiceErrorView(
                message: 'دریافت جزئیات فاکتور انجام نشد.',
                onRetry: () async => _retry(),
              );
            }

            return _InvoiceDetailsBody(invoice: snapshot.data!);
          },
        ),
      ),
    );
  }
}

class _InvoiceDetailsBody extends StatelessWidget {
  const _InvoiceDetailsBody({required this.invoice});

  final ManagerInvoiceDetails invoice;

  @override
  Widget build(BuildContext context) {
    final invoiceNumber =
        invoice.invoiceNumber ?? invoice.arsenFactorId.toString();

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        invoice.company.name,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (invoice.isDeletedInArsen)
                      const _InvoiceBadge(
                        text: 'حذف‌شده در آرسن',
                        icon: Icons.warning_amber_rounded,
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                _DetailRow(
                  label: 'وضعیت پرداخت',
                  value: invoice.isPaid ? 'پرداخت شده' : 'پرداخت نشده',
                  emphasize: invoice.isPaid,
                ),
                _DetailRow(label: 'شماره فاکتور', value: invoiceNumber),
                _DetailRow(
                  label: 'تاریخ فاکتور',
                  value: invoice.invoiceDate ?? '-',
                ),
                _DetailRow(
                  label: 'تاریخ تسویه',
                  value: invoice.settlementDate ?? '-',
                ),
                _DetailRow(
                  label: 'نوع سند',
                  value: invoice.factorDocTypeName ?? '-',
                ),
                if (invoice.paymentDays != null)
                  _DetailRow(
                    label: 'مهلت پرداخت',
                    value: '${invoice.paymentDays} روز',
                  ),
                _DetailRow(
                  label: 'جمع فاکتور',
                  value: _formatAmount(invoice.factorTotalPrice),
                ),
                _DetailRow(
                  label: 'تخفیف',
                  value: _formatAmount(invoice.factorDiscount),
                ),
                _DetailRow(
                  label: 'مالیات',
                  value: _formatAmount(invoice.factorTax),
                ),
                _DetailRow(
                  label: 'مبلغ قابل پرداخت',
                  value: _formatAmount(invoice.factorPayablePrice),
                  emphasize: true,
                ),
                if (invoice.barbariPrice != null)
                  _DetailRow(
                    label: 'باربری',
                    value: _formatAmount(invoice.barbariPrice),
                  ),
                if (invoice.description != null)
                  _DetailRow(label: 'توضیحات', value: invoice.description!),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'اقلام فاکتور (${invoice.items.length})',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 6),
        ...invoice.items.asMap().entries.map(
          (entry) => _InvoiceItemCard(index: entry.key + 1, item: entry.value),
        ),
      ],
    );
  }
}

class _InvoiceItemCard extends StatelessWidget {
  const _InvoiceItemCard({required this.index, required this.item});

  final int index;
  final ManagerInvoiceItem item;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '$index. ${item.drugName ?? 'بدون نام'}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 7,
              children: [
                if (item.quantity != null)
                  _InvoiceInfo(
                    icon: Icons.numbers,
                    text: 'تعداد: ${_formatQuantity(item.quantity!)}',
                  ),
                if (item.packetQuantity != null)
                  _InvoiceInfo(
                    icon: Icons.inventory_outlined,
                    text: 'بسته: ${item.packetQuantity}',
                  ),
                if (item.purchasePrice != null)
                  _InvoiceInfo(
                    icon: Icons.shopping_cart_outlined,
                    text: 'خرید: ${_formatAmount(item.purchasePrice)}',
                  ),
                if (item.salePrice != null)
                  _InvoiceInfo(
                    icon: Icons.sell_outlined,
                    text: 'فروش: ${_formatAmount(item.salePrice)}',
                  ),
                if (item.expireDate != null)
                  _InvoiceInfo(
                    icon: Icons.event_outlined,
                    text: 'انقضا: ${item.expireDate}',
                  ),
                if (item.batchNumber != null)
                  _InvoiceInfo(
                    icon: Icons.qr_code_2,
                    text: 'بچ: ${item.batchNumber}',
                  ),
                if (item.barcode != null)
                  _InvoiceInfo(
                    icon: Icons.barcode_reader,
                    text: 'بارکد: ${item.barcode}',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final style = emphasize
        ? const TextStyle(fontWeight: FontWeight.w800)
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 115, child: Text('$label:', style: style)),
          Expanded(
            child: Text(value, textAlign: TextAlign.left, style: style),
          ),
        ],
      ),
    );
  }
}

class _InvoiceInfo extends StatelessWidget {
  const _InvoiceInfo({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [Icon(icon, size: 17), const SizedBox(width: 4), Text(text)],
    );
  }
}

class _InvoiceBadge extends StatelessWidget {
  const _InvoiceBadge({required this.text, required this.icon});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.error),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: Theme.of(context).colorScheme.error),
            const SizedBox(width: 4),
            Text(
              text,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InvoiceErrorView extends StatelessWidget {
  const _InvoiceErrorView({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 52),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('تلاش مجدد'),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatQuantity(double value) {
  if (value == value.roundToDouble()) {
    return value.toInt().toString();
  }

  return value.toString();
}

String _formatAmount(String? raw) {
  final normalized = raw?.trim();

  if (normalized == null || normalized.isEmpty) {
    return '-';
  }

  final split = normalized.split('.');
  var integerPart = split.first;

  final negative = integerPart.startsWith('-');

  if (negative) {
    integerPart = integerPart.substring(1);
  }

  final buffer = StringBuffer();

  for (var index = 0; index < integerPart.length; index++) {
    if (index > 0 && (integerPart.length - index) % 3 == 0) {
      buffer.write(',');
    }

    buffer.write(integerPart[index]);
  }

  final result = '${negative ? '-' : ''}$buffer';

  if (split.length < 2) {
    return result;
  }

  final decimalPart = split[1].replaceFirst(RegExp(r'0+$'), '');

  return decimalPart.isEmpty ? result : '$result.$decimalPart';
}
