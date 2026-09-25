import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'amount_words.dart';
import 'sales_invoice.dart';
import 'sales_invoice_export_service.dart';
import 'staff_sales_api.dart';
import 'catalog_item_details.dart';

String money(num value) => value.round().toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => ',');
double amount(String input) => double.tryParse(normalizePersianDigitsToEnglish(input).replaceAll(',', '')) ?? 0;
String jalali(DateTime date) {
  final j = Jalali.fromDateTime(date.toLocal());
  return '${j.year}/${j.month.toString().padLeft(2, '0')}/${j.day.toString().padLeft(2, '0')}';
}

class StaffSalesPage extends StatefulWidget {
  const StaffSalesPage({super.key});
  @override
  State<StaffSalesPage> createState() => _StaffSalesPageState();
}
class _StaffSalesPageState extends State<StaffSalesPage> {
  final api = StaffSalesApi();
  final search = TextEditingController();
  SalesInvoicePage? invoices;
  String? error;
  bool loading = false;
  @override
  void initState() { super.initState(); load(); }
  @override
  void dispose() { api.close(); search.dispose(); super.dispose(); }
  Future<void> load() async {
    setState(() { loading = true; error = null; });
    try { final result = await api.list(query: search.text.trim()); if (mounted) setState(() => invoices = result); }
    catch (e) { if (mounted) setState(() => error = '$e'); }
    finally { if (mounted) setState(() => loading = false); }
  }
  @override
  Widget build(BuildContext context) => Column(children: [
    Padding(padding: const EdgeInsets.all(12), child: Row(children: [
      Expanded(child: TextField(controller: search, decoration: const InputDecoration(
          labelText: 'جستجو در فاکتورهای صادرشده', prefixIcon: Icon(Icons.search)),
          onSubmitted: (_) => load())),
      IconButton(onPressed: load, icon: const Icon(Icons.refresh), tooltip: 'بروزرسانی'),
    ])),
    Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: SizedBox(width: double.infinity,
        child: FilledButton.icon(icon: const Icon(Icons.add), label: const Text('فاکتور جدید'), onPressed: () async {
          final changed = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => StaffInvoiceForm(api: api)));
          if (changed == true) load();
        }))),
    if (loading) const LinearProgressIndicator(),
    if (error != null) Padding(padding: const EdgeInsets.all(12), child: Text(error!)),
    Expanded(child: ListView.builder(itemCount: invoices?.items.length ?? 0,
        itemBuilder: (context, index) {
          final item = invoices!.items[index];
          return ListTile(title: Text('فاکتور ${item.invoiceNumber ?? ''} — ${item.buyerName}'),
              subtitle: Text('${jalali(item.issueDate)} • ${money(amount(item.payableAmount))} ریال'),
              trailing: const Icon(Icons.chevron_left), onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => StaffInvoiceDetails(api: api, id: item.id))));
        })),
  ]);
}

class _Line {
  _Line(this.item, this.quantity, this.price, this.discount);
  final StaffCatalogItem item;
  final double quantity, price, discount;
  double get total => quantity * price - discount;
}

