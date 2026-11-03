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
import 'barcode_lookup.dart';
import 'scan_success_sound.dart';

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
    // Report the same symbol while it remains visible. This lets us unlock
    // the product only after the package is removed from the camera frame.
    detectionSpeed: DetectionSpeed.normal,
    detectionTimeoutMs: 280,
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.dataMatrix,
      BarcodeFormat.qrCode,
      BarcodeFormat.code128,
    ],
  );
  bool _cameraStarting = false;
  String? _cameraStartError;
  bool scannerBusy = false;
  String? lastScannedCode;
  Timer? _barcodeOutOfFrameTimer;
  String _scanFeedback = 'منتظر شناسایی بارکد...';
  bool _scanWasSuccessful = false;
  bool _soundTested = false;
  final Map<String, StaffCatalogItem> _barcodeHitCache = {};
  final Map<String, GlobalKey> _lineCardKeys = {};
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
    // The default native BarcodeDetector misses these local pharmaceutical
    // labels on Chrome Android. Select the known-working WASM decoder before
    // MobileScanner starts for the very first time (no stop/start cycle).
    if (kIsWeb) {
      MobileScannerPlatform.instance.setWebBarcodeReader(WebBarcodeReader.zxingWasm);
    }
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
    debounce?.cancel();
    _barcodeOutOfFrameTimer?.cancel();
    _barcodeHitCache.clear();
    _lineCardKeys.clear();
    for (final c in [buyer, nationalId, phone, address, query, discount, notes]) { c.dispose(); }
    searchFocus.dispose();
    scannerController.dispose();
    for (final node in quantityFocusNodes.values) { node.dispose(); }
    super.dispose();
  }
  void _showScanFeedback(String message, {bool success = false}) {
    if (mounted) setState(() {
      _scanFeedback = message;
      _scanWasSuccessful = success;
    });
  }

  Future<List<StaffCatalogItem>> _findExactBarcodeMatches(BarcodeLookup lookup) async {
    final cached = _barcodeHitCache[lookup.displayCode];
    if (cached != null) return [cached];

    // A single indexed backend lookup replaces fetching all catalog pages
    // and searching the 13-digit/14-digit forms in separate API requests.
    final matches = await widget.api.searchBarcodeExact(lookup.candidates);
    if (matches.length == 1) {
      if (_barcodeHitCache.length >= 100) _barcodeHitCache.clear();
      _barcodeHitCache[lookup.displayCode] = matches.single;
    }
    return matches;
  }

  Future<void> scanBarcode() async {
    final input = query.text.trim();
    if (input.isEmpty) return;
    debounce?.cancel();
    final lookup = parseBarcodeLookup(input);
    if (lookup == null) {
      notify('شناسه کالا از این کد استخراج نشد.');
      return;
    }
    // Text queries keep their existing suggestion-based catalog search.
    if (!RegExp(r'^\d{8,14}$').hasMatch(lookup.displayCode)) {
      try {
        final results = await widget.api.search(input);
        if (mounted && query.text.trim() == input) setState(() => suggestions = results);
      } catch (error) {
        if (mounted) notify('جستجوی کالا ناموفق بود: $error');
      }
      return;
    }
    try {
      final matches = await _findExactBarcodeMatches(lookup);
      if (!mounted || query.text.trim() != input) return;
      if (matches.length == 1) {
        addItem(matches.single);
        final audible = playScanSuccessSound();
        _showScanFeedback('✓ ${matches.single.name} انتخاب شد${audible ? '' : ' • برای بوق روی تست صدا بزنید'}', success: true);
      } else {
        notify(matches.isEmpty ? 'کالای متناظر پیدا نشد.' : 'این بارکد به چند کالا مرتبط است؛ انتخاب خودکار ممکن نیست.');
      }
    } catch (error) {
      if (mounted) notify('جستجوی بارکد ناموفق بود: $error');
    }
  }

  void _onDetectedBarcodes(BarcodeCapture capture) {
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null || raw.trim().isEmpty) continue;
      final lookup = parseBarcodeLookup(raw);
      if (lookup == null) {
        // Avoid rebuilding the entire invoice on every undecodable frame.
        continue;
      }
      _barcodeOutOfFrameTimer?.cancel();
      _barcodeOutOfFrameTimer = Timer(const Duration(milliseconds: 1200), () {
        lastScannedCode = null;
      });
      if (!scannerBusy && lookup.displayCode != lastScannedCode) {
        handleScannedBarcode(lookup);
      }
      break;
    }
  }

  Future<void> handleScannedBarcode(BarcodeLookup lookup) async {
    final code = lookup.displayCode;
    if (scannerBusy || code == lastScannedCode) return;
    scannerBusy = true;
    lastScannedCode = code;
    // Confirm the scan immediately, not after a network request. An unknown
    // catalog item still produces one short beep and then a clear error.
    final audible = playScanSuccessSound();
    _showScanFeedback('بارکد $code خوانده شد؛ در حال بررسی کالا...');
    final stopwatch = Stopwatch()..start();
    try {
      final matches = await _findExactBarcodeMatches(lookup);
      if (!mounted) return;
      if (matches.length == 1) {
        final item = matches.single;
        addItem(item);
        _showScanFeedback('✓ ${item.name} به فاکتور اضافه شد${audible ? '' : ' • برای بوق روی تست صدا بزنید'}', success: true);
      } else if (matches.isEmpty) {
        _showScanFeedback('کالای متناظر با بارکد $code پیدا نشد.${audible ? '' : ' برای بوق روی تست صدا بزنید.'}');
      } else {
        _showScanFeedback('بارکد $code به چند کالا مرتبط است؛ انتخاب خودکار ایمن نیست.');
      }
    } catch (error) {
      _showScanFeedback('جستجوی کالا با خطا مواجه شد: $error');
    } finally {
      stopwatch.stop();
      debugPrint('PharmaFlow barcode resolution (${lookup.displayCode}): ${stopwatch.elapsedMilliseconds} ms');
      scannerBusy = false;
    }
  }

  void _focusQuantityForItem(String id) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final itemContext = _lineCardKeys[id]?.currentContext;
      if (itemContext != null && itemContext.mounted) {
        await Scrollable.ensureVisible(itemContext,
          alignment: 0.36, duration: const Duration(milliseconds: 160));
      }
      if (mounted) _quantityFocusNode(id).requestFocus();
    });
  }

  void _testSuccessSound() {
    final supported = enableScanSuccessSound();
    if (!supported) {
      notify('مرورگر اجازه فعال‌سازی صدا را نداد؛ صدای سایت و تنظیمات گوشی را بررسی کنید.');
      return;
    }
    setState(() => _soundTested = true);
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
    // A unique barcode immediately selects its catalog item; the operator
    // continues directly in the quantity field, without choosing a result.
    _focusQuantityForItem(item.id);
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
  Widget _invoiceSection(String title, List<Widget> children,
      {Key? key, IconData icon = Icons.widgets_outlined}) {
    final colors = Theme.of(context).colorScheme;
    final isDetails = title == 'مشخصات فاکتور';
    final isScanner = title == 'اسکن سریع کالا و دارو';
    final accent = isDetails ? const Color(0xFF147B8C)
        : isScanner ? const Color(0xFF158F73) : const Color(0xFF8B6CBE);
    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDetails ? const Color(0xFFF9FCFF)
            : isScanner ? const Color(0xFFF6FFFA) : colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: .22)),
        boxShadow: [
          BoxShadow(color: accent.withValues(alpha: .07),
            blurRadius: 18, offset: const Offset(0, 5)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: accent),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800, color: const Color(0xFF21483F)))),
            Container(width: 5, height: 24, decoration: BoxDecoration(
              color: accent, borderRadius: BorderRadius.circular(8))),
          ]),
          const SizedBox(height: 11),
          Divider(color: accent.withValues(alpha: .13), height: 1),
          const SizedBox(height: 12),
          ...children,
        ]),
      ),
    );
  }

  Widget _invoiceHeader() => Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [Color(0xFF176B5B), Color(0xFF0F9986)]),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(children: [
      const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 30),
      const SizedBox(width: 12),
      const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('فاکتور جدید', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
        SizedBox(height: 3),
        Text('اسکن بارکد، تنظیم تعداد و ثبت سریع', style: TextStyle(color: Color(0xFFD8F6EA), fontSize: 12)),
      ])),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: .16), borderRadius: BorderRadius.circular(14)),
        child: Text('${lines.length} قلم', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
      ),
    ]),
  );

  Widget _invoiceFooter() {
    if (MediaQuery.viewInsetsOf(context).bottom > 0) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    return SafeArea(top: false, child: Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.outlineVariant)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .07), blurRadius: 20, offset: const Offset(0, -4))],
      ),
      child: Row(children: [
        Expanded(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('قابل پرداخت', style: Theme.of(context).textTheme.labelMedium),
          Text('${money(payable)} ریال', style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: colors.primary, fontWeight: FontWeight.w900)),
        ])),
        const SizedBox(width: 12),
        FilledButton.icon(
          onPressed: saving ? null : save,
          icon: Icon(saving ? Icons.hourglass_top : Icons.check_circle_outline),
          label: Text(saving ? 'در حال ثبت...' : 'صدور فاکتور'),
        ),
      ]),
    ));
  }

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
      bottomNavigationBar: _invoiceFooter(),
      body: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.all(12),
        children: [
          _invoiceHeader(),
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
          ], icon: Icons.receipt_long_outlined),
          _invoiceSection('اسکن سریع کالا و دارو', [
            Row(children: [
              const Icon(Icons.verified_outlined, color: Color(0xFF176B5B), size: 18),
              const SizedBox(width: 6),
              const Expanded(child: Text('اسکن دقیق GS1 و EAN فعال است',
                style: TextStyle(color: Color(0xFF176B5B), fontSize: 12, fontWeight: FontWeight.w700))),
              TextButton.icon(
                onPressed: _testSuccessSound,
                icon: Icon(_soundTested ? Icons.volume_up : Icons.volume_up_outlined, size: 18),
                label: const Text('تست بوق'),
              ),
            ]),
            const SizedBox(height: 8),
            Center(child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Stack(fit: StackFit.expand, children: [
                    ColoredBox(
                      color: const Color(0xFF102720),
                      child: MobileScanner(
                        controller: scannerController,
                        fit: BoxFit.cover,
                        onDetect: _onDetectedBarcodes,
                        errorBuilder: (context, error) => Center(child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.videocam_off_outlined, color: Colors.white, size: 32),
                            const SizedBox(height: 8),
                            const Text('دوربین در دسترس نیست؛ مجوز Chrome را بررسی کنید.',
                              textAlign: TextAlign.center, style: TextStyle(color: Colors.white)),
                            const SizedBox(height: 6),
                            SelectableText(error.toString(), textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white70, fontSize: 11)),
                            TextButton.icon(onPressed: _cameraStarting ? null : _restartInvoiceCamera,
                              icon: const Icon(Icons.refresh), label: const Text('تلاش مجدد')),
                          ]),
                        )),
                      ),
                    ),
                    // Centered viewfinder; the preview itself fills its 4:3 frame.
                    IgnorePointer(child: Center(child: FractionallySizedBox(
                      widthFactor: .77, heightFactor: .48,
                      child: Container(decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFB7F7D9), width: 2.2),
                        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 4)],
                      )),
                    ))),
                    if (_cameraStarting || _cameraStartError != null)
                      Positioned.fill(child: ColoredBox(
                        color: const Color(0xEE102720),
                        child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                          if (_cameraStarting) const CircularProgressIndicator(color: Colors.white),
                          const SizedBox(height: 10),
                          Text(_cameraStarting ? 'در حال راه‌اندازی دوربین...' : 'دوربین متوقف شد',
                            style: const TextStyle(color: Colors.white)),
                          if (_cameraStartError != null) ...[
                            const SizedBox(height: 6),
                            Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: SelectableText(_cameraStartError!,
                                textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70))),
                            TextButton.icon(onPressed: _restartInvoiceCamera,
                              icon: const Icon(Icons.refresh), label: const Text('تلاش مجدد')),
                          ],
                        ])),
                      )),
                    Positioned(
                      left: 8, top: 8,
                      child: IconButton.filledTonal(
                        tooltip: 'راه‌اندازی مجدد دوربین',
                        onPressed: _cameraStarting ? null : _restartInvoiceCamera,
                        icon: const Icon(Icons.refresh_rounded, size: 20),
                      ),
                    ),
                    Positioned(
                      left: 8, right: 8, bottom: 10,
                      child: Center(child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(color: const Color(0xB8000000),
                          borderRadius: BorderRadius.circular(20)),
                        child: const Text('بارکد را داخل کادر قرار دهید',
                          style: TextStyle(color: Colors.white, fontSize: 12)),
                      )),
                    ),
                  ]),
                ),
              ),
            )),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: _scanWasSuccessful ? const Color(0xFFE3F6EA) : const Color(0xFFF0F5F3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                Icon(_scanWasSuccessful ? Icons.check_circle_rounded : Icons.info_outline,
                  color: _scanWasSuccessful ? const Color(0xFF217347) : const Color(0xFF176B5B), size: 19),
                const SizedBox(width: 8),
                Expanded(child: Text(_scanFeedback,
                  style: TextStyle(fontSize: 12,
                    color: _scanWasSuccessful ? const Color(0xFF17633D) : const Color(0xFF2E574B)))),
              ]),
            ),
            const SizedBox(height: 14),
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
          ], icon: Icons.qr_code_scanner_rounded),
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
                key: _lineCardKeys.putIfAbsent(item.id, () => GlobalKey()),
                margin: const EdgeInsets.only(bottom: 9),
                elevation: 0,
                color: Theme.of(context).colorScheme.surfaceContainerLowest,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Row(children: [
                      Expanded(child: InkWell(
                        onTap: () => edit(item, index: entry.key),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(item.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 3),
                          Text(item.details, maxLines: 2, overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall),
                        ]),
                      )),
                      IconButton(tooltip: 'حذف قلم', icon: const Icon(Icons.delete_outline),
                        onPressed: () => setState(() {
                          lines.removeAt(entry.key);
                          _lineCardKeys.remove(item.id);
                        })),
                    ]),
                    const SizedBox(height: 6),
                    Row(children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${money(entry.value.total)} ریال',
                          style: TextStyle(fontWeight: FontWeight.w800,
                            color: Theme.of(context).colorScheme.primary)),
                        Text('قیمت واحد: ${money(entry.value.price)}',
                          style: Theme.of(context).textTheme.bodySmall),
                      ])),
                      IconButton(tooltip: 'کاهش تعداد', visualDensity: VisualDensity.compact,
                        onPressed: () => setQuantity(entry.key,
                          (entry.value.quantity - 1).clamp(1, double.infinity).toDouble()),
                        icon: const Icon(Icons.remove_circle_outline)),
                      SizedBox(width: 68, child: _QuantityControl(
                        value: entry.value.quantity,
                        focusNode: _quantityFocusNode(item.id),
                        onChanged: (value) => setQuantity(entry.key, value),
                      )),
                      IconButton(tooltip: 'افزایش تعداد', visualDensity: VisualDensity.compact,
                        onPressed: () => setQuantity(entry.key, entry.value.quantity + 1),
                        icon: const Icon(Icons.add_circle_outline)),
                    ]),
                  ]),
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
            const SizedBox(height: 6),
            Text('جمع نهایی: ${money(payable)} ریال',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.primary)),
          ], key: itemsSectionKey, icon: Icons.shopping_bag_outlined),
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
    widget.focusNode.addListener(_selectOnFocus);
  }
  @override
  void didUpdateWidget(covariant _QuantityControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && amount(controller.text) != widget.value) {
      controller.text = _text(widget.value);
    }
  }
  String _text(double value) => value == value.roundToDouble() ? '${value.toInt()}' : '$value';
  void _selectOnFocus() {
    if (widget.focusNode.hasFocus) {
      controller.selection = TextSelection(baseOffset: 0, extentOffset: controller.text.length);
    }
  }
  @override
  void dispose() {
    widget.focusNode.removeListener(_selectOnFocus);
    controller.dispose();
    super.dispose();
  }
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
