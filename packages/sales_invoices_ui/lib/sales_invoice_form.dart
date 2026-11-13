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
import 'sales_pos_settings.dart';
import 'staff_pos_bridge.dart';
import 'amount_words.dart';
import 'sales_invoice.dart';
import 'sales_api.dart';
import 'catalog_item_details.dart';
import 'barcode_lookup.dart';
import 'scan_success_sound.dart';
import 'camera_preview_stub.dart'
    if (dart.library.html) 'camera_preview_web.dart'
    as camera_preview;

String money(num value) => value.round().toString().replaceAllMapped(
  RegExp(r'\B(?=(\d{3})+(?!\d))'),
  (match) => ',',
);
double amount(String input) =>
    double.tryParse(
      normalizePersianDigitsToEnglish(input).replaceAll(',', ''),
    ) ??
    0;
String jalali(DateTime date) {
  final j = Jalali.fromDateTime(date.toLocal());
  return '${j.year}/${j.month.toString().padLeft(2, '0')}/${j.day.toString().padLeft(2, '0')}';
}

class _Line {
  _Line(this.item, this.quantity, this.price, this.discount);
  final StaffCatalogItem item;
  final double quantity, price, discount;
  double get total => quantity * price - discount;
}

class _SuccessfulPosPayment {
  const _SuccessfulPosPayment({
    required this.device,
    required this.amount,
    required this.responseCode,
    required this.responseDescription,
    required this.traceNumber,
    required this.rrn,
    required this.terminalId,
    required this.paidAt,
    required this.receipt,
  });

  final StaffPosDevice device;
  final int amount;
  final String responseCode;
  final String responseDescription;
  final String traceNumber;
  final String rrn;
  final String terminalId;
  final DateTime paidAt;
  final String receipt;

  Map<String, dynamic> toJson() => {
    'deviceId': device.id,
    'deviceName': device.name,
    'terminalId': terminalId.isEmpty ? device.terminalId : terminalId,
    if (traceNumber.isNotEmpty) 'traceNumber': traceNumber,
    if (rrn.isNotEmpty) 'rrn': rrn,
    'responseCode': responseCode,
    if (responseDescription.isNotEmpty)
      'responseDescription': responseDescription,
    'paidAmount': amount,
    'paidAt': paidAt.toUtc().toIso8601String(),
    'receipt': receipt,
  };
}

typedef InvoiceDatePicker =
    Future<Jalali?> Function(BuildContext context, Jalali initialDate);
typedef PosBridgeRequest =
    Future<StaffPosBridgeResult> Function({
      required String baseUrl,
      required String path,
      String method,
      Map<String, dynamic>? body,
      int timeoutMs,
      String grant,
    });

class StaffInvoiceForm extends StatefulWidget {
  const StaffInvoiceForm({
    required this.api,
    required this.pickDate,
    this.posBridgeRequest = staffPosBridgeRequest,
    this.onHistory,
    super.key,
  });

  final SalesApi api;
  final InvoiceDatePicker pickDate;
  final VoidCallback? onHistory;
  final PosBridgeRequest posBridgeRequest;
  @override
  State<StaffInvoiceForm> createState() => _StaffInvoiceFormState();
}

