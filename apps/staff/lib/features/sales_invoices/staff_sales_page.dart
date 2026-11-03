import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shamsi_date/shamsi_date.dart';
import '../../shared/widgets/date_picker/pharmaflow_date_picker.dart';
import 'amount_words.dart';
import 'sales_invoice.dart';
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
  const StaffSalesPage({super.key, this.onReturnHome});
  final VoidCallback? onReturnHome;
  @override
  State<StaffSalesPage> createState() => StaffSalesPageState();
}
class StaffSalesPageState extends State<StaffSalesPage> {
  final api = StaffSalesApi();
  final search = TextEditingController();
  SalesInvoicePage? invoices;
  String? error;
  bool loading = false;
  Timer? invoiceSearchDebounce;
  bool _openingCreate = false;

  Future<void> openCreate() => _openCreate();

  Future<void> _openCreate() async {
    if (_openingCreate || !mounted) return;
    _openingCreate = true;
    try {
      final result = await Navigator.of(context, rootNavigator: true).push<String>(
        MaterialPageRoute<String>(
          builder: (_) => StaffInvoiceForm(api: api),
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
  void dispose() { invoiceSearchDebounce?.cancel(); api.close(); search.dispose(); super.dispose(); }
  Future<void> load() async {
    final requestedQuery = search.text.trim();
    setState(() { loading = true; error = null; });
    try { final result = await api.list(query: requestedQuery);
      if (mounted && search.text.trim() == requestedQuery) setState(() => invoices = result); }
    catch (e) { if (mounted && search.text.trim() == requestedQuery) setState(() => error = '$e'); }
    finally { if (mounted && search.text.trim() == requestedQuery) setState(() => loading = false); }
  }
  @override
  Widget build(BuildContext context) => Directionality(textDirection: TextDirection.rtl, child: Column(children: [
    Padding(padding: const EdgeInsets.all(12), child: Row(children: [
      Expanded(child: TextField(controller: search, decoration: const InputDecoration(
          labelText: 'جستجو در فاکتورهای صادرشده', prefixIcon: Icon(Icons.search)),
          onChanged: (_) {
            invoiceSearchDebounce?.cancel();
            invoiceSearchDebounce = Timer(const Duration(milliseconds: 300), load);
          },
          onSubmitted: (_) => load())),
      IconButton(onPressed: load, icon: const Icon(Icons.refresh), tooltip: 'بروزرسانی'),
    ])),
    Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: SizedBox(width: double.infinity,
        child: FilledButton.icon(icon: const Icon(Icons.add), label: const Text('فاکتور جدید'), onPressed: () async {
          final result = await Navigator.push<String>(
            context,
            MaterialPageRoute(builder: (_) => StaffInvoiceForm(api: api)),
          );
          if (!mounted) return;
          if (result == 'home') {
            widget.onReturnHome?.call();
          } else {
            load();
          }
        }))),
    if (loading) const LinearProgressIndicator(),
    if (error != null) Padding(padding: const EdgeInsets.all(12), child: Text(error!)),
    Expanded(child: ListView.builder(itemCount: invoices?.items.length ?? 0,
        itemBuilder: (context, index) {
          final item = invoices!.items[index];
          return ListTile(title: Text('فاکتور ${item.invoiceNumber ?? ''} — ${item.buyerName}'),
              subtitle: Text('${jalali(item.issueDate)} • ${money(amount(item.payableAmount))} ریال'),
              trailing: const Icon(Icons.chevron_left), onTap: () async {
                final action = await Navigator.push<String>(context,
                    MaterialPageRoute(builder: (_) => StaffInvoiceDetails(api: api, id: item.id)));
                if (!mounted) return;
                if (action == 'new') {
                  openCreate();
                } else if (action == 'home') {
                  widget.onReturnHome?.call();
                }
              });
        })),
  ]));
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
  final searchFocus = FocusNode();
  final Map<String, FocusNode> quantityFocusNodes = {};
  final itemsSectionKey = GlobalKey();
  FocusNode _quantityFocusNode(String id) =>
      quantityFocusNodes.putIfAbsent(id, FocusNode.new);
  final MobileScannerController scannerController = MobileScannerController(
    // Let the MobileScanner widget initialize the camera exactly once.
    autoStart: true,
    facing: CameraFacing.back,
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _cameraStarting = false;
  String? _cameraStartError;
  bool scannerBusy = false;
  String? lastScannedCode;
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
  String invoiceType = 'OTC';
  bool saving = false;
  bool canManage = false;
  bool get containsDrug => lines.any((line) => line.item.category.toUpperCase() == 'DRUG');
  double manualTariff = 81000;
  double freeTariff = 727000;
  double get serviceTariff => !containsDrug || invoiceType == 'GOODS'
      ? 0
      : (invoiceType == 'OTC' ? manualTariff : freeTariff);
  double get payable => (subtotal + serviceTariff - amount(discount.text)).clamp(0, double.infinity).toDouble();
  @override
  void initState() {
    super.initState();
    query.addListener(search);
    discount.addListener(refresh);
    _loadTariffs();
    widget.api.canManage().then((value) { if (mounted) setState(() => canManage = value); });
  }

  // Initial start belongs to MobileScanner (autoStart: true). Only retries
  // invoke start() manually, after the previous startup has finished.
  Future<void> _restartInvoiceCamera() async {
    if (!mounted || _cameraStarting || scannerController.value.isStarting) return;
    setState(() {
      _cameraStarting = true;
      _cameraStartError = null;
    });
    try {
      // Release an existing camera stream before requesting a new one.
      await scannerController.stop();
      if (!mounted) return;
      await scannerController.start();
    } catch (error, stack) {
      debugPrint('Staff invoice camera restart failed: $error\n$stack');
      if (mounted) setState(() => _cameraStartError = error.toString());
    } finally {
      if (mounted) setState(() => _cameraStarting = false);
    }
  }

  Future<void> _editTariffs() async {
    try {
      final profile = await widget.api.profile();
      final manual = TextEditingController(text: money(profile.manualServiceTariff));
      final free = TextEditingController(text: money(profile.freeServiceTariff));
      final saved = await showDialog<bool>(context: context, builder: (dialogContext) =>
        Directionality(textDirection: TextDirection.rtl, child: AlertDialog(
          title: const Text('تنظیم تعرفه خدمات دارویی'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: manual, keyboardType: TextInputType.number, inputFormatters: [ThousandsFormatter()], decoration: const InputDecoration(labelText: 'تعرفه فروش OTC (ریال)')),
            TextField(controller: free, keyboardType: TextInputType.number, inputFormatters: [ThousandsFormatter()], decoration: const InputDecoration(labelText: 'تعرفه نسخه آزاد (ریال)')),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('انصراف')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('ذخیره')),
          ],
        )));
      if (saved == true) {
        final updated = await widget.api.updateProfile({
          'sellerName': profile.sellerName,
          if (profile.legalName != null) 'legalName': profile.legalName,
          if (profile.nationalId != null) 'nationalId': profile.nationalId,
          if (profile.economicCode != null) 'economicCode': profile.economicCode,
          if (profile.phone != null) 'phone': profile.phone,
          if (profile.address != null) 'address': profile.address,
          if (profile.logoData != null) 'logoData': profile.logoData,
          'manualServiceTariff': amount(manual.text),
          'freeServiceTariff': amount(free.text),
        });
        if (mounted) setState(() {
          manualTariff = updated.manualServiceTariff;
          freeTariff = updated.freeServiceTariff;
        });
        if (mounted) notify('تعرفه‌ها ذخیره شدند.');
      }
      manual.dispose();
      free.dispose();
    } catch (e) {
      if (mounted) notify('ذخیره تعرفه‌ها انجام نشد: $e');
    }
  }
  Future<void> _loadTariffs() async {
    try {
      final profile = await widget.api.profile();
      if (mounted) setState(() {
        manualTariff = profile.manualServiceTariff;
        freeTariff = profile.freeServiceTariff;
      });
    } catch (_) {
      // The invoice can still be drafted with the documented default tariffs.
    }
  }
  void _resetForm() {
    for (final c in [buyer, nationalId, phone, address, query, discount, notes]) { c.clear(); }
    setState(() {
      lines.clear();
      suggestions = [];
      date = Jalali.now();
      invoiceType = 'OTC';
    });
  }
  void refresh() { if (mounted) setState(() {}); }
  @override
  void dispose() {
    debounce?.cancel(); for (final c in [buyer, nationalId, phone, address, query, discount, notes]) { c.dispose(); }
    searchFocus.dispose();
    scannerController.dispose();
    for (final node in quantityFocusNodes.values) { node.dispose(); }
    super.dispose();
  }
  Future<void> scanBarcode() async {
    final scanned = query.text.trim();
    if (scanned.isEmpty) return;
    debounce?.cancel();
    try {
      final result = await widget.api.search(scanned);
      if (!mounted || query.text.trim() != scanned) return;
      final exact = result.where((item) => item.matchedBarcode == scanned).toList();
      if (exact.length == 1) {
        addItem(exact.single);
      } else {
        setState(() => suggestions = result);
        if (exact.isEmpty) notify('بارکد دقیق پیدا نشد؛ از نتایج جستجو کالا را انتخاب کنید.');
      }
    } catch (e) {
      if (mounted) notify('جستجوی بارکد انجام نشد: $e');
    }
  }
  Future<void> handleScannedBarcode(String rawCode) async {
    final code = rawCode.trim();
    if (code.isEmpty || scannerBusy || code == lastScannedCode) return;
    scannerBusy = true;
    lastScannedCode = code;
    try {
      final result = await widget.api.search(code);
      if (!mounted) return;
      final exact = result.where((item) => item.matchedBarcode == code).toList();
      if (exact.length == 1) {
        addItem(exact.single);
      } else {
        query.text = code;
        setState(() => suggestions = result);
        if (exact.isEmpty) notify('بارکد دقیق پیدا نشد؛ از نتایج جستجو کالا را انتخاب کنید.');
      }
    } catch (e) {
      if (mounted) notify('خواندن بارکد انجام نشد: $e');
    } finally {
      // Keep this barcode locked while it remains in the camera frame.
      // onDetect releases the lock when no barcode is visible.
      scannerBusy = false;
    }
  }

  void search() {
    debounce?.cancel();
    final text = query.text.trim();
    if (suggestions.isNotEmpty) setState(() => suggestions = []);
    if (text.length < 2) return;
    debounce = Timer(const Duration(milliseconds: 220), () async {
      try { final result = await widget.api.search(text); if (mounted && query.text.trim() == text) setState(() => suggestions = result); }
      catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
    });
  }
  double get subtotal => lines.fold(0, (double sum, line) => sum + line.total);
  void notify(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  void addItem(StaffCatalogItem item) {
    final index = lines.indexWhere((line) => line.item.id == item.id);
    setState(() {
      if (index >= 0) {
        final old = lines[index];
        lines[index] = _Line(old.item, old.quantity + 1, old.price,
            old.discount.clamp(0, (old.quantity + 1) * old.price));
      } else {
        lines.add(_Line(item, 1, item.price, 0));
      }
      suggestions = [];
      query.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final sectionContext = itemsSectionKey.currentContext;
      if (sectionContext != null) {
        await Scrollable.ensureVisible(
          sectionContext,
          alignment: 0.15,
          duration: const Duration(milliseconds: 220),
        );
      }
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _quantityFocusNode(item.id).requestFocus();
        });
      }
    });
  }
  void setQuantity(int index, double quantity) {
    if (quantity <= 0) return;
    final old = lines[index];
    setState(() => lines[index] = _Line(old.item, quantity, old.price,
        old.discount.clamp(0, quantity * old.price)));
  }
  Future<void> edit(StaffCatalogItem item, {required int index}) async {
    final line = await showDialog<_Line>(context: context,
        builder: (_) => _LineDialog(item: item, initial: lines[index]));
    if (line == null || !mounted) return;
    setState(() => lines[index] = line);
  }
  Future<void> save() async {
    if (lines.isEmpty) { notify('حداقل یک قلم لازم است.'); return; }
    if (amount(discount.text) > subtotal + serviceTariff) { notify('تخفیف از جمع فاکتور بیشتر است.'); return; }
    setState(() => saving = true);
    try {
      final invoice = await widget.api.create({
        'issueDate': date.toDateTime().toIso8601String(),
        'invoiceType': invoiceType,
        if (buyer.text.trim().isNotEmpty) 'buyerName': buyer.text.trim(),
        if (nationalId.text.trim().isNotEmpty) 'buyerNationalId': nationalId.text.trim(),
        if (phone.text.trim().isNotEmpty) 'buyerPhone': phone.text.trim(),
        if (address.text.trim().isNotEmpty) 'buyerAddress': address.text.trim(),
        'discount': amount(discount.text),
        if (notes.text.trim().isNotEmpty) 'notes': notes.text.trim(),
        'items': lines.map((line) => {'catalogItemId': line.item.id,
            'quantity': line.quantity, 'unitPrice': line.price, 'lineDiscount': line.discount}).toList(),
      });
      if (!mounted) return;
      final action = await Navigator.push<String>(
        context,
        MaterialPageRoute(builder: (_) => StaffInvoiceDetails(api: widget.api, id: invoice.id)),
      );
      if (mounted) {
        if (action == 'new') {
          _resetForm();
        } else if (action == 'home') {
          Navigator.pop(context, 'home');
        } else {
          Navigator.pop(context, 'done');
        }
      }
    } catch (e) { if (mounted) notify('صدور فاکتور انجام نشد: $e'); }
    finally { if (mounted) setState(() => saving = false); }
  }
  Widget _invoiceSection(String title, List<Widget> children, {Key? key}) => Card(
    key: key,
    margin: const EdgeInsets.only(bottom: 14),
    elevation: 1,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('صدور فاکتور فروش'),
        actions: [
          if (canManage)
            IconButton(
              tooltip: 'تنظیم تعرفه خدمات دارویی',
              onPressed: _editTariffs,
              icon: const Icon(Icons.settings),
            ),
          TextButton.icon(
            onPressed: () => Navigator.pop(context, 'history'),
            icon: const Icon(Icons.history),
            label: const Text('فاکتورهای قبلی'),
          ),
        ],
      ),
      resizeToAvoidBottomInset: true,
      body: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.all(12),
        children: [
          _invoiceSection('مشخصات فاکتور', [
            DropdownButtonFormField<String>(
              value: invoiceType,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'نوع فروش'),
              items: const [
                DropdownMenuItem(value: 'GOODS', child: Text('فروش کالا')),
                DropdownMenuItem(value: 'OTC', child: Text('فروش OTC')),
                DropdownMenuItem(value: 'FREE', child: Text('نسخه آزاد')),
              ],
              onChanged: (value) {
                if (value != null) setState(() => invoiceType = value);
              },
            ),
            TextField(controller: buyer, textAlign: TextAlign.right,
              decoration: const InputDecoration(labelText: 'نام و نام خانوادگی خریدار (اختیاری)')),
            TextField(controller: nationalId, textAlign: TextAlign.right,
              keyboardType: TextInputType.number,
              inputFormatters: [PersianDigitsOnlyFormatter()],
              decoration: const InputDecoration(labelText: 'کد/شناسه ملی (اختیاری)')),
            TextField(controller: phone, textAlign: TextAlign.right,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'تلفن (اختیاری)')),
            TextField(controller: address, textAlign: TextAlign.right,
              decoration: const InputDecoration(labelText: 'نشانی خریدار (اختیاری)')),
            OutlinedButton.icon(
              onPressed: () async {
                final picked = await PharmaFlowDatePicker.show(
                  context: context,
                  initialDate: date,
                  firstDate: Jalali(1390, 1, 1),
                  lastDate: Jalali(1450, 12, 29),
                );
                if (picked != null) setState(() => date = picked);
              },
              icon: const Icon(Icons.calendar_month),
              label: Text('تاریخ فاکتور: ${jalali(date.toDateTime())}'),
            ),
          ]),
          _invoiceSection('انتخاب کالا و دارو', [
            Container(
              height: 190,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  MobileScanner(
                    controller: scannerController,
                    onDetect: (capture) {
                      if (capture.barcodes.isEmpty) {
                        lastScannedCode = null;
                        return;
                      }
                      for (final barcode in capture.barcodes) {
                        final value = barcode.rawValue;
                        if (value != null && value.trim().isNotEmpty) {
                          handleScannedBarcode(value);
                          break;
                        }
                      }
                    },
                    errorBuilder: (context, error) => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.no_photography_outlined, size: 34),
                            const SizedBox(height: 8),
                            const Text(
                              'پیش‌نمایش دوربین اجرا نشد. دسترسی دوربین Chrome و مجوز سایت را بررسی کنید؛ جستجوی متنی فعال است.',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 6),
                            SelectableText(
                              error.toString(),
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: _cameraStarting ? null : _restartInvoiceCamera,
                              icon: const Icon(Icons.refresh),
                              label: const Text('تلاش مجدد'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (_cameraStarting || _cameraStartError != null)
                    Positioned.fill(
                      child: ColoredBox(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_cameraStarting) const CircularProgressIndicator(),
                                const SizedBox(height: 8),
                                Text(
                                  _cameraStarting
                                      ? 'در حال فعال‌سازی دوربین پشت...'
                                      : 'راه‌اندازی دوربین انجام نشد',
                                  textAlign: TextAlign.center,
                                ),
                                if (_cameraStartError != null) ...[
                                  const SizedBox(height: 6),
                                  SelectableText(
                                    _cameraStartError!,
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                  TextButton.icon(
                                    onPressed: _restartInvoiceCamera,
                                    icon: const Icon(Icons.refresh),
                                    label: const Text('تلاش مجدد'),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (!_cameraStarting)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: IconButton.filledTonal(
                        tooltip: 'راه‌اندازی مجدد دوربین',
                        onPressed: _restartInvoiceCamera,
                        icon: const Icon(Icons.refresh, size: 20),
                      ),
                    ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: .55),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('بارکد را مقابل دوربین پشت قرار دهید',
                        style: TextStyle(color: Colors.white, fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: searchFieldKey,
              focusNode: searchFocus,
              controller: query,
              textAlign: TextAlign.right,
              onTap: showSearchAboveKeyboard,
              onSubmitted: (_) => scanBarcode(),
              decoration: const InputDecoration(
                labelText: 'جستجوی متنی یا ورود بارکد',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
            if (suggestions.isNotEmpty) Row(children: [
              TextButton(onPressed: () => toggleSort(CatalogSortField.relevance), child: const Text('ارتباط')),
              TextButton(onPressed: () => toggleSort(CatalogSortField.dose),
                child: Text('دوز/حجم ${catalogSort == CatalogSortField.dose ? (sortDescending ? '↓' : '↑') : ''}')),
              TextButton(onPressed: () => toggleSort(CatalogSortField.shape),
                child: Text('شکل ${catalogSort == CatalogSortField.shape ? (sortDescending ? '↓' : '↑') : ''}')),
            ]),
            if (suggestions.isNotEmpty)
              SizedBox(
                height: 260,
                child: ListView.builder(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  itemCount: sortedSuggestions.length,
                  itemBuilder: (context, index) {
                    final item = sortedSuggestions[index];
                    return ListTile(
                      title: Text(item.name),
                      subtitle: Text('${item.details}\nقیمت فروش ثبت‌شده: ${money(item.price)} ریال${item.packetQuantity != null && item.packetQuantity! > 1 ? ' • تعداد در بسته: ${item.packetQuantity}' : ''}'),
                      isThreeLine: true,
                      onTap: () => addItem(item),
                    );
                  },
                ),
              ),
          ]),
          _invoiceSection('اقلام فاکتور و مبالغ', [
            if (lines.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('هنوز کالایی به فاکتور اضافه نشده است.',
                  textAlign: TextAlign.center),
              ),
            ...lines.asMap().entries.map((entry) {
              final item = entry.value.item;
              return Card(
                child: ListTile(
                  title: Text(item.name),
                  subtitle: Text('${money(entry.value.price)} ریال × ${entry.value.quantity} — جمع ${money(entry.value.total)} ریال'),
                  onTap: () => edit(item, index: entry.key),
                  trailing: SizedBox(
                    width: 250,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(tooltip: 'افزایش تعداد',
                          onPressed: () => setQuantity(entry.key, entry.value.quantity + 1),
                          icon: const Icon(Icons.add_circle_outline)),
                        SizedBox(
                          width: 58,
                          child: _QuantityControl(
                            value: entry.value.quantity,
                            focusNode: _quantityFocusNode(item.id),
                            onChanged: (value) => setQuantity(entry.key, value),
                          ),
                        ),
                        IconButton(tooltip: 'کاهش تعداد',
                          onPressed: () => setQuantity(entry.key,
                            (entry.value.quantity - 1).clamp(1, double.infinity).toDouble()),
                          icon: const Icon(Icons.remove_circle_outline)),
                        IconButton(tooltip: 'حذف قلم',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => setState(() => lines.removeAt(entry.key))),
                      ],
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 8),
            Text('جمع اقلام: ${money(subtotal)} ریال'),
            Text('تعرفه خدمات دارویی${containsDrug ? '' : ' (بدون دارو: صفر)'}: ${money(serviceTariff)} ریال'),
            TextField(
              controller: discount,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.right,
              inputFormatters: [ThousandsFormatter()],
              decoration: const InputDecoration(labelText: 'تخفیف کل (ریال)'),
            ),
            TextField(controller: notes, textAlign: TextAlign.right,
              decoration: const InputDecoration(labelText: 'توضیحات (اختیاری)')),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text('قابل پرداخت: ${money(payable)} ریال',
                style: Theme.of(context).textTheme.titleLarge),
            ),
            FilledButton(
              onPressed: saving ? null : save,
              child: Text(saving ? 'در حال ثبت...' : 'صدور فاکتور'),
            ),
          ], key: itemsSectionKey),
        ],
      ),
    ),
  );
}

class PersianDigitsOnlyFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = normalizePersianDigitsToEnglish(newValue.text).replaceAll(RegExp(r'[^0-9]'), '');
    return TextEditingValue(text: digits, selection: TextSelection.collapsed(offset: digits.length));
  }
}

class _QuantityControl extends StatefulWidget {
  const _QuantityControl({required this.value, required this.onChanged, required this.focusNode});
  final double value;
  final ValueChanged<double> onChanged;
  final FocusNode focusNode;
  @override
  State<_QuantityControl> createState() => _QuantityControlState();
}
class _QuantityControlState extends State<_QuantityControl> {
  late final TextEditingController controller;
  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: _text(widget.value));
  }
  @override
  void didUpdateWidget(covariant _QuantityControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && amount(controller.text) != widget.value) {
      controller.text = _text(widget.value);
    }
  }
  String _text(double value) => value == value.roundToDouble() ? '${value.toInt()}' : '$value';
  @override
  void dispose() { controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    focusNode: widget.focusNode,
    textAlign: TextAlign.center,
    onChanged: (text) {
      final value = double.tryParse(normalizePersianDigitsToEnglish(text));
      if (value != null && value > 0) widget.onChanged(value);
    },
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    onTap: () => controller.selection = TextSelection(baseOffset: 0, extentOffset: controller.text.length),
    onSubmitted: (text) {
      final value = double.tryParse(normalizePersianDigitsToEnglish(text));
      if (value != null && value > 0) widget.onChanged(value);
      else controller.text = _text(widget.value);
    },
    onEditingComplete: () {
      final value = double.tryParse(normalizePersianDigitsToEnglish(controller.text));
      if (value != null && value > 0) widget.onChanged(value);
      else controller.text = _text(widget.value);
      FocusScope.of(context).unfocus();
    },
    decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 2), border: OutlineInputBorder()),
  );
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
  Widget build(BuildContext context) => Directionality(textDirection: TextDirection.rtl,
      child: AlertDialog(title: Text(widget.item.name), content: SingleChildScrollView(child:
      Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [IconButton(onPressed: () => adjust(1), icon: const Icon(Icons.add)),
          Expanded(child: TextField(controller: quantity, focusNode: quantityFocus, autofocus: true,
              textAlign: TextAlign.right,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => addLine(),
              decoration: const InputDecoration(labelText: 'تعداد'))),
          IconButton(onPressed: () => adjust(-1), icon: const Icon(Icons.remove))]),
        TextField(controller: price, keyboardType: TextInputType.number, textAlign: TextAlign.right,
            inputFormatters: [ThousandsFormatter()], onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'قیمت واحد (ریال، قابل ویرایش)')),
        Text(amountToPersianWords(amount(price.text).round()) ?? 'صفر تومان'),
        TextField(controller: discount, keyboardType: TextInputType.number, textAlign: TextAlign.right,
            inputFormatters: [ThousandsFormatter()], decoration: const InputDecoration(labelText: 'تخفیف این ردیف (ریال)')),
      ])), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('انصراف')),
        FilledButton(onPressed: addLine, child: const Text('افزودن'))]));

  void addLine() {
    final count = double.tryParse(quantity.text) ?? 0;
    final unit = amount(price.text), rebate = amount(discount.text);
    if (count <= 0 || rebate > count * unit) return;
    Navigator.pop(context, _Line(widget.item, count, unit, rebate));
  }
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

  Widget invoiceRow(String label, String value, {bool emphasized = false}) =>
      Directionality(textDirection: TextDirection.rtl, child: Row(children: [
        Expanded(child: Text(label, textAlign: TextAlign.right,
            style: emphasized ? Theme.of(context).textTheme.titleMedium : null)),
        Expanded(child: Text(value, textAlign: TextAlign.left,
            style: emphasized ? Theme.of(context).textTheme.titleMedium : null)),
      ]));

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
    final pngData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (pngData == null) throw StateError('ساخت تصویر فاکتور ممکن نشد.');
    final decoded = img.decodePng(pngData.buffer.asUint8List());
    if (decoded == null) throw StateError('تبدیل تصویر فاکتور به JPEG ممکن نشد.');
    return Uint8List.fromList(img.encodeJpg(decoded, quality: 92));
  }

  Future<void> exportImage(SalesInvoiceDetails invoice, {required bool share}) async {
    setState(() => working = true);
    try {
      final bytes = await captureImage();
      final name = 'sales_invoice_${invoice.invoiceNumber ?? invoice.id}.jpg';
      if (share) {
        if (kIsWeb) {
          await SharePlus.instance.share(ShareParams(
            files: [XFile.fromData(bytes, mimeType: 'image/jpeg', name: name)],
            fileNameOverrides: [name],
            text: 'فاکتور فروش ${invoice.invoiceNumber ?? ''}',
          ));
        } else {
          final file = File(p.join((await getTemporaryDirectory()).path, name));
          await file.writeAsBytes(bytes, flush: true);
          await SharePlus.instance.share(ShareParams(
            files: [XFile(file.path, mimeType: 'image/jpeg')],
            fileNameOverrides: [name],
            text: 'فاکتور فروش ${invoice.invoiceNumber ?? ''}',
          ));
        }
      } else {
        await FilePicker.platform.saveFile(
          dialogTitle: 'ذخیره تصویر فاکتور', fileName: name,
          type: FileType.custom, allowedExtensions: const ['jpg', 'jpeg'], bytes: bytes,
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خروجی تصویر انجام نشد: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('فاکتور صادرشده')),
      body: FutureBuilder<SalesInvoiceDetails>(future: invoiceFuture, builder: (context, snapshot) {
        if (!snapshot.hasData) return Center(child: Text(snapshot.hasError ? '${snapshot.error}' : 'در حال دریافت فاکتور...'));
        final invoice = snapshot.data!;
        return ListView(padding: const EdgeInsets.all(12), children: [
          RepaintBoundary(key: captureKey, child: Directionality(textDirection: TextDirection.rtl,
              child: Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Image.asset('assets/branding/logo.png', height: 70),
            Text(invoice.sellerName, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
            ...[('تاریخ فاکتور:', jalali(invoice.issueDate)), ('شماره فاکتور:', invoice.invoiceNumber ?? '-'),
                ('نوع نسخه:', invoice.invoiceType == 'FREE' ? 'نسخه آزاد' : (invoice.invoiceType == 'OTC' || invoice.invoiceType == 'MANUAL') ? 'فروش OTC' : invoice.invoiceType == 'GOODS' ? 'فروش کالا' : 'قدیمی'), ('نام و نام خانوادگی:', invoice.buyerName)].map((row) =>
                invoiceRow(row.$1, row.$2)),
            const Divider(),
            ...invoice.items.map((item) => ListTile(title: Text(item.itemName),
                subtitle: Text('${item.quantity} × ${money(amount(item.unitPrice))} ریال'),
                trailing: Text(money(amount(item.lineTotal))))),
            const Divider(),
            invoiceRow('قیمت کل اقلام:', '${money(amount(invoice.subtotal))} ریال'),
            if (amount(invoice.serviceTariff) > 0) invoiceRow('تعرفه خدمات دارویی:', '${money(amount(invoice.serviceTariff))} ریال'),
            if (amount(invoice.discount) > 0) invoiceRow('تخفیف:', '${money(amount(invoice.discount))} ریال'),
            invoiceRow('قابل پرداخت:', '${money(amount(invoice.payableAmount))} ریال', emphasized: true),
            Text(amountToPersianWords(amount(invoice.payableAmount).round()) ?? ''),
            if (invoice.notes != null) Text('توضیحات: ${invoice.notes}'),
            if (invoice.sellerAddress != null) Text(invoice.sellerAddress!),
            if (invoice.sellerPhone != null) Text(invoice.sellerPhone!),
          ]))))),
          if (working)
            const Center(child: Padding(
              padding: EdgeInsets.all(12),
              child: CircularProgressIndicator(),
            )),
          FilledButton.icon(
            icon: const Icon(Icons.save_alt),
            label: const Text('ذخیره در گالری'),
            onPressed: working ? null : () => exportImage(invoice, share: false),
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.share),
            label: const Text('اشتراک گذاری'),
            onPressed: working ? null : () => exportImage(invoice, share: true),
          ),
          FilledButton.tonalIcon(
            icon: const Icon(Icons.add),
            label: const Text('فاکتور جدید'),
            onPressed: working ? null : () => Navigator.pop(context, 'new'),
          ),
          TextButton.icon(
            icon: const Icon(Icons.home_outlined),
            label: const Text('خروج'),
            onPressed: working ? null : () => Navigator.pop(context, 'home'),
          ),
        ]);
      }));
}
