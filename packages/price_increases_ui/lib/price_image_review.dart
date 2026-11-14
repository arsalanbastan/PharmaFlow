import 'dart:convert';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'price_increases_page.dart';

class PriceImageReview extends StatefulWidget {
  const PriceImageReview({
    required this.request,
    required this.pickDate,
    super.key,
  });

  final PriceIncreaseRequest request;
  final Future<void> Function(BuildContext, TextEditingController) pickDate;

  @override
  State<PriceImageReview> createState() => _PriceImageReviewState();
}

class _Row {
  _Row(Map data)
    : name = TextEditingController(text: data['name'] as String?),
      price = TextEditingController(text: data['price'] as String?),
      unit = switch (data['unit']) {
        'RIAL' => 'RIAL',
        'TOMAN' => 'TOMAN',
        _ => 'UNKNOWN',
      },
      note = data['note'] as String?;

  final TextEditingController name, price;
  final String? note;
  String unit;
  String category = 'DRUG';
  bool included = true;

  String? get rial {
    final value = normalizePriceInput(price.text).replaceAll('٫', '.');
    if (unit == 'UNKNOWN' ||
        !RegExp(r'^\d{1,16}(\.\d{1,2})?$').hasMatch(value) ||
        (num.tryParse(value) ?? 0) <= 0)
      return null;
    if (unit == 'RIAL') return value;

    final parts = value.split('.');
    final digits =
        '${parts.first}${(parts.length == 2 ? parts.last : '').padRight(2, '0')}';
    final cents = BigInt.parse(digits) * BigInt.from(10);
    final whole = (cents ~/ BigInt.from(100)).toString();
    final fraction = cents % BigInt.from(100);
    return whole.length > 16
        ? null
        : fraction == BigInt.zero
        ? whole
        : '$whole.${fraction.toString().padLeft(2, '0')}';
  }

  void dispose() {
    name.dispose();
    price.dispose();
  }
}

