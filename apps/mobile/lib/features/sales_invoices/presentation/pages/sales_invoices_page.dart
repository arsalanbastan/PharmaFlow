import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:sales_invoices_ui/sales_api.dart';
import 'package:sales_invoices_ui/sales_invoice_form.dart'
    show StaffInvoiceForm;

import '../../../../core/auth/manager_app_auth_gate.dart';
import '../../../../core/network/api_client.dart';
import '../../data/manager_sales_pos_bridge.dart';

import '../../../../shared/widgets/date_picker/pharmaflow_date_picker.dart';
import '../../../cheques/presentation/utils/cheque_text_utils.dart';
import '../../../settings/presentation/providers/communication_settings_provider.dart';
import '../../data/sales_invoices_repository.dart';
import '../../domain/sales_invoice.dart';
import '../services/sales_invoice_export_service.dart';

class SalesInvoicesPage extends ConsumerStatefulWidget {
  const SalesInvoicesPage({super.key});

  @override
  ConsumerState<SalesInvoicesPage> createState() => _SalesInvoicesPageState();
}

class _SalesInvoicesPageState extends ConsumerState<SalesInvoicesPage> {
  final _searchController = TextEditingController();
  final List<SalesInvoiceSummary> _items = [];
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  String _query = '';
  int _page = 1;
  int _totalPages = 1;
  int _totalCount = 0;