class _StaffInvoiceFormState extends State<StaffInvoiceForm>
    with WidgetsBindingObserver {
  final buyer = TextEditingController();
  final nationalId = TextEditingController();
  final phone = TextEditingController();
  final address = TextEditingController();
  final query = TextEditingController();
  final searchFocus = FocusNode();
  final ScrollController _formScrollController = ScrollController();
  final Map<String, FocusNode> quantityFocusNodes = {};
  final Map<String, GlobalKey> _quantityFieldKeys = {};
  final itemsSectionKey = GlobalKey();
  Timer? _quantityVisibilityTimer;
  Timer? _keyboardDismissTimer;
  String? _focusedQuantityId;
  double? _scrollPositionBeforeKeyboard;
  double? _screenHeightBeforeKeyboard;
  bool _quantityKeyboardOpened = false;
  bool _keyboardWasObserved = false;

  FocusNode _quantityFocusNode(String id) =>
      quantityFocusNodes.putIfAbsent(id, () {
        final node = FocusNode();
        node.addListener(() {
          if (!mounted) return;
          if (node.hasFocus) {
            _prepareQuantityFocus(id);
          } else if (_focusedQuantityId == id) {
            _focusedQuantityId = null;
          }
        });
        return node;
      });

  void _rememberScrollBeforeKeyboard() {
    if (_scrollPositionBeforeKeyboard != null ||
        !_formScrollController.hasClients)
      return;
    _scrollPositionBeforeKeyboard = _formScrollController.offset;
    _screenHeightBeforeKeyboard = MediaQuery.sizeOf(context).height;
  }

  bool get _keyboardIsVisible {
    if (!mounted) return false;
    final media = MediaQuery.of(context);
    // Some Android browsers resize the viewport instead of reporting viewInsets.
    return media.viewInsets.bottom > 80 ||
        (_screenHeightBeforeKeyboard != null &&
            _screenHeightBeforeKeyboard! - media.size.height > 140);
  }

  void _prepareQuantityFocus(String id) {
    _keyboardDismissTimer?.cancel();
    _rememberScrollBeforeKeyboard();
    _focusedQuantityId = id;
    // Scroll immediately when the field is focused, even if Chrome Android
    // has not reported keyboard insets/viewport resize to Flutter yet.
    // Reserving room *before* the IME animation makes the last invoice row
    // scrollable above the keyboard instead of waiting for didChangeMetrics.
    if (MediaQuery.sizeOf(context).width < 700 && !_quantityKeyboardOpened) {
      setState(() => _quantityKeyboardOpened = true);
    }
    _scheduleQuantityVisibility();
  }

  void _scrollFocusedQuantityIntoView() {
    if (!mounted || _focusedQuantityId == null) return;
    final fieldContext = _quantityFieldKeys[_focusedQuantityId]?.currentContext;
    if (fieldContext == null || !fieldContext.mounted) return;
    // 14% from the top stays clear even while Chrome is still animating its
    // visual viewport; the previous 40% target could sit under the IME.
    Scrollable.ensureVisible(
      fieldContext,
      alignment: 0.14,
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
    );
  }

  void _scheduleQuantityVisibility() {
    // Fast path: next frame, independent of keyboard-inset notifications.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollFocusedQuantityIntoView();
    });
    // One correction after the keyboard animation, not a delayed first scroll.
    _quantityVisibilityTimer?.cancel();
    _quantityVisibilityTimer = Timer(const Duration(milliseconds: 320), () {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollFocusedQuantityIntoView();
      });
    });
  }

  @override
  void didChangeMetrics() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_keyboardIsVisible) {
        _keyboardWasObserved = true;
        _keyboardDismissTimer?.cancel();
        if (_scrollPositionBeforeKeyboard != null) {
          if (!_quantityKeyboardOpened) {
            setState(() => _quantityKeyboardOpened = true);
          }
          if (_focusedQuantityId != null) _scheduleQuantityVisibility();
        }
      } else if (_quantityKeyboardOpened && _keyboardWasObserved) {
        // Keyboard animations may briefly report zero inset; wait until the
        // final dimensions settle before restoring the previous scroll offset.
        _keyboardDismissTimer?.cancel();
        _keyboardDismissTimer = Timer(const Duration(milliseconds: 180), () {
          if (mounted && !_keyboardIsVisible) _restoreScrollAfterKeyboard();
        });
      }
    });
  }

  void _restoreScrollAfterKeyboard() {
    _quantityVisibilityTimer?.cancel();
    final previousOffset = _scrollPositionBeforeKeyboard;
    final focusedId = _focusedQuantityId;
    _scrollPositionBeforeKeyboard = null;
    _screenHeightBeforeKeyboard = null;
    _focusedQuantityId = null;
    _keyboardWasObserved = false;
    // Android Web can leave the TextField focused after Back hides the IME;
    // release only the quantity focus so it does not fight the restored scroll.
    if (focusedId != null) quantityFocusNodes[focusedId]?.unfocus();
    if (mounted) setState(() => _quantityKeyboardOpened = false);
    if (previousOffset == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_formScrollController.hasClients) return;
      final position = _formScrollController.position;
      _formScrollController.animateTo(
        previousOffset
            .clamp(position.minScrollExtent, position.maxScrollExtent)
            .toDouble(),
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    });
  }

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
        Scrollable.ensureVisible(
          target,
          alignment: 0.1,
          duration: const Duration(milliseconds: 220),
        );
      }
    });
  }

  final discount = TextEditingController();
  final notes = TextEditingController();
  final lines = <_Line>[];
  late final settingsApi = SalesPosSettingsApi(widget.api.request);
  bool _posSending = false;
  bool _posOutcomeUnknown = false;
  _SuccessfulPosPayment? _posPayment;
  List<StaffCatalogItem> suggestions = [];
  CatalogSortField catalogSort = CatalogSortField.relevance;
  bool sortDescending = false;
  List<StaffCatalogItem> get sortedSuggestions => sortCatalogMatches(
    suggestions,
    field: catalogSort,
    descending: sortDescending,
    name: (item) => item.name,
    shape: (item) => item.shape,
    alternateName: (item) => item.alternateName,
  );
  void toggleSort(CatalogSortField field) => setState(() {
    if (catalogSort == field) {
      sortDescending = !sortDescending;
    } else {
      catalogSort = field;
      sortDescending = false;
    }
  });
  Timer? debounce;
  Jalali date = Jalali.now();
  String invoiceType = 'OTC';
  bool saving = false;
  bool canManage = false;
  bool get containsDrug =>
      lines.any((line) => line.item.category.toUpperCase() == 'DRUG');
  double manualTariff = 81000;
  double freeTariff = 727000;
  double get serviceTariff => !containsDrug || invoiceType == 'GOODS'
      ? 0
      : (invoiceType == 'OTC' ? manualTariff : freeTariff);
  double get payable => (subtotal + serviceTariff - amount(discount.text))
      .clamp(0, double.infinity)
      .toDouble();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // The default native BarcodeDetector misses these local pharmaceutical
    // labels on Chrome Android. Select the known-working WASM decoder before
    // MobileScanner starts for the very first time (no stop/start cycle).
    if (kIsWeb) {
      MobileScannerPlatform.instance.setWebBarcodeReader(
        WebBarcodeReader.zxingWasm,
      );
    }
    query.addListener(search);
    discount.addListener(refresh);
    _loadTariffs();
    widget.api.canManage().then((value) {
      if (mounted) setState(() => canManage = value);
    });
  }

  // Initial start belongs to MobileScanner (autoStart: true). Only retries
  // invoke start() manually, after the previous startup has finished.
  Future<void> _restartInvoiceCamera() async {
    if (!mounted || _cameraStarting || scannerController.value.isStarting)
      return;
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
      final manual = TextEditingController(
        text: money(profile.manualServiceTariff),
      );
      final free = TextEditingController(
        text: money(profile.freeServiceTariff),
      );
      final saved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('تنظیم تعرفه خدمات دارویی'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: manual,
                  keyboardType: TextInputType.number,
                  inputFormatters: [ThousandsFormatter()],
                  decoration: const InputDecoration(
                    labelText: 'تعرفه فروش OTC (ریال)',
                  ),
                ),
                TextField(
                  controller: free,
                  keyboardType: TextInputType.number,
                  inputFormatters: [ThousandsFormatter()],
                  decoration: const InputDecoration(
                    labelText: 'تعرفه نسخه آزاد (ریال)',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('انصراف'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('ذخیره'),
              ),
            ],
          ),
        ),
      );
      if (saved == true) {
        final updated = await widget.api.updateProfile({
          'sellerName': profile.sellerName,
          if (profile.legalName != null) 'legalName': profile.legalName,
          if (profile.nationalId != null) 'nationalId': profile.nationalId,
          if (profile.economicCode != null)
            'economicCode': profile.economicCode,
          if (profile.phone != null) 'phone': profile.phone,
          if (profile.address != null) 'address': profile.address,
          if (profile.logoData != null) 'logoData': profile.logoData,
          'manualServiceTariff': amount(manual.text),
          'freeServiceTariff': amount(free.text),
        });
        if (mounted)
          setState(() {
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
      if (mounted)
        setState(() {
          manualTariff = profile.manualServiceTariff;
          freeTariff = profile.freeServiceTariff;
        });
    } catch (_) {
      // The invoice can still be drafted with the documented default tariffs.
    }
  }

  void _resetForm() {
    _quantityVisibilityTimer?.cancel();
    _keyboardDismissTimer?.cancel();
    _scrollPositionBeforeKeyboard = null;
    _screenHeightBeforeKeyboard = null;
    _focusedQuantityId = null;
    _quantityKeyboardOpened = false;
    _keyboardWasObserved = false;
    for (final c in [
      buyer,
      nationalId,
      phone,
      address,
      query,
      discount,
      notes,
    ]) {
      c.clear();
    }
    setState(() {
      lines.clear();
      suggestions = [];
      _posPayment = null;
      _posOutcomeUnknown = false;
      date = Jalali.now();
      invoiceType = 'OTC';
    });
  }

  void refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    debounce?.cancel();
    _barcodeOutOfFrameTimer?.cancel();
    _barcodeHitCache.clear();
    _lineCardKeys.clear();
    _quantityFieldKeys.clear();
    _quantityVisibilityTimer?.cancel();
    _keyboardDismissTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _formScrollController.dispose();
    for (final c in [
      buyer,
      nationalId,
      phone,
      address,
      query,
      discount,
      notes,
    ]) {
      c.dispose();
    }
    searchFocus.dispose();
    scannerController.dispose();
    for (final node in quantityFocusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  void _showScanFeedback(String message, {bool success = false}) {
    if (mounted)
      setState(() {
        _scanFeedback = message;
        _scanWasSuccessful = success;
      });
  }

  Future<List<StaffCatalogItem>> _findExactBarcodeMatches(
    BarcodeLookup lookup,
  ) async {
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
        if (mounted && query.text.trim() == input)
          setState(() => suggestions = results);
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
        _showScanFeedback(
          '✓ ${matches.single.name} انتخاب شد${audible ? '' : ' • برای بوق روی تست صدا بزنید'}',
          success: true,
        );
      } else {
        notify(
          matches.isEmpty
              ? 'کالای متناظر پیدا نشد.'
              : 'این بارکد به چند کالا مرتبط است؛ انتخاب خودکار ممکن نیست.',
        );
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
    // Read the barcode first; the lookup result decides which distinct sound plays.
    _showScanFeedback('بارکد $code خوانده شد؛ در حال بررسی کالا...');
    final stopwatch = Stopwatch()..start();
    try {
      final matches = await _findExactBarcodeMatches(lookup);
      if (!mounted) return;
      if (matches.length == 1) {
        final item = matches.single;
        addItem(item);
        final audible = playScanSuccessSound();
        _showScanFeedback(
          '✓ ${item.name} به فاکتور اضافه شد${audible ? '' : ' • برای بوق روی تست صدا بزنید'}',
          success: true,
        );
      } else if (matches.isEmpty) {
        final audible = playScanErrorSound();
        _showScanFeedback(
          'کالای متناظر با بارکد $code پیدا نشد.${audible ? '' : ' برای بوق روی تست صدا بزنید.'}',
        );
      } else {
        _showScanFeedback(
          'بارکد $code به چند کالا مرتبط است؛ انتخاب خودکار ایمن نیست.',
        );
      }
    } catch (error) {
      _showScanFeedback('جستجوی کالا با خطا مواجه شد: $error');
    } finally {
      stopwatch.stop();
      debugPrint(
        'PharmaFlow barcode resolution (${lookup.displayCode}): ${stopwatch.elapsedMilliseconds} ms',
      );
      scannerBusy = false;
    }
  }

  void _focusQuantityForItem(String id) {
    // Capture the position before any automatic scroll, including scans.
    _prepareQuantityFocus(id);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _quantityFocusNode(id).requestFocus();
      _scheduleQuantityVisibility();
    });
  }

  void _testSuccessSound() {
    final supported = enableScanSuccessSound();
    if (!supported) {
      notify(
        'مرورگر اجازه فعال‌سازی صدا را نداد؛ صدای سایت و تنظیمات گوشی را بررسی کنید.',
      );
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
      try {
        final result = await widget.api.search(text);
        if (mounted && query.text.trim() == text)
          setState(() => suggestions = result);
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('$e')));
      }
    });
  }

  double get subtotal => lines.fold(0, (double sum, line) => sum + line.total);
  void notify(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));
  void addItem(StaffCatalogItem item) {
    final index = lines.indexWhere((line) => line.item.id == item.id);
    setState(() {
      if (index >= 0) {
        final old = lines[index];
        lines[index] = _Line(
          old.item,
          old.quantity + 1,
          old.price,
          old.discount.clamp(0, (old.quantity + 1) * old.price),
        );
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
    setState(
      () => lines[index] = _Line(
        old.item,
        quantity,
        old.price,
        old.discount.clamp(0, quantity * old.price),
      ),
    );
  }

  Future<void> edit(StaffCatalogItem item, {required int index}) async {
    final line = await showDialog<_Line>(
      context: context,
      builder: (_) => _LineDialog(item: item, initial: lines[index]),
    );
    if (line == null || !mounted) return;
    setState(() => lines[index] = line);
  }

  Future<StaffPosDevice?> _choosePosDevice(List<StaffPosDevice> devices) async {
    return showDialog<StaffPosDevice>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('ارسال مبلغ به کدام پوز؟'),
          content: SizedBox(
            width: 420,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: devices.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, index) {
                final device = devices[index];
                return ListTile(
                  leading: const Icon(Icons.point_of_sale_outlined),
                  title: Text(
                    device.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    '${device.ip} • Terminal ${device.terminalId}',
                    textDirection: TextDirection.ltr,
                  ),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () => Navigator.pop(dialogContext, device),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('انصراف'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendAmountToPos() async {
    if (_posSending || _posPayment != null || _posOutcomeUnknown) return;
    final payableRial = payable.round();
    if (payableRial < 1000) {
      notify('مبلغ قابل پرداخت باید حداقل ۱٬۰۰۰ ریال باشد.');
      return;
    }

    setState(() => _posSending = true);
    try {
      final settings = await settingsApi.posSettings();
      if (!mounted) return;
      final devices = settings.devices
          .where((device) => device.enabled)
          .toList(growable: false);
      if (settings.bridgeHost.isEmpty || devices.isEmpty) {
        notify(
          'تنظیمات پوز کامل نیست. از صفحه تنظیمات، POS Bridge و دستگاه‌ها را تعریف کنید.',
        );
        return;
      }

      final health = await widget.posBridgeRequest(
        baseUrl: settings.bridgeBaseUrl,
        path: '/health',
        timeoutMs: 3500,
      );
      if (!mounted) return;
      if (!health.ok || health.data['pharmaFlowLan'] != true) {
        notify('به شبکه داروخانه متصل نیستید.');
        return;
      }

      // Release the busy state while the user chooses a terminal, then lock it
      // again immediately after selection. No purchase request is sent yet.
      setState(() => _posSending = false);
      final device = await _choosePosDevice(devices);
      if (!mounted || device == null || _posPayment != null) return;
      setState(() => _posSending = true);
      final requestId =
          'pf-${DateTime.now().microsecondsSinceEpoch}-${device.id}';

      // The backend signs a single-use, short-lived grant for this device and
      // exact amount. No shared POS secret is delivered to the browser.
      final grant = await settingsApi.requestPosGrant(
        operation: 'purchase',
        deviceId: device.id,
        requestId: requestId,
        amount: payableRial,
      );
      final result = await widget.posBridgeRequest(
        grant: grant,
        baseUrl: settings.bridgeBaseUrl,
        path: '/pos/purchase',
        method: 'POST',
        body: {
          'requestId': requestId,
          'posId': device.id,
          'posName': device.name,
          'ip': device.ip,
          'terminalId': device.terminalId,
          'timeout': device.timeout,
          'amount': payableRial,
        },
        timeoutMs: device.timeout * 1000 + 15000,
      );
      if (!mounted) return;

      if (result.ok && result.responseCode == '00') {
        final data = result.data;
        final receipt = '${data['receipt'] ?? ''}';
        if (!receipt.startsWith('r1.')) {
          setState(() => _posOutcomeUnknown = true);
          notify(
            'پوز پرداخت موفق گزارش کرد اما رسید امضاشده دریافت نشد؛ نتیجه را بررسی کنید و دوباره پرداخت نزنید.',
          );
          return;
        }
        // An unauthenticated HTTP LAN response is not sufficient proof of
        // payment. Validate the signed receipt over HTTPS before confirming.
        late final Map<String, dynamic> verified;
        try {
          verified = await settingsApi.verifyPosReceipt(
            receipt: receipt,
            deviceId: device.id,
            amount: payableRial,
          );
        } catch (_) {
          if (mounted) {
            setState(() => _posOutcomeUnknown = true);
            notify(
              'نتیجه پوز دریافت شد اما اصالت رسید تأیید نشد؛ قبل از هر اقدام نتیجه دستگاه را بررسی کنید.',
            );
          }
          return;
        }
        if (!mounted) return;
        final payment = _SuccessfulPosPayment(
          device: device,
          amount: payableRial,
          responseCode: result.responseCode,
          responseDescription: '${verified['responseDescription'] ?? ''}'
              .trim(),
          traceNumber: '${verified['traceNumber'] ?? ''}'.trim(),
          rrn: '${verified['rrn'] ?? ''}'.trim(),
          terminalId: '${verified['terminalId'] ?? device.terminalId}'.trim(),
          paidAt: DateTime.now(),
          receipt: receipt,
        );
        setState(() => _posPayment = payment);
        playScanSuccessSound();
        final trace = payment.traceNumber.isEmpty
            ? ''
            : ' • پیگیری ${payment.traceNumber}';
        notify('پرداخت موفق بود$trace');
        return;
      }

      final code = '${result.data['code'] ?? ''}';
      if (code == 'BRIDGE_TIMEOUT' ||
          code == 'BRIDGE_OFFLINE' ||
          code == 'RECEIPT_SIGNING_FAILED' ||
          code == 'TERMINAL_MISMATCH' ||
          code == 'INVALID_BRIDGE_RESPONSE') {
        setState(() => _posOutcomeUnknown = true);
        notify(
          'وضعیت تراکنش نامشخص است. قبل از هر تلاش مجدد، نتیجه روی دستگاه پوز یا رسید را بررسی کنید.',
        );
        return;
      }

      playScanErrorSound();
      final codeLabel = result.responseCode.isEmpty
          ? ''
          : '${result.responseCode} — ';
      notify(
        'تراکنش ناموفق بود: $codeLabel${result.description.isEmpty ? 'خطای پوز' : result.description}',
      );
    } catch (error) {
      if (mounted) notify('ارسال مبلغ به پوز انجام نشد: $error');
    } finally {
      if (mounted) setState(() => _posSending = false);
    }
  }

  Future<void> save() async {
    if (lines.isEmpty) {
      notify('حداقل یک قلم لازم است.');
      return;
    }
    if (amount(discount.text) > subtotal + serviceTariff) {
      notify('تخفیف از جمع فاکتور بیشتر است.');
      return;
    }
    if (_posPayment != null && _posPayment!.amount != payable.round()) {
      notify(
        'مبلغ فاکتور بعد از پرداخت پوز تغییر کرده است. برای جلوگیری از ثبت مبلغ اشتباه، مبلغ فاکتور را به مبلغ پرداخت‌شده برگردانید.',
      );
      return;
    }
    setState(() => saving = true);
    try {
      final invoice = await widget.api.create({
        'issueDate': date.toDateTime().toIso8601String(),
        'invoiceType': invoiceType,
        if (buyer.text.trim().isNotEmpty) 'buyerName': buyer.text.trim(),
        if (nationalId.text.trim().isNotEmpty)
          'buyerNationalId': nationalId.text.trim(),
        if (phone.text.trim().isNotEmpty) 'buyerPhone': phone.text.trim(),
        if (address.text.trim().isNotEmpty) 'buyerAddress': address.text.trim(),
        'discount': amount(discount.text),
        if (notes.text.trim().isNotEmpty) 'notes': notes.text.trim(),
        if (_posPayment != null) 'posPayment': _posPayment!.toJson(),
        'items': lines
            .map(
              (line) => {
                'catalogItemId': line.item.id,
                'quantity': line.quantity,
                'unitPrice': line.price,
                'lineDiscount': line.discount,
              },
            )
            .toList(),
      });
      if (!mounted) return;
      final action = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (_) => StaffInvoiceDetails(api: widget.api, id: invoice.id),
        ),
      );
      if (mounted) {
        if (action == 'new') {
          _resetForm();
        } else if (action == 'home') {
          Navigator.pop(context, 'home');
        } else if (widget.onHistory != null) {
          widget.onHistory!();
        } else {
          Navigator.pop(context, 'done');
        }
      }
    } catch (e) {
      if (mounted) notify('صدور فاکتور انجام نشد: $e');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Widget _invoiceSection(
    String title,
    List<Widget> children, {
    Key? key,
    IconData icon = Icons.widgets_outlined,
  }) {
    final colors = Theme.of(context).colorScheme;
    final isDetails = title == 'مشخصات فاکتور';
    final isScanner = title == 'اسکن سریع کالا و دارو';
    final accent = isDetails
        ? const Color(0xFF147B8C)
        : isScanner
        ? const Color(0xFF158F73)
        : const Color(0xFF8B6CBE);
    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDetails
            ? const Color(0xFFF9FCFF)
            : isScanner
            ? const Color(0xFFF6FFFA)
            : colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: .22)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: .07),
            blurRadius: 18,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 20, color: accent),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: const Color(0xFF21483F),
                    ),
                  ),
                ),
                Container(
                  width: 5,
                  height: 24,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 11),
            Divider(color: accent.withValues(alpha: .13), height: 1),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _invoiceHeader() => Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF176B5B), Color(0xFF0F9986)],
      ),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      children: [
        const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 30),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'فاکتور جدید',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'اسکن بارکد، تنظیم تعداد و ثبت سریع',
                style: TextStyle(color: Color(0xFFD8F6EA), fontSize: 14),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .16),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            '${lines.length} قلم',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _invoiceFooter() {
    if (MediaQuery.viewInsetsOf(context).bottom > 0)
      return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border(top: BorderSide(color: colors.outlineVariant)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .07),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final total = Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'قابل پرداخت',
                  style: Theme.of(
                    context,
                  ).textTheme.labelMedium?.copyWith(fontSize: 14),
                ),
                Text(
                  '${money(payable)} ریال',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
              ],
            );
            final submit = FilledButton.icon(
              onPressed: saving ? null : save,
              icon: Icon(
                saving ? Icons.hourglass_top : Icons.check_circle_outline,
              ),
              label: Text(saving ? 'در حال ثبت...' : 'صدور فاکتور'),
            );
            final posButton = FilledButton.tonalIcon(
              onPressed:
                  saving ||
                      _posSending ||
                      _posPayment != null ||
                      _posOutcomeUnknown
                  ? null
                  : _sendAmountToPos,
              icon: Icon(
                _posPayment != null
                    ? Icons.verified_outlined
                    : _posOutcomeUnknown
                    ? Icons.warning_amber_rounded
                    : _posSending
                    ? Icons.hourglass_top
                    : Icons.point_of_sale_outlined,
              ),
              label: Text(
                _posPayment != null
                    ? 'پرداخت موفق'
                    : _posOutcomeUnknown
                    ? 'وضعیت پرداخت نامشخص'
                    : _posSending
                    ? 'در حال ارتباط...'
                    : 'ارسال مبلغ به پوز',
              ),
            );
            if (constraints.maxWidth < 440) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  total,
                  const SizedBox(height: 8),
                  SizedBox(width: double.infinity, child: posButton),
                  const SizedBox(height: 8),
                  SizedBox(width: double.infinity, child: submit),
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: total),
                const SizedBox(width: 12),
                posButton,
                const SizedBox(width: 8),
                submit,
              ],
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    // Staff typography is scaled globally in main.dart.
    // Preserve the already-scaled MediaQuery here so the invoice page does not
    // receive the same 50% increase a second time.
    final textScale = media.textScaler.scale(16) / 16;
    return MediaQuery(
      data: media.copyWith(textScaler: TextScaler.linear(textScale)),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Theme(
          data: theme.copyWith(
            textTheme: theme.textTheme.apply(fontSizeFactor: 1.0),
          ),
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
                IconButton(
                  tooltip: 'فاکتورهای قبلی',
                  onPressed:
                      widget.onHistory ??
                      () => Navigator.pop(context, 'history'),
                  icon: const Icon(Icons.history),
                ),
              ],
            ),
            resizeToAvoidBottomInset: true,
            bottomNavigationBar: _invoiceFooter(),
            body: ListView(
              controller: _formScrollController,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              // Reserve enough scroll range *on focus*, without waiting for the
              // browser's visual viewport/keyboard inset updates. Removed on close.
              padding: EdgeInsets.fromLTRB(
                12,
                12,
                12,
                _quantityKeyboardOpened
                    ? MediaQuery.sizeOf(context).height * 0.60
                    : 12,
              ),
              children: [
                _invoiceHeader(),
                _invoiceSection('مشخصات فاکتور', [
                  DropdownButtonFormField<String>(
                    value: invoiceType,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'نوع فروش'),
                    items: const [
                      DropdownMenuItem(
                        value: 'GOODS',
                        child: Text('فروش کالا'),
                      ),
                      DropdownMenuItem(value: 'OTC', child: Text('فروش OTC')),
                      DropdownMenuItem(value: 'FREE', child: Text('نسخه آزاد')),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => invoiceType = value);
                    },
                  ),
                  TextField(
                    controller: buyer,
                    textAlign: TextAlign.right,
                    decoration: const InputDecoration(
                      labelText: 'نام و نام خانوادگی خریدار (اختیاری)',
                    ),
                  ),
                  TextField(
                    controller: nationalId,
                    textAlign: TextAlign.right,
                    keyboardType: TextInputType.number,
                    inputFormatters: [PersianDigitsOnlyFormatter()],
                    decoration: const InputDecoration(
                      labelText: 'کد/شناسه ملی (اختیاری)',
                    ),
                  ),
                  TextField(
                    controller: phone,
                    textAlign: TextAlign.right,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'تلفن (اختیاری)',
                    ),
                  ),
                  TextField(
                    controller: address,
                    textAlign: TextAlign.right,
                    decoration: const InputDecoration(
                      labelText: 'نشانی خریدار (اختیاری)',
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await widget.pickDate(context, date);
                      if (picked != null && mounted)
                        setState(() => date = picked);
                    },
                    icon: const Icon(Icons.calendar_month),
                    label: Text('تاریخ فاکتور: ${jalali(date.toDateTime())}'),
                  ),
                ], icon: Icons.receipt_long_outlined),
                _invoiceSection('اسکن سریع کالا و دارو', [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.verified_outlined,
                            color: Color(0xFF176B5B),
                            size: 18,
                          ),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'اسکن دقیق GS1 و EAN فعال است',
                              style: TextStyle(
                                color: Color(0xFF176B5B),
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: _testSuccessSound,
                          icon: Icon(
                            _soundTested
                                ? Icons.volume_up
                                : Icons.volume_up_outlined,
                            size: 18,
                          ),
                          label: const Text('تست بوق'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: AspectRatio(
                        aspectRatio: 4 / 3,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              ColoredBox(
                                color: const Color(0xFF102720),
                                child: MobileScanner(
                                  controller: scannerController,
                                  fit: BoxFit.cover,
                                  onDetect: _onDetectedBarcodes,
                                  errorBuilder: (context, error) => Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.videocam_off_outlined,
                                            color: Colors.white,
                                            size: 32,
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            kIsWeb
                                                ? 'دوربین در دسترس نیست؛ مجوز Chrome را بررسی کنید.'
                                                : 'دوربین در دسترس نیست؛ مجوز دوربین برنامه را بررسی کنید.',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          SelectableText(
                                            error.toString(),
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 11,
                                            ),
                                          ),
                                          TextButton.icon(
                                            onPressed: _cameraStarting
                                                ? null
                                                : _restartInvoiceCamera,
                                            icon: const Icon(Icons.refresh),
                                            label: const Text('تلاش مجدد'),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              // Web-only HTML preview reuses mobile_scanner's MediaStream.
                              // Keeps barcode decoding and all native mobile UI unchanged.
                              if (kIsWeb)
                                IgnorePointer(
                                  child: camera_preview.buildCameraPreview(),
                                ),
                              // Centered viewfinder; the preview itself fills its 4:3 frame.
                              IgnorePointer(
                                child: Center(
                                  child: FractionallySizedBox(
                                    widthFactor: .77,
                                    heightFactor: .48,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: const Color(0xFFB7F7D9),
                                          width: 2.2,
                                        ),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Color(0x33000000),
                                            blurRadius: 4,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              if (_cameraStarting || _cameraStartError != null)
                                Positioned.fill(
                                  child: ColoredBox(
                                    color: const Color(0xEE102720),
                                    child: Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (_cameraStarting)
                                            const CircularProgressIndicator(
                                              color: Colors.white,
                                            ),
                                          const SizedBox(height: 10),
                                          Text(
                                            _cameraStarting
                                                ? 'در حال راه‌اندازی دوربین...'
                                                : 'دوربین متوقف شد',
                                            style: const TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                          if (_cameraStartError != null) ...[
                                            const SizedBox(height: 6),
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                  ),
                                              child: SelectableText(
                                                _cameraStartError!,
                                                textAlign: TextAlign.center,
                                                style: const TextStyle(
                                                  color: Colors.white70,
                                                ),
                                              ),
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
                              Positioned(
                                left: 8,
                                top: 8,
                                child: IconButton.filledTonal(
                                  tooltip: 'راه‌اندازی مجدد دوربین',
                                  onPressed: _cameraStarting
                                      ? null
                                      : _restartInvoiceCamera,
                                  icon: const Icon(
                                    Icons.refresh_rounded,
                                    size: 20,
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 8,
                                right: 8,
                                bottom: 10,
                                child: Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 7,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xB8000000),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Text(
                                      'بارکد را داخل کادر قرار دهید',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: _scanWasSuccessful
                          ? const Color(0xFFE3F6EA)
                          : const Color(0xFFF0F5F3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _scanWasSuccessful
                              ? Icons.check_circle_rounded
                              : Icons.info_outline,
                          color: _scanWasSuccessful
                              ? const Color(0xFF217347)
                              : const Color(0xFF176B5B),
                          size: 19,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _scanFeedback,
                            style: TextStyle(
                              fontSize: 14,
                              color: _scanWasSuccessful
                                  ? const Color(0xFF17633D)
                                  : const Color(0xFF2E574B),
                            ),
                          ),
                        ),
                      ],
                    ),
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
                  if (suggestions.isNotEmpty)
                    Row(
                      children: [
                        TextButton(
                          onPressed: () =>
                              toggleSort(CatalogSortField.relevance),
                          child: const Text('ارتباط'),
                        ),
                        TextButton(
                          onPressed: () => toggleSort(CatalogSortField.dose),
                          child: Text(
                            'دوز/حجم ${catalogSort == CatalogSortField.dose ? (sortDescending ? '↓' : '↑') : ''}',
                          ),
                        ),
                        TextButton(
                          onPressed: () => toggleSort(CatalogSortField.shape),
                          child: Text(
                            'شکل ${catalogSort == CatalogSortField.shape ? (sortDescending ? '↓' : '↑') : ''}',
                          ),
                        ),
                      ],
                    ),
                  if (suggestions.isNotEmpty)
                    SizedBox(
                      height: 260,
                      child: ListView.builder(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        itemCount: sortedSuggestions.length,
                        itemBuilder: (context, index) {
                          final item = sortedSuggestions[index];
                          return ListTile(
                            title: Text(item.name),
                            subtitle: Text(
                              '${item.details}\nقیمت فروش ثبت‌شده: ${money(item.price)} ریال${item.packetQuantity != null && item.packetQuantity! > 1 ? ' • تعداد در بسته: ${item.packetQuantity}' : ''}',
                            ),
                            isThreeLine: true,
                            onTap: () => addItem(item),
                          );
                        },
                      ),
                    ),
                ], icon: Icons.qr_code_scanner_rounded),
                _invoiceSection(
                  'اقلام فاکتور و مبالغ',
                  [
                    if (lines.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'هنوز کالایی به فاکتور اضافه نشده است.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ...lines.asMap().entries.map((entry) {
                      final item = entry.value.item;
                      return Card(
                        key: _lineCardKeys.putIfAbsent(
                          item.id,
                          () => GlobalKey(),
                        ),
                        margin: const EdgeInsets.only(bottom: 9),
                        elevation: 0,
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerLowest,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: InkWell(
                                      onTap: () => edit(item, index: entry.key),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.name,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            item.details,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(fontSize: 14),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'حذف قلم',
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () => setState(() {
                                      lines.removeAt(entry.key);
                                      _lineCardKeys.remove(item.id);
                                    }),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    '${money(entry.value.total)} ریال',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                  ),
                                  Text(
                                    'قیمت واحد: ${money(entry.value.price)}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Text(
                                        'تعداد',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const Spacer(),
                                      IconButton(
                                        tooltip: 'کاهش تعداد',
                                        visualDensity: VisualDensity.compact,
                                        onPressed: () => setQuantity(
                                          entry.key,
                                          (entry.value.quantity - 1)
                                              .clamp(1, double.infinity)
                                              .toDouble(),
                                        ),
                                        icon: const Icon(
                                          Icons.remove_circle_outline,
                                        ),
                                      ),
                                      SizedBox(
                                        width: 100,
                                        child: _QuantityControl(
                                          value: entry.value.quantity,
                                          focusNode: _quantityFocusNode(
                                            item.id,
                                          ),
                                          fieldKey: _quantityFieldKeys
                                              .putIfAbsent(
                                                item.id,
                                                () => GlobalKey(),
                                              ),
                                          onTap: () =>
                                              _prepareQuantityFocus(item.id),
                                          onChanged: (value) =>
                                              setQuantity(entry.key, value),
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'افزایش تعداد',
                                        visualDensity: VisualDensity.compact,
                                        onPressed: () => setQuantity(
                                          entry.key,
                                          entry.value.quantity + 1,
                                        ),
                                        icon: const Icon(
                                          Icons.add_circle_outline,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 8),
                    Text('جمع اقلام: ${money(subtotal)} ریال'),
                    Text(
                      'تعرفه خدمات دارویی${containsDrug ? '' : ' (بدون دارو: صفر)'}: ${money(serviceTariff)} ریال',
                    ),
                    TextField(
                      controller: discount,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.right,
                      inputFormatters: [ThousandsFormatter()],
                      decoration: const InputDecoration(
                        labelText: 'تخفیف کل (ریال)',
                      ),
                    ),
                    TextField(
                      controller: notes,
                      textAlign: TextAlign.right,
                      decoration: const InputDecoration(
                        labelText: 'توضیحات (اختیاری)',
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'جمع نهایی: ${money(payable)} ریال',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                  key: itemsSectionKey,
                  icon: Icons.shopping_bag_outlined,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PersianDigitsOnlyFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = normalizePersianDigitsToEnglish(
      newValue.text,
    ).replaceAll(RegExp(r'[^0-9]'), '');
    return TextEditingValue(
      text: digits,
      selection: TextSelection.collapsed(offset: digits.length),
    );
  }
}

class _QuantityControl extends StatefulWidget {
  const _QuantityControl({
    required this.value,
    required this.onChanged,
    required this.focusNode,
    this.fieldKey,
    this.onTap,
  });
  final double value;
  final ValueChanged<double> onChanged;
  final FocusNode focusNode;
  final Key? fieldKey;
  final VoidCallback? onTap;
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
    if (oldWidget.value != widget.value &&
        amount(controller.text) != widget.value) {
      controller.text = _text(widget.value);
    }
  }

  String _text(double value) =>
      value == value.roundToDouble() ? '${value.toInt()}' : '$value';
  void _selectOnFocus() {
    if (widget.focusNode.hasFocus) {
      controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: controller.text.length,
      );
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
    key: widget.fieldKey,
    controller: controller,
    focusNode: widget.focusNode,
    textAlign: TextAlign.center,
    onChanged: (text) {
      final value = double.tryParse(normalizePersianDigitsToEnglish(text));
      if (value != null && value > 0) widget.onChanged(value);
    },
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    onTap: () {
      widget.onTap?.call();
      controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: controller.text.length,
      );
    },
    onSubmitted: (text) {
      final value = double.tryParse(normalizePersianDigitsToEnglish(text));
      if (value != null && value > 0)
        widget.onChanged(value);
      else
        controller.text = _text(widget.value);
    },
    onEditingComplete: () {
      final value = double.tryParse(
        normalizePersianDigitsToEnglish(controller.text),
      );
      if (value != null && value > 0)
        widget.onChanged(value);
      else
        controller.text = _text(widget.value);
      FocusScope.of(context).unfocus();
    },
    decoration: const InputDecoration(
      isDense: true,
      contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      border: OutlineInputBorder(),
    ),
  );
}

class ThousandsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = normalizePersianDigitsToEnglish(
      newValue.text,
    ).replaceAll(RegExp(r'[^0-9]'), '');
    final formatted = digits.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
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
  void initState() {
    super.initState();
    quantity = TextEditingController(text: '${widget.initial?.quantity ?? 1}');
    price = TextEditingController(
      text: money(widget.initial?.price ?? widget.item.price),
    );
    discount = TextEditingController(
      text: money(widget.initial?.discount ?? 0),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) quantityFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    quantity.dispose();
    price.dispose();
    discount.dispose();
    quantityFocus.dispose();
    super.dispose();
  }

  void adjust(int delta) {
    final value = ((double.tryParse(quantity.text) ?? 1) + delta)
        .clamp(1, double.infinity)
        .toDouble();
    quantity.text = value == value.roundToDouble()
        ? '${value.toInt()}'
        : '$value';
    quantity.selection = TextSelection.collapsed(offset: quantity.text.length);
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: AlertDialog(
      title: Text(widget.item.name),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => adjust(1),
                  icon: const Icon(Icons.add),
                ),
                Expanded(
                  child: TextField(
                    controller: quantity,
                    focusNode: quantityFocus,
                    autofocus: true,
                    textAlign: TextAlign.right,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => addLine(),
                    decoration: const InputDecoration(labelText: 'تعداد'),
                  ),
                ),
                IconButton(
                  onPressed: () => adjust(-1),
                  icon: const Icon(Icons.remove),
                ),
              ],
            ),
            TextField(
              controller: price,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.right,
              inputFormatters: [ThousandsFormatter()],
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'قیمت واحد (ریال، قابل ویرایش)',
              ),
            ),
            Text(
              amountToPersianWords(amount(price.text).round()) ?? 'صفر تومان',
            ),
            TextField(
              controller: discount,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.right,
              inputFormatters: [ThousandsFormatter()],
              decoration: const InputDecoration(
                labelText: 'تخفیف این ردیف (ریال)',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('انصراف'),
        ),
        FilledButton(onPressed: addLine, child: const Text('افزودن')),
      ],
    ),
  );

  void addLine() {
    final count = double.tryParse(quantity.text) ?? 0;
    final unit = amount(price.text), rebate = amount(discount.text);
    if (count <= 0 || rebate > count * unit) return;
    Navigator.pop(context, _Line(widget.item, count, unit, rebate));
  }
}

class StaffInvoiceDetails extends StatefulWidget {
  const StaffInvoiceDetails({required this.api, required this.id, super.key});
  final SalesApi api;
  final String id;
  @override
  State<StaffInvoiceDetails> createState() => _StaffInvoiceDetailsState();
}

class _StaffInvoiceDetailsState extends State<StaffInvoiceDetails> {
  final captureKey = GlobalKey();
  late final Future<SalesInvoiceDetails> invoiceFuture;
  bool working = false;

  Widget invoiceRow(
    String label,
    String value, {
    bool emphasized = false,
  }) => Directionality(
    textDirection: TextDirection.rtl,
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            textAlign: TextAlign.right,
            style: emphasized ? Theme.of(context).textTheme.titleMedium : null,
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.left,
            style: emphasized ? Theme.of(context).textTheme.titleMedium : null,
          ),
        ),
      ],
    ),
  );

  @override
  void initState() {
    super.initState();
    invoiceFuture = widget.api.detail(widget.id);
  }

  Future<Uint8List> captureImage() async {
    final boundary =
        captureKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null)
      throw StateError('فاکتور برای ذخیره تصویر آماده نیست.');
    final image = await boundary.toImage(pixelRatio: 2);
    final pngData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (pngData == null) throw StateError('ساخت تصویر فاکتور ممکن نشد.');
    final decoded = img.decodePng(pngData.buffer.asUint8List());
    if (decoded == null)
      throw StateError('تبدیل تصویر فاکتور به JPEG ممکن نشد.');
    return Uint8List.fromList(img.encodeJpg(decoded, quality: 92));
  }

  Future<void> exportImage(
    SalesInvoiceDetails invoice, {
    required bool share,
  }) async {
    setState(() => working = true);
    try {
      final bytes = await captureImage();
      final name = 'sales_invoice_${invoice.invoiceNumber ?? invoice.id}.jpg';
      if (share) {
        if (kIsWeb) {
          await SharePlus.instance.share(
            ShareParams(
              files: [
                XFile.fromData(bytes, mimeType: 'image/jpeg', name: name),
              ],
              fileNameOverrides: [name],
              text: 'فاکتور فروش ${invoice.invoiceNumber ?? ''}',
            ),
          );
        } else {
          final file = File(p.join((await getTemporaryDirectory()).path, name));
          await file.writeAsBytes(bytes, flush: true);
          await SharePlus.instance.share(
            ShareParams(
              files: [XFile(file.path, mimeType: 'image/jpeg')],
              fileNameOverrides: [name],
              text: 'فاکتور فروش ${invoice.invoiceNumber ?? ''}',
            ),
          );
        }
      } else {
        await FilePicker.platform.saveFile(
          dialogTitle: 'ذخیره تصویر فاکتور',
          fileName: name,
          type: FileType.custom,
          allowedExtensions: const ['jpg', 'jpeg'],
          bytes: bytes,
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
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('فاکتور صادرشده')),
    body: FutureBuilder<SalesInvoiceDetails>(
      future: invoiceFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return Center(
            child: Text(
              snapshot.hasError
                  ? '${snapshot.error}'
                  : 'در حال دریافت فاکتور...',
            ),
          );
        final invoice = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            RepaintBoundary(
              key: captureKey,
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Image.asset('assets/branding/logo.png', height: 70),
                        Text(
                          invoice.sellerName,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        ...[
                          ('تاریخ فاکتور:', jalali(invoice.issueDate)),
                          ('شماره فاکتور:', invoice.invoiceNumber ?? '-'),
                          (
                            'نوع نسخه:',
                            invoice.invoiceType == 'FREE'
                                ? 'نسخه آزاد'
                                : (invoice.invoiceType == 'OTC' ||
                                      invoice.invoiceType == 'MANUAL')
                                ? 'فروش OTC'
                                : invoice.invoiceType == 'GOODS'
                                ? 'فروش کالا'
                                : 'قدیمی',
                          ),
                          ('نام و نام خانوادگی:', invoice.buyerName),
                        ].map((row) => invoiceRow(row.$1, row.$2)),
                        const Divider(),
                        ...invoice.items.map(
                          (item) => ListTile(
                            title: Text(item.itemName),
                            subtitle: Text(
                              '${item.quantity} × ${money(amount(item.unitPrice))} ریال',
                            ),
                            trailing: Text(money(amount(item.lineTotal))),
                          ),
                        ),
                        const Divider(),
                        invoiceRow(
                          'قیمت کل اقلام:',
                          '${money(amount(invoice.subtotal))} ریال',
                        ),
                        if (amount(invoice.serviceTariff) > 0)
                          invoiceRow(
                            'تعرفه خدمات دارویی:',
                            '${money(amount(invoice.serviceTariff))} ریال',
                          ),
                        if (amount(invoice.discount) > 0)
                          invoiceRow(
                            'تخفیف:',
                            '${money(amount(invoice.discount))} ریال',
                          ),
                        invoiceRow(
                          'قابل پرداخت:',
                          '${money(amount(invoice.payableAmount))} ریال',
                          emphasized: true,
                        ),
                        if (invoice.posPaymentStatus == 'SUCCESS') ...[
                          const Divider(),
                          invoiceRow('پرداخت:', 'موفق از طریق پوز'),
                          if (invoice.posPaymentDeviceName != null)
                            invoiceRow(
                              'دستگاه پوز:',
                              invoice.posPaymentDeviceName!,
                            ),
                          if (invoice.posPaymentTraceNumber != null)
                            invoiceRow(
                              'شماره پیگیری:',
                              invoice.posPaymentTraceNumber!,
                            ),
                          if (invoice.posPaymentRrn != null)
                            invoiceRow('RRN:', invoice.posPaymentRrn!),
                        ],
                        Text(
                          amountToPersianWords(
                                amount(invoice.payableAmount).round(),
                              ) ??
                              '',
                        ),
                        if (invoice.notes != null)
                          Text('توضیحات: ${invoice.notes}'),
                        if (invoice.sellerAddress != null)
                          Text(invoice.sellerAddress!),
                        if (invoice.sellerPhone != null)
                          Text(invoice.sellerPhone!),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (working)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(),
                ),
              ),
            FilledButton.icon(
              icon: const Icon(Icons.save_alt),
              label: const Text('ذخیره در گالری'),
              onPressed: working
                  ? null
                  : () => exportImage(invoice, share: false),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.share),
              label: const Text('اشتراک گذاری'),
              onPressed: working
                  ? null
                  : () => exportImage(invoice, share: true),
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
          ],
        );
      },
    ),
  );
}
