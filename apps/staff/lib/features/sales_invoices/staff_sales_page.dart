import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sales_invoices_ui/sales_invoice.dart';
import 'package:sales_invoices_ui/sales_invoice_form.dart';
import 'package:shamsi_date/shamsi_date.dart';

import '../../shared/widgets/date_picker/pharmaflow_date_picker.dart';
import 'sales_invoice_export_service.dart';
import 'staff_sales_api.dart';

Future<Jalali?> _pickDate(BuildContext context, Jalali initialDate) =>
    PharmaFlowDatePicker.show(
      context: context,
      initialDate: initialDate,
      firstDate: Jalali(1390, 1, 1),
      lastDate: Jalali(1450, 12, 29),
    );

class StaffSalesPage extends StatefulWidget {
  const StaffSalesPage({super.key, this.onReturnHome});
  final VoidCallback? onReturnHome;
  @override
  State<StaffSalesPage> createState() => StaffSalesPageState();
}

class StaffSalesPageState extends State<StaffSalesPage> {
  final api = StaffSalesApi();
  final search = TextEditingController();
  final _export = SalesInvoiceExportService();
  SalesInvoicePage? invoices;
  String? error;
  bool loading = false;
  Timer? invoiceSearchDebounce;
  bool _openingCreate = false;
  int _loadGeneration = 0;

  Future<void> openCreate() => _openCreate();

  Future<void> _openCreate() async {
    if (_openingCreate || !mounted) return;
    _openingCreate = true;
    try {
      final result = await Navigator.of(context, rootNavigator: true)
          .push<String>(
            MaterialPageRoute<String>(
              builder: (_) => StaffInvoiceForm(
                api: api,
                pickDate: _pickDate,
                onSharePdf: kIsWeb ? null : _export.sharePdf,
              ),
            ),
          );
      if (!mounted) return;
      if (result == 'home') {
        widget.onReturnHome?.call();
      } else {
        await load();
      }
    } finally {
      _openingCreate = false;
    }
  }

  @override
  void dispose() {
    invoiceSearchDebounce?.cancel();
    api.close();
    search.dispose();
    super.dispose();
  }

  Future<void> load({bool nextPage = false}) async {
    if (nextPage && (loading || invoices == null)) return;
    final generation = ++_loadGeneration;
    final previous = nextPage ? invoices : null;
    final requestedQuery = search.text.trim();
    setState(() {
      loading = true;
      error = null;
      if (!nextPage) invoices = null;
    });
    try {
      final result = await api.list(
        query: requestedQuery,
        page: (previous?.page ?? 0) + 1,
      );
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        invoices = previous == null
            ? result
            : SalesInvoicePage(
                items: [...previous.items, ...result.items],
                page: result.page,
                totalPages: result.totalPages,
                totalCount: result.totalCount,
              );
      });
    } catch (e) {
      if (mounted && generation == _loadGeneration) {
        setState(() => error = '$e');
      }
    } finally {
      if (mounted && generation == _loadGeneration) {
        setState(() => loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      appBar: AppBar(title: const Text('فاکتورهای فروش')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: search,
                    decoration: const InputDecoration(
                      labelText: 'جستجو در فاکتورهای صادرشده',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (_) {
                      invoiceSearchDebounce?.cancel();
                      invoiceSearchDebounce = Timer(
                        const Duration(milliseconds: 300),
                        load,
                      );
                    },
                    onSubmitted: (_) => load(),
                  ),
                ),
                IconButton(
                  onPressed: load,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'بروزرسانی',
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('فاکتور جدید'),
                onPressed: _openCreate,
              ),
            ),
          ),
          if (loading) const LinearProgressIndicator(),
          if (error != null)
            Padding(padding: const EdgeInsets.all(12), child: Text(error!)),
          Expanded(
            child: ListView.builder(
              itemCount: invoices?.items.length ?? 0,
              itemBuilder: (context, index) {
                final item = invoices!.items[index];
                return ListTile(
                  title: Text(
                    'فاکتور ${item.invoiceNumber ?? ''} — ${item.buyerName}',
                  ),
                  subtitle: Text(
                    '${jalali(item.issueDate)} • ${money(amount(item.payableAmount))} ریال',
                  ),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () async {
                    final action = await Navigator.push<String>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => StaffInvoiceDetails(
                          api: api,
                          id: item.id,
                          onSharePdf: kIsWeb ? null : _export.sharePdf,
                        ),
                      ),
                    );
                    if (!mounted) return;
                    if (action == 'new') {
                      openCreate();
                    } else if (action == 'home') {
                      widget.onReturnHome?.call();
                    }
                  },
                );
              },
            ),
          ),
          if (invoices case final page? when page.page < page.totalPages)
            TextButton(
              onPressed: loading ? null : () => load(nextPage: true),
              child: const Text('نمایش بیشتر'),
            ),
        ],
      ),
    ),
  );
}