  SalesInvoicesRepository get _repository =>
      SalesInvoicesRepository(ref.read(apiClientProvider));

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({required bool reset}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
        _page = 1;
      });
    } else {
      if (_loadingMore || _page >= _totalPages) return;
      setState(() => _loadingMore = true);
    }
    try {
      final result = await _repository.getPage(
        query: _query,
        page: reset ? 1 : _page + 1,
      );
      if (!mounted) return;
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
      if (mounted) setState(() => _error = 'دریافت فاکتورهای فروش انجام نشد.');
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  bool _showHistory = false;

  SalesApi _salesApi(BuildContext context) {
    final api = ref.read(apiClientProvider);
    final canManage =
        ManagerAccessScope.maybeOf(context)?.user.isManager == true;
    return SalesApi((path, {body, method}) async {
      final uri = Uri.parse(path);
      final result = switch (method) {
        'PUT' => await api.put(uri.path, body: body),
        _ when body != null => await api.post(uri.path, body: body),
        _ => await api.get(
          uri.path,
          queryParameters: uri.hasQuery ? uri.queryParameters : null,
        ),
      };
      if (result is! Map<String, dynamic>) {
        throw const ApiDecodingException('Expected a sales invoice response.');
      }
      return result;
    }, canManage: () async => canManage);
  }

  StaffInvoiceForm _form(BuildContext context, {VoidCallback? onHistory}) =>
      StaffInvoiceForm(
        api: _salesApi(context),
        posBridgeRequest: managerSalesPosBridgeRequest,
        onHistory: onHistory,
        pickDate: (context, initialDate) => PharmaFlowDatePicker.show(
          context: context,
          initialDate: initialDate,
          firstDate: Jalali(1390, 1, 1),
          lastDate: Jalali(1450, 12, 29),
        ),
      );

  void _openHistory() {
    setState(() => _showHistory = true);
    _load(reset: true);
  }

  void _openCreate() => setState(() => _showHistory = false);

  Future<void> _openProfile() async {
    final profile = await _repository.getProfile();
    if (!mounted) return;
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) =>
          _SalesProfileDialog(repository: _repository, profile: profile),
    );
    if (changed == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('مشخصات فروشنده ذخیره شد.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_showHistory) return _form(context, onHistory: _openHistory);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('فاکتورهای فروش'),
          actions: [
            IconButton(
              tooltip: 'مشخصات فروشنده',
              onPressed: _openProfile,
              icon: const Icon(Icons.storefront_outlined),
            ),
            IconButton(
              tooltip: 'بروزرسانی',
              onPressed: () => _load(reset: true),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _openCreate,
          icon: const Icon(Icons.add),
          label: const Text('فاکتور جدید'),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) {
                  _query = _searchController.text.trim();
                  _load(reset: true);
                },
                decoration: InputDecoration(
                  labelText: 'جستجو در فاکتورهای صادرشده',
                  hintText: 'شماره فاکتور، نام یا مشخصات خریدار',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    onPressed: () {
                      _query = _searchController.text.trim();
                      _load(reset: true);
                    },
                    icon: const Icon(Icons.arrow_back),
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
                  child: Text('$_totalCount فاکتور صادرشده'),
                ),
              ),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _items.isEmpty) {
      return Center(
        child: FilledButton.icon(
          onPressed: () => _load(reset: true),
          icon: const Icon(Icons.refresh),
          label: Text(_error!),
        ),
      );
    }
    if (_items.isEmpty) {
      return const Center(child: Text('هنوز فاکتور فروشی صادر نشده است.'));
    }
    return RefreshIndicator(
      onRefresh: () => _load(reset: true),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 90),
        itemCount: _items.length + 1,
        itemBuilder: (context, index) {
          if (index == _items.length) {
            if (_page >= _totalPages) return const SizedBox(height: 8);
            return Center(
              child: TextButton.icon(
                onPressed: _loadingMore ? null : () => _load(reset: false),
                icon: _loadingMore
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.expand_more),
                label: const Text('نمایش بیشتر'),
              ),
            );
          }
          final invoice = _items[index];
          return Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.receipt_outlined)),
              title: Text(
                '${invoice.invoiceNumber ?? '-'} — ${invoice.buyerName}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                '${_jalali(invoice.issueDate)} • ${invoice.itemCount} قلم • ${_money(invoice.payableAmount)} ریال',
              ),
              trailing: IconButton(
                tooltip: 'اشتراک PDF',
                onPressed: () async {
                  final details = await _repository.getById(invoice.id);
                  await const SalesInvoiceExportService().sharePdf(details);
                },
                icon: const Icon(Icons.share_outlined),
              ),
              onTap: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => SalesInvoiceDetailsPage(
                    invoiceId: invoice.id,
                    repository: _repository,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class SalesInvoiceDetailsPage extends StatefulWidget {
  const SalesInvoiceDetailsPage({
    required this.repository,
    this.invoiceId,
    this.invoice,
    super.key,
  }) : assert(invoiceId != null || invoice != null);

  final String? invoiceId;
  final SalesInvoiceDetails? invoice;
  final SalesInvoicesRepository repository;

  @override
  State<SalesInvoiceDetailsPage> createState() =>
      _SalesInvoiceDetailsPageState();
}

class _SalesInvoiceDetailsPageState extends State<SalesInvoiceDetailsPage> {
  final _captureKey = GlobalKey();
  final _exporter = const SalesInvoiceExportService();
  late Future<SalesInvoiceDetails> _future;
  bool _working = false;

  @override
  void initState() {
    super.initState();
    _future = widget.invoice == null
        ? widget.repository.getById(widget.invoiceId!)
        : Future.value(widget.invoice!);
  }

  Future<Uint8List> _capture() async {
    final boundary =
        _captureKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) throw StateError('Unable to render invoice image.');
    return data.buffer.asUint8List();
  }

  Future<void> _shareImage(SalesInvoiceDetails invoice) async {
    setState(() => _working = true);
    try {
      final bytes = await _capture();
      final name = 'sales_invoice_${invoice.invoiceNumber ?? invoice.id}.png';
      final file = File(p.join((await getTemporaryDirectory()).path, name));
      await file.writeAsBytes(bytes, flush: true);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'image/png')],
          fileNameOverrides: [name],
          text: 'فاکتور فروش ${invoice.invoiceNumber ?? ''}',
        ),
      );
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _saveImage(SalesInvoiceDetails invoice) async {
    setState(() => _working = true);
    try {
      final bytes = await _capture();
      await FilePicker.platform.saveFile(
        dialogTitle: 'ذخیره تصویر فاکتور',
        fileName: 'sales_invoice_${invoice.invoiceNumber ?? invoice.id}.png',
        type: FileType.custom,
        allowedExtensions: const ['png'],
        bytes: bytes,
      );
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('مشاهده فاکتور فروش')),
        body: FutureBuilder<SalesInvoiceDetails>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final invoice = snapshot.data;
            if (invoice == null)
              return const Center(child: Text('فاکتور دریافت نشد.'));
            return ListView(
              padding: const EdgeInsets.all(12),
              children: [
                RepaintBoundary(
                  key: _captureKey,
                  child: _SalesInvoiceDocument(invoice: invoice),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    FilledButton.icon(
                      onPressed: _working
                          ? null
                          : () => _exporter.sharePdf(invoice),
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      label: const Text('اشتراک PDF'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _working
                          ? null
                          : () => _exporter.savePdf(invoice),
                      icon: const Icon(Icons.download_outlined),
                      label: const Text('ذخیره PDF'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: _working ? null : () => _shareImage(invoice),
                      icon: const Icon(Icons.image_outlined),
                      label: const Text('اشتراک تصویر'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _working ? null : () => _saveImage(invoice),
                      icon: const Icon(Icons.save_alt_outlined),
                      label: const Text('ذخیره تصویر'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SalesInvoiceDocument extends StatelessWidget {
  const _SalesInvoiceDocument({required this.invoice});
  final SalesInvoiceDetails invoice;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: Center(
        child: Container(
          width: 380,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.black54),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Image.asset(
                  'assets/branding/logo.png',
                  width: 100,
                  height: 82,
                  fit: BoxFit.contain,
                ),
              ),
              Text(
                invoice.sellerName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (invoice.sellerLegalName != null)
                Text(
                  invoice.sellerLegalName!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11),
                ),
              const SizedBox(height: 6),
              Table(
                border: TableBorder.all(color: Colors.black54),
                columnWidths: const {
                  0: FlexColumnWidth(3),
                  1: FlexColumnWidth(2),
                },
                children: [
                  _tableRow(['تاریخ فاکتور:', _jalali(invoice.issueDate)]),
                  _tableRow(['شماره فاکتور:', invoice.invoiceNumber ?? '-']),
                  _tableRow(['نوع نسخه:', 'فروش دستی']),
                  _tableRow(['نام و نام خانوادگی:', invoice.buyerName]),
                ],
              ),
              Table(
                border: TableBorder.all(color: Colors.black54),
                columnWidths: const {
                  0: FlexColumnWidth(5),
                  1: FlexColumnWidth(1.2),
                  2: FlexColumnWidth(2.2),
                },
                children: [
                  _tableRow(['شرح', 'تعداد', 'مبلغ'], header: true),
                  ...invoice.items.map(
                    (item) => _tableRow([
                      '${item.itemName}\nفی: ${_money(item.unitPrice)}',
                      _quantity(double.parse(item.quantity)),
                      _money(item.lineTotal),
                    ]),
                  ),
                ],
              ),
              _totalLine('قیمت کل اقلام', invoice.subtotal),
              if (double.parse(invoice.discount) > 0)
                _totalLine('تخفیف', invoice.discount),
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black87),
                ),
                child: Column(
                  children: [
                    _totalLine(
                      'قابل پرداخت',
                      invoice.payableAmount,
                      bold: true,
                    ),
                    if (amountToPersianWords(
                          double.parse(invoice.payableAmount).round(),
                        ) !=
                        null)
                      Text(
                        amountToPersianWords(
                          double.parse(invoice.payableAmount).round(),
                        )!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                  ],
                ),
              ),
              if (invoice.notes != null) ...[
                const SizedBox(height: 8),
                Text('توضیحات: ${invoice.notes}'),
              ],
              const SizedBox(height: 8),
              if (invoice.sellerAddress != null)
                Text(invoice.sellerAddress!, textAlign: TextAlign.center),
              if (invoice.sellerPhone != null)
                Text(
                  invoice.sellerPhone!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  TableRow _tableRow(List<String> values, {bool header = false}) {
    return TableRow(
      decoration: header ? const BoxDecoration(color: Color(0xFFECEFF1)) : null,
      children: values
          .map(
            (value) => Padding(
              padding: const EdgeInsets.all(6),
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: header ? FontWeight.w800 : null,
                ),
              ),
            ),
          )
          .toList(growable: false),
    );
  }

  Widget _totalLine(String label, String amount, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontWeight: bold ? FontWeight.w900 : null),
          ),
          Text(
            '${_money(amount)} ریال',
            style: TextStyle(fontWeight: bold ? FontWeight.w900 : null),
          ),
        ],
      ),
    );
  }
}

class _SalesProfileDialog extends StatefulWidget {
  const _SalesProfileDialog({required this.repository, required this.profile});
  final SalesInvoicesRepository repository;
  final SalesInvoiceProfile profile;

  @override
  State<_SalesProfileDialog> createState() => _SalesProfileDialogState();
}

class _SalesProfileDialogState extends State<_SalesProfileDialog> {
  late final TextEditingController _name;
  late final TextEditingController _legalName;
  late final TextEditingController _nationalId;
  late final TextEditingController _economicCode;
  late final TextEditingController _phone;
  late final TextEditingController _address;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.profile.sellerName);
    _legalName = TextEditingController(text: widget.profile.legalName);
    _nationalId = TextEditingController(text: widget.profile.nationalId);
    _economicCode = TextEditingController(text: widget.profile.economicCode);
    _phone = TextEditingController(text: widget.profile.phone);
    _address = TextEditingController(text: widget.profile.address);
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _legalName,
      _nationalId,
      _economicCode,
      _phone,
      _address,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('مشخصات فروشنده در فاکتور'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _field(_name, 'نام فروشنده'),
            _field(_legalName, 'نام قانونی / صاحب امتیاز'),
            _field(_nationalId, 'شناسه ملی'),
            _field(_economicCode, 'کد اقتصادی'),
            _field(_phone, 'تلفن'),
            _field(_address, 'نشانی', maxLines: 2),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('انصراف'),
        ),
        FilledButton(
          onPressed: _saving
              ? null
              : () async {
                  if (_name.text.trim().isEmpty) return;
                  setState(() => _saving = true);
                  try {
                    await widget.repository.updateProfile({
                      'sellerName': _name.text.trim(),
                      'legalName': _legalName.text.trim(),
                      'nationalId': _nationalId.text.trim(),
                      'economicCode': _economicCode.text.trim(),
                      'phone': _phone.text.trim(),
                      'address': _address.text.trim(),
                    });
                    if (context.mounted) Navigator.pop(context, true);
                  } finally {
                    if (mounted) setState(() => _saving = false);
                  }
                },
          child: const Text('ذخیره'),
        ),
      ],
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}

double _parseAmount(String raw) =>
    double.tryParse(raw.replaceAll(',', '').trim()) ?? 0;

String _money(String raw) {
  final value = double.tryParse(raw) ?? 0;
  final digits = value.round().toString();
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) buffer.write(',');
    buffer.write(digits[index]);
  }
  return buffer.toString();
}

String _quantity(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toString();

String _jalali(DateTime date) =>
    _formatJalali(Jalali.fromDateTime(date.toLocal()));

String _formatJalali(Jalali date) =>
    '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