class StaffInvoiceForm extends StatefulWidget {
  const StaffInvoiceForm({required this.api, super.key});
  final StaffSalesApi api;
  @override
  State<StaffInvoiceForm> createState() => _StaffInvoiceFormState();
}
class _StaffInvoiceFormState extends State<StaffInvoiceForm> {
  final buyer = TextEditingController();
  final nationalId = TextEditingController();
  final phone = TextEditingController();
  final address = TextEditingController();
  final query = TextEditingController();
  final searchFieldKey = GlobalKey();
  void showSearchAboveKeyboard() {
    Future<void>.delayed(const Duration(milliseconds: 280), () {
      final target = searchFieldKey.currentContext;
      if (mounted && target != null && target.mounted) {
        Scrollable.ensureVisible(target, alignment: 0.1,
            duration: const Duration(milliseconds: 220));
      }
    });
  }
  final discount = TextEditingController();
  final notes = TextEditingController();
  final lines = <_Line>[];
  List<StaffCatalogItem> suggestions = [];
  CatalogSortField catalogSort = CatalogSortField.relevance;
  bool sortDescending = false;
  List<StaffCatalogItem> get sortedSuggestions => sortCatalogMatches(
      suggestions, field: catalogSort, descending: sortDescending,
      name: (item) => item.name, shape: (item) => item.shape,
      alternateName: (item) => item.alternateName);
  void toggleSort(CatalogSortField field) => setState(() {
    if (catalogSort == field) { sortDescending = !sortDescending; }
    else { catalogSort = field; sortDescending = false; }
  });
  Timer? debounce;
  Jalali date = Jalali.now();
  bool saving = false;
  @override
  void initState() { super.initState(); query.addListener(search); discount.addListener(refresh); }
  void refresh() { if (mounted) setState(() {}); }
  @override
  void dispose() {
    debounce?.cancel(); for (final c in [buyer, nationalId, phone, address, query, discount, notes]) { c.dispose(); }
    super.dispose();
  }
  void search() {
    debounce?.cancel();
    final text = query.text.trim();
    if (text.length < 2) { setState(() => suggestions = []); return; }
    debounce = Timer(const Duration(milliseconds: 350), () async {
      try { final result = await widget.api.search(text); if (mounted && query.text.trim() == text) setState(() => suggestions = result); }
      catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
    });
  }
  double get subtotal => lines.fold(0, (double sum, line) => sum + line.total);
  void notify(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  Future<void> edit(StaffCatalogItem item, {int? index}) async {
    if (index == null && lines.any((line) => line.item.id == item.id)) { notify('این قلم قبلاً اضافه شده است.'); return; }
    final line = await showDialog<_Line>(context: context,
        builder: (_) => _LineDialog(item: item, initial: index == null ? null : lines[index]));
    if (line == null || !mounted) return;
    setState(() { if (index == null) { lines.add(line); } else { lines[index] = line; }
      query.clear(); suggestions = []; });
  }
  Future<void> save() async {
    if (buyer.text.trim().isEmpty || lines.isEmpty) { notify('نام خریدار و حداقل یک قلم لازم است.'); return; }
    if (amount(discount.text) > subtotal) { notify('تخفیف از جمع فاکتور بیشتر است.'); return; }
    setState(() => saving = true);
    try {
      final invoice = await widget.api.create({
        'issueDate': date.toDateTime().toIso8601String(), 'buyerName': buyer.text.trim(),
        if (nationalId.text.trim().isNotEmpty) 'buyerNationalId': nationalId.text.trim(),
        if (phone.text.trim().isNotEmpty) 'buyerPhone': phone.text.trim(),
        if (address.text.trim().isNotEmpty) 'buyerAddress': address.text.trim(),
        'discount': amount(discount.text),
        if (notes.text.trim().isNotEmpty) 'notes': notes.text.trim(),
        'items': lines.map((line) => {'catalogItemId': line.item.id,
            'quantity': line.quantity, 'unitPrice': line.price, 'lineDiscount': line.discount}).toList(),
      });
      if (!mounted) return;
      await Navigator.push(context, MaterialPageRoute(builder: (_) => StaffInvoiceDetails(api: widget.api, id: invoice.id)));
      if (mounted) Navigator.pop(context, true);
    } catch (e) { if (mounted) notify('صدور فاکتور انجام نشد: $e'); }
    finally { if (mounted) setState(() => saving = false); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('صدور فاکتور فروش')),
      resizeToAvoidBottomInset: true,
      body: ListView(keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag, padding: const EdgeInsets.all(12), children: [
        TextField(controller: buyer, decoration: const InputDecoration(labelText: 'نام و نام خانوادگی خریدار')),
        TextField(controller: nationalId, decoration: const InputDecoration(labelText: 'کد/شناسه ملی (اختیاری)')),
        TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'تلفن (اختیاری)')),
        TextField(controller: address, decoration: const InputDecoration(labelText: 'نشانی خریدار (اختیاری)')),
        OutlinedButton.icon(onPressed: () async {
          final picked = await showDatePicker(context: context, initialDate: date.toDateTime(),
              firstDate: Jalali(1390).toDateTime(), lastDate: Jalali(1450, 12, 29).toDateTime());
          if (picked != null) setState(() => date = Jalali.fromDateTime(picked));
        }, icon: const Icon(Icons.calendar_month), label: Text('تاریخ فاکتور: ${jalali(date.toDateTime())}')),
        const SizedBox(height: 12),
        TextField(key: searchFieldKey, onTap: showSearchAboveKeyboard,
            controller: query, decoration: const InputDecoration(labelText: 'جستجو و افزودن دارو / کالا', prefixIcon: Icon(Icons.search))),
        if (suggestions.isNotEmpty) Row(children: [
          TextButton(onPressed: () => toggleSort(CatalogSortField.relevance), child: const Text('ارتباط')),
          TextButton(onPressed: () => toggleSort(CatalogSortField.dose), child: Text('دوز/حجم ${catalogSort == CatalogSortField.dose ? (sortDescending ? '↓' : '↑') : ''}')),
          TextButton(onPressed: () => toggleSort(CatalogSortField.shape), child: Text('شکل ${catalogSort == CatalogSortField.shape ? (sortDescending ? '↓' : '↑') : ''}')),
        ]),
        if (suggestions.isNotEmpty) SizedBox(height: 260, child: ListView.builder(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          itemCount: sortedSuggestions.length,
          itemBuilder: (context, index) {
            final item = sortedSuggestions[index];
            return ListTile(title: Text(item.name),
              subtitle: Text('${item.details}\nقیمت فروش: ${money(item.price)} ریال'),
              isThreeLine: true, onTap: () => edit(item));
          },
        )),
        ...lines.asMap().entries.map((entry) => Card(child: ListTile(
            title: Text(entry.value.item.name),
            subtitle: Text('${entry.value.quantity} × ${money(entry.value.price)} — جمع ${money(entry.value.total)} ریال'),
            onTap: () => edit(entry.value.item, index: entry.key),
            trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => setState(() => lines.removeAt(entry.key)))))),
        TextField(controller: discount, keyboardType: TextInputType.number,
            inputFormatters: [ThousandsFormatter()], decoration: const InputDecoration(labelText: 'تخفیف کل (ریال)')),
        TextField(controller: notes, decoration: const InputDecoration(labelText: 'توضیحات (اختیاری)')),
        Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text('قابل پرداخت: ${money((subtotal - amount(discount.text)).clamp(0, double.infinity))} ریال',
            style: Theme.of(context).textTheme.titleLarge)),
        FilledButton(onPressed: saving ? null : save, child: Text(saving ? 'در حال ثبت...' : 'صدور فاکتور')),
      ]));
}

class ThousandsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = normalizePersianDigitsToEnglish(newValue.text).replaceAll(RegExp(r'[^0-9]'), '');
    final formatted = digits.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
    return TextEditingValue(text: formatted, selection: TextSelection.collapsed(offset: formatted.length));
  }
}
class _LineDialog extends StatefulWidget {
  const _LineDialog({required this.item, this.initial});
  final StaffCatalogItem item;
  final _Line? initial;
  @override
  State<_LineDialog> createState() => _LineDialogState();
}
class _LineDialogState extends State<_LineDialog> {
  late final TextEditingController quantity;
  late final TextEditingController price;
  late final TextEditingController discount;
  final quantityFocus = FocusNode();
  @override
  void initState() { super.initState();
    quantity = TextEditingController(text: '${widget.initial?.quantity ?? 1}');
    price = TextEditingController(text: money(widget.initial?.price ?? widget.item.price));
    discount = TextEditingController(text: money(widget.initial?.discount ?? 0));
    WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) quantityFocus.requestFocus();
  }); }
  @override
  void dispose() { quantity.dispose(); price.dispose(); discount.dispose(); quantityFocus.dispose(); super.dispose(); }
  void adjust(int delta) {
    final value = ((double.tryParse(quantity.text) ?? 1) + delta).clamp(1, double.infinity).toDouble();
    quantity.text = value == value.roundToDouble() ? '${value.toInt()}' : '$value';
    quantity.selection = TextSelection.collapsed(offset: quantity.text.length);
  }
  @override
  Widget build(BuildContext context) => AlertDialog(title: Text(widget.item.name), content: SingleChildScrollView(child:
      Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [IconButton(onPressed: () => adjust(1), icon: const Icon(Icons.add)),
          Expanded(child: TextField(controller: quantity, focusNode: quantityFocus, autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'تعداد'))),
          IconButton(onPressed: () => adjust(-1), icon: const Icon(Icons.remove))]),
        TextField(controller: price, keyboardType: TextInputType.number,
            inputFormatters: [ThousandsFormatter()], onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'قیمت واحد (ریال، قابل ویرایش)')),
        Text(amountToPersianWords(amount(price.text).round()) ?? 'صفر تومان'),
        TextField(controller: discount, keyboardType: TextInputType.number,
            inputFormatters: [ThousandsFormatter()], decoration: const InputDecoration(labelText: 'تخفیف این ردیف (ریال)')),
      ])), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('انصراف')),
        FilledButton(onPressed: () {
          final count = double.tryParse(quantity.text) ?? 0;
          final unit = amount(price.text), rebate = amount(discount.text);
          if (count <= 0 || rebate > count * unit) return;
          Navigator.pop(context, _Line(widget.item, count, unit, rebate));
        }, child: const Text('افزودن'))]);
}

