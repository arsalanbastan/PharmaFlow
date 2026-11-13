import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart' show DateFormat;
import 'package:shamsi_date/shamsi_date.dart';
import 'package:share_plus/share_plus.dart';

typedef PriceIncreaseRequest =
    Future<Map<String, dynamic>> Function(
      String path,
      Map<String, dynamic>? body,
    );

String normalizePriceInput(String value) {
  const digits = '۰۱۲۳۴۵۶۷۸۹٠١٢٣٤٥٦٧٨٩';
  return value
      .split('')
      .map((c) {
        final i = digits.indexOf(c);
        return i < 0 ? c : '${i % 10}';
      })
      .join()
      .replaceAll(',', '')
      .replaceAll('٬', '')
      .trim();
}

String formatPrice(String value) {
  final parts = value.split('.');
  final whole = parts.first.replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (m) => '${m[1]},',
  );
  return parts.length == 1 ? whole : '$whole.${parts[1]}';
}

String jalaliTimestamp(String value) {
  final date = DateTime.tryParse(value)?.toLocal();
  if (date == null) return value;
  final j = Jalali.fromDateTime(date);
  return '${j.year}/${j.month.toString().padLeft(2, '0')}/${j.day.toString().padLeft(2, '0')} ${DateFormat('HH:mm:ss').format(date)}';
}

class PriceIncreasesPage extends StatefulWidget {
  const PriceIncreasesPage({
    super.key,
    required this.request,
    required this.manager,
    this.canConfirm = true,
  });
  final PriceIncreaseRequest request;
  final bool manager;
  final bool canConfirm;
  @override
  State<PriceIncreasesPage> createState() => _PriceIncreasesPageState();
}