class _PriceImageReviewState extends State<PriceImageReview> {
  Map<String, dynamic>? _pendingBatch;
  final _form = GlobalKey<FormState>();
  final _date = TextEditingController();
  final _source = TextEditingController();
  List<_Row> _rows = [];
  PlatformFile? _image;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _date.dispose();
    _source.dispose();
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  Future<void> _extract() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final files = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
        withData: true,
      );
      if (!mounted || files == null) return;
      final file = files.files.single;
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty || bytes.length > 6 * 1024 * 1024) {
        throw const FormatException('حداکثر حجم تصویر ۶ مگابایت است.');
      }
      final result = await widget.request('/price-increases/extract-image', {
        'mimeType': switch (file.extension?.toLowerCase()) {
          'png' => 'image/png',
          'webp' => 'image/webp',
          _ => 'image/jpeg',
        },
        'imageBase64': base64Encode(bytes),
      });
      if (!mounted) return;
      final rows = (result['rows'] as List)
          .map((row) => _Row(row as Map))
          .toList();
      if (rows.isEmpty) {
        throw const FormatException(
          'ردیفی در تصویر پیدا نشد. تصویر واضح‌تری انتخاب کنید.',
        );
      }
      setState(() {
        for (final row in _rows) {
          row.dispose();
        }
        _rows = rows;
        _image = file;
      });
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _publish() async {
    final included = _rows.where((row) => row.included).toList();
    if (!_form.currentState!.validate() || included.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final random = Random.secure();
      final batch = _pendingBatch ??= {
        'requestKey': List.generate(
          24,
          (_) => random.nextInt(256),
        ).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join(),
        'items': [
          for (final row in included)
            {
              'productName': row.name.text.trim(),
              'newPrice': row.rial,
              'category': row.category,
              'effectiveDate': _date.text,
              'source': _source.text.trim(),
            },
        ],
      };
      await widget.request('/price-increases/batch', batch);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editable = !_busy && _pendingBatch == null;
    final count = _rows.where((row) => row.included).length;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: PopScope(
        canPop: !_busy,
        child: Scaffold(
          appBar: AppBar(title: const Text('استخراج افزایش قیمت از عکس')),
          body: Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                OutlinedButton.icon(
                  onPressed: editable ? _extract : null,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: Text(
                    _image == null
                        ? 'انتخاب تصویر اطلاعیه'
                        : 'انتخاب تصویر دیگر',
                  ),
                ),
                if (_busy) const LinearProgressIndicator(),
                if (_error != null)
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                if (_image != null) ...[
                  ExpansionTile(
                    title: Text(_image!.name),
                    children: [
                      Image.memory(
                        _image!.bytes!,
                        height: 360,
                        fit: BoxFit.contain,
                      ),
                    ],
                  ),
                  const Text(
                    'نام، قیمت و واحد هر ردیف را با تصویر تطبیق دهید. فقط ردیف‌های انتخاب‌شده ثبت می‌شوند.',
                  ),
                  TextFormField(
                    controller: _source,
                    enabled: editable,
                    maxLength: 500,
                    decoration: const InputDecoration(
                      labelText: 'منبع اطلاعیه',
                    ),
                    validator: (value) =>
                        value!.trim().isEmpty ? 'منبع را وارد کنید.' : null,
                  ),
                  TextFormField(
                    controller: _date,
                    enabled: editable,
                    readOnly: true,
                    onTap: () => widget.pickDate(context, _date),
                    decoration: const InputDecoration(
                      labelText: 'تاریخ اجرا',
                      suffixIcon: Icon(Icons.calendar_month),
                    ),
                    validator: (value) =>
                        value!.isEmpty ? 'تاریخ را انتخاب کنید.' : null,
                  ),
                  for (final (index, row) in _rows.indexed)
                    Card(
                      key: ObjectKey(row),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            CheckboxListTile(
                              title: Text('ردیف ${index + 1}'),
                              value: row.included,
                              onChanged: !editable
                                  ? null
                                  : (value) =>
                                        setState(() => row.included = value!),
                            ),
                            if (row.note case final note? when note.isNotEmpty)
                              Text(note),
                            TextFormField(
                              controller: row.name,
                              enabled: editable && row.included,
                              maxLength: 300,
                              decoration: const InputDecoration(
                                labelText: 'نام کالا یا دارو',
                              ),
                              validator: (value) =>
                                  row.included && value!.trim().isEmpty
                                  ? 'نام را وارد کنید.'
                                  : null,
                            ),
                            TextFormField(
                              controller: row.price,
                              enabled: editable && row.included,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'قیمت جدید',
                              ),
                              validator: (_) => row.included && row.rial == null
                                  ? 'قیمت و واحد معتبر وارد کنید.'
                                  : null,
                            ),
                            DropdownButtonFormField<String>(
                              initialValue: row.unit,
                              decoration: const InputDecoration(
                                labelText: 'واحد قیمت در تصویر',
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'UNKNOWN',
                                  child: Text('نامشخص'),
                                ),
                                DropdownMenuItem(
                                  value: 'RIAL',
                                  child: Text('ریال'),
                                ),
                                DropdownMenuItem(
                                  value: 'TOMAN',
                                  child: Text('تومان'),
                                ),
                              ],
                              onChanged: !editable || !row.included
                                  ? null
                                  : (value) =>
                                        setState(() => row.unit = value!),
                            ),
                            DropdownButtonFormField<String>(
                              initialValue: row.category,
                              decoration: const InputDecoration(
                                labelText: 'نوع محصول',
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'DRUG',
                                  child: Text('دارو'),
                                ),
                                DropdownMenuItem(
                                  value: 'GOODS',
                                  child: Text('کالا'),
                                ),
                              ],
                              onChanged: !editable || !row.included
                                  ? null
                                  : (value) => row.category = value!,
                            ),
                          ],
                        ),
                      ),
                    ),
                  FilledButton(
                    onPressed: _busy || count == 0 ? null : _publish,
                    child: Text(
                      _pendingBatch == null
                          ? 'تأیید و ثبت $count ردیف'
                          : 'تلاش دوباره برای ثبت',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