class StaffInvoiceDetails extends StatefulWidget {
  const StaffInvoiceDetails({required this.api, required this.id, super.key});
  final StaffSalesApi api;
  final String id;
  @override
  State<StaffInvoiceDetails> createState() => _StaffInvoiceDetailsState();
}

class _StaffInvoiceDetailsState extends State<StaffInvoiceDetails> {
  final captureKey = GlobalKey();
  late final Future<SalesInvoiceDetails> invoiceFuture;
  bool working = false;

  @override
  void initState() {
    super.initState();
    invoiceFuture = widget.api.detail(widget.id);
  }

  Future<Uint8List> captureImage() async {
    final boundary = captureKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) throw StateError('فاکتور برای ذخیره تصویر آماده نیست.');
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) throw StateError('ساخت تصویر فاکتور ممکن نشد.');
    return bytes.buffer.asUint8List();
  }

  Future<void> exportImage(SalesInvoiceDetails invoice, {required bool share}) async {
    setState(() => working = true);
    try {
      final bytes = await captureImage();
      final name = 'sales_invoice_${invoice.invoiceNumber ?? invoice.id}.png';
      if (share) {
        final file = File(p.join((await getTemporaryDirectory()).path, name));
        await file.writeAsBytes(bytes, flush: true);
        await SharePlus.instance.share(ShareParams(
          files: [XFile(file.path, mimeType: 'image/png')],
          fileNameOverrides: [name],
          text: 'فاکتور فروش ${invoice.invoiceNumber ?? ''}',
        ));
      } else {
        await FilePicker.platform.saveFile(
          dialogTitle: 'ذخیره تصویر فاکتور', fileName: name,
          type: FileType.custom, allowedExtensions: const ['png'], bytes: bytes,
        );
      }
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خروجی تصویر انجام نشد: $error')));
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('مشاهده فاکتور فروش')),
      body: FutureBuilder<SalesInvoiceDetails>(future: invoiceFuture, builder: (context, snapshot) {
        if (!snapshot.hasData) return Center(child: Text(snapshot.hasError ? '${snapshot.error}' : 'در حال دریافت فاکتور...'));
        final invoice = snapshot.data!;
        final exporter = SalesInvoiceExportService();
        return ListView(padding: const EdgeInsets.all(12), children: [
          RepaintBoundary(key: captureKey, child: Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Image.asset('assets/branding/logo.png', height: 70),
            Text(invoice.sellerName, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
            ...[('تاریخ فاکتور:', jalali(invoice.issueDate)), ('شماره فاکتور:', invoice.invoiceNumber ?? '-'),
                ('نوع نسخه:', 'فروش دستی'), ('نام و نام خانوادگی:', invoice.buyerName)].map((row) => Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(row.$1), Flexible(child: Text(row.$2))])),
            const Divider(),
            ...invoice.items.map((item) => ListTile(title: Text(item.itemName),
                subtitle: Text('${item.quantity} × ${money(amount(item.unitPrice))} ریال'),
                trailing: Text(money(amount(item.lineTotal))))),
            const Divider(),
            Text('قیمت کل اقلام: ${money(amount(invoice.subtotal))} ریال'),
            if (amount(invoice.discount) > 0) Text('تخفیف: ${money(amount(invoice.discount))} ریال'),
            Text('قابل پرداخت: ${money(amount(invoice.payableAmount))} ریال',
                style: Theme.of(context).textTheme.titleMedium),
            Text(amountToPersianWords(amount(invoice.payableAmount).round()) ?? ''),
            if (invoice.notes != null) Text('توضیحات: ${invoice.notes}'),
            if (invoice.sellerAddress != null) Text(invoice.sellerAddress!),
            if (invoice.sellerPhone != null) Text(invoice.sellerPhone!),
          ])))),
          Wrap(spacing: 8, children: [
            if (!kIsWeb) FilledButton.icon(icon: const Icon(Icons.picture_as_pdf), label: const Text('اشتراک PDF'),
                onPressed: working ? null : () => exporter.sharePdf(invoice)),
            OutlinedButton.icon(icon: const Icon(Icons.download), label: const Text('ذخیره / چاپ PDF'),
                onPressed: working ? null : () => exporter.savePdf(invoice)),
            if (!kIsWeb) FilledButton.tonalIcon(icon: const Icon(Icons.image_outlined),
                label: const Text('اشتراک تصویر'),
                onPressed: working ? null : () => exportImage(invoice, share: true)),
            OutlinedButton.icon(icon: const Icon(Icons.save_alt_outlined),
                label: const Text('ذخیره تصویر'),
                onPressed: working ? null : () => exportImage(invoice, share: false)),
          ]),
        ]);
      }));
}