class _PriceIncreasesPageState extends State<PriceIncreasesPage> {
  final _search = TextEditingController();
  final _from = TextEditingController();
  final _to = TextEditingController();
  String _status = '', _category = '', _userId = '';
  int _page = 1, _total = 0, _generation = 0;
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _items = [];
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    _from.dispose();
    _to.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) _page = 1;
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final query = Uri(
        queryParameters: {
          'q': _search.text.trim(),
          'status': _status,
          'category': _category,
          'from': normalizePriceInput(_from.text),
          'to': normalizePriceInput(_to.text),
          'page': '$_page',
        },
      ).query;
      final data = await widget.request('/price-increases?$query', null);
      if (!mounted || generation != _generation) return;
      setState(() {
        _items = (data['items'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _total = data['total'] as int;
        _userId = data['currentUserId'] as String;
      });
    } catch (e) {
      if (mounted && generation == _generation)
        setState(() => _error = 'دریافت اطلاعات ناموفق بود: $e');
    } finally {
      if (mounted && generation == _generation)
        setState(() => _loading = false);
    }
  }

  void _message(String text) {
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  bool _isBeforeEffectiveDate(Map<String, dynamic> item) {
    final today = Jalali.fromDateTime(DateTime.now());
    final todayString =
        '${today.year}/${today.month.toString().padLeft(2, '0')}/${today.day.toString().padLeft(2, '0')}';
    return todayString.compareTo('${item['effectiveDate']}') < 0;
  }

  Future<void> _edit(Map<String, dynamic> item) async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => _CreatePage(request: widget.request, existing: item),
      ),
    );
    if (result != null && mounted) await _load();
  }

  Future<void> _cancel(Map<String, dynamic> item) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('لغو افزایش قیمت'),
        content: TextField(
          controller: controller,
          maxLength: 1000,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'دلیل لغو (الزامی)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) Navigator.pop(context, value);
            },
            child: const Text('ثبت لغو'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason == null || !mounted) return;
    try {
      await widget.request('/price-increases/${item['id']}/cancel', {
        'reason': reason,
      });
      await _load();
      _message('افزایش قیمت لغو شد و در تاریخچه باقی می‌ماند.');
    } catch (e) {
      _message('لغو ناموفق بود: $e');
    }
  }

  Future<void> _confirm(
    Map<String, dynamic> item,
    int index,
    String name,
  ) async {
    final id = item['id'] as String;
    var note = '';
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأیید اعمال قیمت'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_isBeforeEffectiveDate(item))
                const Text(
                  'هشدار: تاریخ اجرای این افزایش قیمت هنوز نرسیده است.',
                ),
              Text('قیمت جدید «$name» را اعمال کرده‌اید؟'),
              TextField(
                maxLength: 1000,
                maxLines: 2,
                onChanged: (value) => note = value.trim(),
                decoration: const InputDecoration(
                  labelText: 'یادداشت (اختیاری)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('اعمال کردم'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted || _busy.contains(id)) return;
    setState(() => _busy.add(id));
    try {
      await widget.request('/price-increases/$id/confirm', {
        if (index >= 0) 'itemIndex': index,
        if (note.isNotEmpty) 'note': note,
      });
      await _load();
      _message('تأیید شما ثبت شد.');
    } catch (e) {
      _message('ثبت تأیید ناموفق بود: $e');
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  Future<void> _upload(String id) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        withData: true,
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
      );
      if (result == null) return;
      final file = result.files.single;
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty || bytes.length > 10 * 1024 * 1024)
        throw StateError('حداکثر حجم فایل ۱۰ مگابایت است.');
      final mime = {
        'jpg': 'image/jpeg',
        'jpeg': 'image/jpeg',
        'png': 'image/png',
        'webp': 'image/webp',
        'pdf': 'application/pdf',
      }[file.extension?.toLowerCase()];
      if (mime == null) throw StateError('نوع فایل پشتیبانی نمی‌شود.');
      final prepared = await widget.request(
        '/price-increases/$id/attachments/prepare',
        {'fileName': file.name, 'mimeType': mime, 'fileSize': bytes.length},
      );
      final response = await http
          .put(
            Uri.parse(prepared['uploadUrl'] as String),
            headers: {'Content-Type': mime},
            body: bytes,
          )
          .timeout(const Duration(seconds: 90));
      if (response.statusCode < 200 || response.statusCode >= 300)
        throw StateError('بارگذاری فایل انجام نشد.');
      await widget.request(
        '/price-increases/$id/attachments/${prepared['id']}/confirm',
        {},
      );
      await _load();
      _message('پیوست ثبت شد.');
    } catch (e) {
      _message('خطای پیوست؛ برای تلاش دوباره از دکمه پیوست استفاده کنید: $e');
    }
  }

  Future<void> _download(String id, Map attachment) async {
    try {
      final data = await widget.request(
        '/price-increases/$id/attachments/${attachment['id']}',
        null,
      );
      final response = await http
          .get(Uri.parse(data['downloadUrl'] as String))
          .timeout(const Duration(seconds: 60));
      if (response.statusCode != 200)
        throw StateError('دریافت فایل ناموفق بود.');
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              response.bodyBytes,
              mimeType: attachment['mimeType'] as String,
            ),
          ],
          fileNameOverrides: [attachment['fileName'] as String],
          downloadFallbackEnabled: true,
        ),
      );
    } catch (e) {
      _message('دریافت پیوست ناموفق بود: $e');
    }
  }

  Future<void> _create() async {
    final id = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => _CreatePage(request: widget.request)),
    );
    if (id != null && mounted) {
      await _load(reset: true);
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('افزایش قیمت‌ها'),
        actions: [
          IconButton(
            onPressed: _loading ? null : () => _load(),
            icon: const Icon(Icons.refresh),
            tooltip: 'بروزرسانی',
          ),
        ],
      ),
      floatingActionButton: widget.manager
          ? FloatingActionButton.extended(
              onPressed: _create,
              icon: const Icon(Icons.add),
              label: const Text('ثبت افزایش قیمت'),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                TextField(
                  controller: _search,
                  decoration: const InputDecoration(
                    labelText: 'جست‌وجوی محصول، منبع، توضیح یا تأییدکننده',
                  ),
                  onSubmitted: (_) => _load(reset: true),
                ),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    SizedBox(
                      width: 160,
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: '',
                        decoration: const InputDecoration(labelText: 'وضعیت'),
                        items: [
                          const DropdownMenuItem(value: '', child: Text('همه')),
                          DropdownMenuItem(
                            value: 'PENDING',
                            child: Text(
                              widget.manager
                                  ? 'بدون تأیید'
                                  : 'در انتظار تأیید من',
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'CANCELED',
                            child: Text('لغوشده'),
                          ),
                          DropdownMenuItem(
                            value: 'CONFIRMED',
                            child: Text(
                              widget.manager
                                  ? 'دارای تأیید'
                                  : 'تأییدشده توسط من',
                            ),
                          ),
                        ],
                        onChanged: (v) {
                          _status = v ?? '';
                          _load(reset: true);
                        },
                      ),
                    ),
                    SizedBox(
                      width: 130,
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: '',
                        decoration: const InputDecoration(
                          labelText: 'نوع محصول',
                        ),
                        items: const [
                          DropdownMenuItem(value: '', child: Text('همه')),
                          DropdownMenuItem(value: 'DRUG', child: Text('دارو')),
                          DropdownMenuItem(value: 'GOODS', child: Text('کالا')),
                        ],
                        onChanged: (v) {
                          _category = v ?? '';
                          _load(reset: true);
                        },
                      ),
                    ),
                    SizedBox(
                      width: 145,
                      child: TextField(
                        controller: _from,
                        decoration: const InputDecoration(
                          labelText: 'اجرا از (شمسی)',
                          hintText: '1405/01/01',
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 145,
                      child: TextField(
                        controller: _to,
                        decoration: const InputDecoration(
                          labelText: 'اجرا تا (شمسی)',
                          hintText: '1405/12/29',
                        ),
                      ),
                    ),
                    FilledButton(
                      onPressed: _loading ? null : () => _load(reset: true),
                      child: const Text('جست‌وجو و فیلتر'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          Expanded(
            child: _error != null
                ? Center(
                    child: FilledButton(
                      onPressed: () => _load(),
                      child: const Text('تلاش مجدد'),
                    ),
                  )
                : _items.isEmpty && !_loading
                ? const Center(child: Text('موردی یافت نشد.'))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 90),
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      final confirmations = item['confirmations'] as List;
                      final products =
                          (item['productItems'] as List?)?.cast<String>() ??
                          const <String>[];
                      final confirmationItems = products.isEmpty
                          ? {-1: item['productName'] as String}
                          : products.asMap();
                      bool confirmedByMe(int index) => confirmations.any(
                        (e) =>
                            e['userId'] == _userId &&
                            (e['itemIndex'] ?? -1) == index,
                      );
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${item['productName']}',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text(
                                '${item['category'] == 'DRUG' ? 'دارو' : 'کالا'} • قیمت جدید: ${formatPrice('${item['newPrice']}')} ریال',
                              ),
                              Text(
                                'تاریخ اجرای شمسی: ${item['effectiveDate']}',
                              ),
                              Text('منبع: ${item['source']}'),
                              if ('${item['notes'] ?? ''}'.isNotEmpty)
                                Text('${item['notes']}'),
                              Text(
                                'ثبت‌کننده: ${item['createdByName']} • ${jalaliTimestamp(item['createdAt'] as String)}',
                              ),
                              if (item['canceledAt'] != null) ...[
                                const Text(
                                  'لغوشده',
                                  style: TextStyle(color: Colors.red),
                                ),
                                Text(
                                  'دلیل: ${item['cancellationReason'] ?? ''}',
                                ),
                                Text(
                                  'لغو توسط: ${item['canceledByName'] ?? ''}',
                                ),
                              ],
                              if (confirmations.isEmpty)
                                const Text('هنوز تأییدی ثبت نشده است.'),
                              if (products.isNotEmpty)
                                Text('اقلام: ${products.join('، ')}'),
                              for (final c in confirmations)
                                SelectableText(
                                  [
                                    'تأیید: ${c['displayName']}',
                                    if (products.isNotEmpty)
                                      confirmationItems[c['itemIndex']] ?? '',
                                    jalaliTimestamp(c['confirmedAt'] as String),
                                    if ('${c['note'] ?? ''}'.isNotEmpty)
                                      '${c['note']}',
                                  ].join(' • '),
                                ),
                              Wrap(
                                children: [
                                  for (final attachment
                                      in item['attachments'] as List)
                                    TextButton.icon(
                                      onPressed: () => _download(
                                        item['id'] as String,
                                        attachment as Map,
                                      ),
                                      icon: const Icon(Icons.attach_file),
                                      label: Text('${attachment['fileName']}'),
                                    ),
                                ],
                              ),
                              if (widget.manager && item['canceledAt'] == null)
                                Wrap(
                                  spacing: 8,
                                  children: [
                                    if (confirmations.isEmpty)
                                      TextButton.icon(
                                        onPressed: () => _edit(item),
                                        icon: const Icon(Icons.edit),
                                        label: const Text('ویرایش'),
                                      ),
                                    TextButton.icon(
                                      onPressed: () => _cancel(item),
                                      icon: const Icon(Icons.cancel_outlined),
                                      label: const Text('لغو'),
                                    ),
                                  ],
                                ),
                              if (widget.manager && item['canceledAt'] == null)
                                TextButton.icon(
                                  onPressed: () =>
                                      _upload(item['id'] as String),
                                  icon: const Icon(Icons.upload_file),
                                  label: const Text(
                                    'افزودن پیوست (عکس یا PDF)',
                                  ),
                                ),
                              if (!widget.manager &&
                                  widget.canConfirm &&
                                  item['canceledAt'] == null)
                                for (final entry in confirmationItems.entries)
                                  FilledButton(
                                    onPressed:
                                        confirmedByMe(entry.key) ||
                                            _busy.contains(item['id'])
                                        ? null
                                        : () => _confirm(
                                            item,
                                            entry.key,
                                            entry.value,
                                          ),
                                    child: Text(
                                      products.isEmpty
                                          ? (confirmedByMe(entry.key)
                                                ? 'تأیید شما ثبت شده'
                                                : 'قیمت جدید را اعمال کردم')
                                          : '${entry.value} • ${confirmedByMe(entry.key) ? 'اعمال شد' : 'تأیید اعمال'}',
                                    ),
                                  ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: _loading || _page == 1
                    ? null
                    : () {
                        _page--;
                        _load();
                      },
                icon: const Icon(Icons.chevron_right),
              ),
              Text('صفحه $_page • $_total مورد'),
              IconButton(
                onPressed: _loading || _page * 25 >= _total
                    ? null
                    : () {
                        _page++;
                        _load();
                      },
                icon: const Icon(Icons.chevron_left),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _CreatePage extends StatefulWidget {
  const _CreatePage({required this.request, this.existing});
  final Map<String, dynamic>? existing;
  final PriceIncreaseRequest request;
  @override
  State<_CreatePage> createState() => _CreatePageState();
}

class _CreatePageState extends State<_CreatePage> {
  @override
  void initState() {
    super.initState();
    final item = widget.existing;
    if (item != null) {
      _name.text = '${item['productName']}';
      _products.text = (item['productItems'] as List?)?.join('\n') ?? '';
      _price.text = '${item['newPrice']}';
      _date.text = '${item['effectiveDate']}';
      _source.text = '${item['source']}';
      _notes.text = '${item['notes'] ?? ''}';
      _category = '${item['category']}';
    }
  }

  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(),
      _products = TextEditingController(),
      _price = TextEditingController(),
      _date = TextEditingController(),
      _source = TextEditingController(),
      _notes = TextEditingController();
  String _category = 'DRUG';
  bool _saving = false;
  String? _error;
  @override
  void dispose() {
    for (final c in [_name, _products, _price, _date, _source, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'این فیلد الزامی است.' : null;
  String? _validateDate(String? value) {
    try {
      final s = normalizePriceInput(value ?? '');
      if (!RegExp(r'^1[3-6]\d{2}/\d{2}/\d{2}$').hasMatch(s))
        return 'قالب تاریخ: 1405/08/18';
      final parts = s.split('/').map(int.parse).toList();
      Jalali(parts[0], parts[1], parts[2]);
      return null;
    } catch (_) {
      return 'تاریخ شمسی نامعتبر است.';
    }
  }

  List<String> get _productItems => _products.text
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toSet()
      .toList();

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final result = await widget.request(
        widget.existing == null
            ? '/price-increases'
            : 'PATCH:/price-increases/${widget.existing!['id']}',
        {
          'productName': _name.text.trim(),
          'productItems': _productItems,
          'category': _category,
          'newPrice': normalizePriceInput(_price.text),
          'effectiveDate': normalizePriceInput(_date.text),
          'source': _source.text.trim(),
          'notes': _notes.text.trim(),
        },
      );
      if (mounted) Navigator.pop(context, result['id'] as String);
    } catch (e) {
      if (mounted) setState(() => _error = 'ثبت ناموفق بود: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existing == null ? 'ثبت افزایش قیمت' : 'ویرایش افزایش قیمت',
        ),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              maxLength: 300,
              validator: _required,
              decoration: const InputDecoration(
                labelText: 'نام دارو / کالا یا عنوان کلی',
              ),
            ),
            TextFormField(
              controller: _products,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'اقلام مشمول (اختیاری، هر قلم یک خط)',
              ),
              validator: (_) =>
                  _productItems.length > 30 ||
                      _productItems.any((item) => item.length > 150)
                  ? 'حداکثر ۳۰ قلم، هر قلم حداکثر ۱۵۰ نویسه.'
                  : null,
            ),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'نوع محصول'),
              items: const [
                DropdownMenuItem(value: 'DRUG', child: Text('دارو')),
                DropdownMenuItem(value: 'GOODS', child: Text('کالا')),
              ],
              onChanged: (v) => _category = v ?? 'DRUG',
            ),
            TextFormField(
              controller: _price,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'قیمت جدید (ریال)'),
              validator: (v) {
                final p = normalizePriceInput(v ?? '');
                return RegExp(r'^\d{1,16}(\.\d{1,2})?$').hasMatch(p) &&
                        (num.tryParse(p) ?? 0) > 0
                    ? null
                    : 'قیمت مثبت و معتبر وارد کنید.';
              },
            ),
            TextFormField(
              controller: _date,
              textDirection: TextDirection.ltr,
              validator: _validateDate,
              decoration: const InputDecoration(
                labelText: 'تاریخ اجرای شمسی',
                hintText: '1405/08/18',
              ),
            ),
            TextFormField(
              controller: _source,
              maxLength: 500,
              validator: _required,
              decoration: const InputDecoration(
                labelText: 'منبع اعلام افزایش قیمت',
              ),
            ),
            TextFormField(
              controller: _notes,
              maxLength: 3000,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'توضیحات'),
            ),
            const Text(
              'پس از ثبت، از دکمه «افزودن پیوست» روی همین رکورد برای عکس یا PDF استفاده کنید.',
            ),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'در حال ثبت...' : 'ثبت'),
            ),
          ],
        ),
      ),
    ),
  );
}
