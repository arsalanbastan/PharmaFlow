import 'dart:async';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/order_photo_optimizer.dart';
import '../data/staff_order_api_service.dart';

typedef StaffOrderDuplicateLookup =
    Future<Map<String, dynamic>> Function({
      required String category,
      required String itemText,
    });

class StaffOrderFormPage extends StatefulWidget {
  const StaffOrderFormPage({
    super.key,
    this.duplicateLookup,
    this.embedded = false,
    this.onOrderCreated,
  });

  final StaffOrderDuplicateLookup? duplicateLookup;
  final bool embedded;
  final VoidCallback? onOrderCreated;

  @override
  State<StaffOrderFormPage> createState() => _StaffOrderFormPageState();
}

class _StaffOrderFormPageState extends State<StaffOrderFormPage> {
  final _formKey = GlobalKey<FormState>();

  final _itemController = TextEditingController();

  final _quantityController = TextEditingController();

  final _companyController = TextEditingController();

  final _notesController = TextEditingController();

  final _picker = ImagePicker();

  String _category = 'DRUG';
  Uint8List? _photoBytes;
  int? _originalPhotoSize;
  bool _saving = false;
  bool _checkingSimilarOrders = false;
  List<Map<String, dynamic>> _similarOrders = const [];
  Timer? _similarityDebounce;
  int _similarityRequestSerial = 0;

  @override
  void dispose() {
    _similarityDebounce?.cancel();
    _similarityRequestSerial += 1;
    _itemController.dispose();
    _quantityController.dispose();
    _companyController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _onItemTextChanged(String value) {
    _similarityDebounce?.cancel();

    final requestSerial = ++_similarityRequestSerial;
    final itemText = value.trim();
    final compactLength = itemText.replaceAll(RegExp(r'\s+'), '').runes.length;

    if (compactLength < 2) {
      if (_checkingSimilarOrders || _similarOrders.isNotEmpty) {
        setState(() {
          _checkingSimilarOrders = false;
          _similarOrders = const [];
        });
      }

      return;
    }

    setState(() {
      _checkingSimilarOrders = true;
    });

    final category = _category;

    _similarityDebounce = Timer(const Duration(milliseconds: 320), () {
      unawaited(
        _loadSimilarOrders(
          category: category,
          itemText: itemText,
          requestSerial: requestSerial,
        ),
      );
    });
  }

  Future<Map<String, dynamic>> _lookupSimilarOrders({
    required String category,
    required String itemText,
  }) async {
    final injectedLookup = widget.duplicateLookup;

    if (injectedLookup != null) {
      return injectedLookup(category: category, itemText: itemText);
    }

    final api = StaffOrderApiService();

    try {
      return await api.checkDuplicate(category: category, itemText: itemText);
    } finally {
      api.close();
    }
  }

  Future<void> _loadSimilarOrders({
    required String category,
    required String itemText,
    required int requestSerial,
  }) async {
    try {
      final result = await _lookupSimilarOrders(
        category: category,
        itemText: itemText,
      );

      final matches = <Map<String, dynamic>>[];
      final rawMatches = result['matches'];

      if (rawMatches is List) {
        for (final rawMatch in rawMatches) {
          if (rawMatch is Map) {
            matches.add(Map<String, dynamic>.from(rawMatch));
          }
        }
      }

      if (!mounted || requestSerial != _similarityRequestSerial) {
        return;
      }

      setState(() {
        _checkingSimilarOrders = false;
        _similarOrders = matches;
      });
    } catch (_) {
      if (!mounted || requestSerial != _similarityRequestSerial) {
        return;
      }

      setState(() {
        _checkingSimilarOrders = false;
        _similarOrders = const [];
      });
    }
  }

  String _similarOrderStatusLabel(Object? status) {
    return status == 'ORDERED'
        ? 'به شرکت داده شده؛ در انتظار دریافت'
        : 'هنوز به شرکت داده نشده';
  }

  Widget _buildSimilarOrdersPanel(BuildContext context) {
    if (!_checkingSimilarOrders && _similarOrders.isEmpty) {
      return const SizedBox.shrink();
    }

    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.content_copy_outlined,
                size: 17,
                color: colors.onSurfaceVariant.withValues(alpha: 0.72),
              ),
              const SizedBox(width: 6),
              Text(
                'سفارش‌های مشابه',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: colors.onSurfaceVariant.withValues(alpha: 0.78),
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (_checkingSimilarOrders) ...[
                const Spacer(),
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 1.5),
                ),
              ],
            ],
          ),
          if (_similarOrders.isNotEmpty) ...[
            const SizedBox(height: 6),
            for (var index = 0; index < _similarOrders.length; index += 1) ...[
              if (index > 0)
                Divider(
                  height: 10,
                  color: colors.outlineVariant.withValues(alpha: 0.45),
                ),
              Text(
                _similarOrders[index]['itemText']?.toString() ?? '',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant.withValues(alpha: 0.78),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _similarOrderStatusLabel(_similarOrders[index]['status']),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant.withValues(alpha: 0.62),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Future<void> _choosePhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('دوربین'),
                onTap: () {
                  Navigator.of(sheetContext).pop(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('گالری'),
                onTap: () {
                  Navigator.of(sheetContext).pop(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );

    if (source == null) {
      return;
    }

    final picked = await _picker.pickImage(source: source, imageQuality: 95);

    if (picked == null) {
      return;
    }

    try {
      final sourceBytes = await picked.readAsBytes();

      final optimized = OrderPhotoOptimizer.optimize(sourceBytes);

      if (!mounted) {
        return;
      }

      setState(() {
        _photoBytes = optimized.bytes;
        _originalPhotoSize = optimized.originalSize;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('آماده‌سازی عکس ناموفق بود: $error')),
      );
    }
  }

  Future<bool> _confirmDuplicate(Map<String, dynamic> result) async {
    if (result['found'] != true) {
      return true;
    }

    final matches = result['matches'];

    var details = '';

    if (matches is List && matches.isNotEmpty) {
      final lines = <String>[];

      for (final match in matches.take(5)) {
        if (match is Map) {
          final itemText = match['itemText']?.toString().trim() ?? '';

          if (itemText.isNotEmpty) {
            lines.add(
              '• $itemText\n  ${_similarOrderStatusLabel(match['status'])}',
            );
          }
        }
      }

      if (lines.isNotEmpty) {
        details = '\n\n${lines.join('\n\n')}';
      }
    }

    final answer = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('احتمال درخواست تکراری'),
          content: Text(
            'یک درخواست مشابه فعال وجود دارد.$details'
            '\n\nآیا با این حال ثبت شود؟',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('انصراف'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('ثبت شود'),
            ),
          ],
        );
      },
    );

    return answer == true;
  }

  void _resetForNextOrder() {
    _similarityDebounce?.cancel();
    _similarityRequestSerial += 1;
    _itemController.clear();
    _quantityController.clear();
    _companyController.clear();
    _notesController.clear();

    _formKey.currentState?.reset();

    setState(() {
      _photoBytes = null;
      _originalPhotoSize = null;
      _checkingSimilarOrders = false;
      _similarOrders = const [];
    });
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final quantityText = _quantityController.text.trim();

    final quantity = quantityText.isEmpty ? null : int.tryParse(quantityText);

    _similarityDebounce?.cancel();
    _similarityRequestSerial += 1;

    setState(() {
      _saving = true;
      _checkingSimilarOrders = false;
    });

    final api = StaffOrderApiService();

    try {
      final duplicate = await api.checkDuplicate(
        category: _category,
        itemText: _itemController.text.trim(),
      );

      if (!mounted) {
        return;
      }

      final continueSave = await _confirmDuplicate(duplicate);

      if (!continueSave) {
        return;
      }

      final created = await api.createOrder(
        category: _category,
        itemText: _itemController.text.trim(),
        requestedQuantity: quantity,
        suggestedCompanyText: _companyController.text,
        notes: _notesController.text,
      );

      final order = created['order'];

      if (order is! Map<String, dynamic>) {
        throw const FormatException('Created order response is invalid.');
      }

      final orderId = order['id']?.toString();

      if (orderId == null || orderId.isEmpty) {
        throw const FormatException('Created order ID is missing.');
      }

      final photo = _photoBytes;

      String? photoWarning;

      if (photo != null) {
        try {
          final photoSha = sha256.convert(photo).toString();

          if (kIsWeb) {
            await api.uploadWebPhoto(
              orderId: orderId,
              bytes: photo,
              sha256: photoSha,
            );
          } else {
            final prepared = await api.preparePhoto(
              orderId: orderId,
              fileSize: photo.length,
            );

            final uploadUrl = prepared['uploadUrl']?.toString();

            if (uploadUrl == null || uploadUrl.isEmpty) {
              throw const FormatException('Photo upload URL is missing.');
            }

            await api.uploadPhotoBytes(uploadUrl: uploadUrl, bytes: photo);

            await api.confirmPhoto(
              orderId: orderId,
              fileSize: photo.length,
              sha256: photoSha,
            );
          }
        } catch (error) {
          photoWarning = 'درخواست ثبت شد ولی ارسال عکس ناموفق بود: $error';
        }
      }

      if (!mounted) {
        return;
      }

      _resetForNextOrder();
      widget.onOrderCreated?.call();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            photoWarning ?? 'درخواست ثبت شد؛ فرم برای مورد بعدی آماده است.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('ثبت درخواست ناموفق بود: $error')));
    } finally {
      api.close();

      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final photo = _photoBytes;
    final content = SafeArea(
      child: Form(
        key: _formKey,
        child: ListView(
          key: const ValueKey('staff-order-form-scroll'),
          padding: const EdgeInsets.all(16),
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'DRUG',
                  label: Text('دارو'),
                  icon: Icon(Icons.medication_outlined),
                ),
                ButtonSegment(
                  value: 'GOODS',
                  label: Text('کالا'),
                  icon: Icon(Icons.inventory_2_outlined),
                ),
              ],
              selected: <String>{_category},
              onSelectionChanged: _saving
                  ? null
                  : (values) {
                      setState(() {
                        _category = values.first;
                      });
                      _onItemTextChanged(_itemController.text);
                    },
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _itemController,
              enabled: !_saving,
              autofocus: !widget.embedded,
              onChanged: _onItemTextChanged,
              decoration: InputDecoration(
                labelText: 'نام دارو / کالا و مشخصات',
                hintText: _category == 'DRUG'
                    ? 'مثلاً آتورواستاتین 20'
                    : 'مثلاً ضد آفتاب پیکسل بی رنگ پوست های چرب',
                border: const OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'نام آیتم را وارد کنید.';
                }

                return null;
              },
            ),
            if (_checkingSimilarOrders || _similarOrders.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildSimilarOrdersPanel(context),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: _quantityController,
              enabled: !_saving,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'تعداد درخواستی - اختیاری',
                helperText: 'اگر خالی باشد، مدیر درباره تعداد تصمیم می‌گیرد.',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                final text = value?.trim() ?? '';

                if (text.isEmpty) {
                  return null;
                }

                final parsed = int.tryParse(text);

                if (parsed == null || parsed <= 0) {
                  return 'تعداد باید عدد مثبت باشد.';
                }

                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _companyController,
              enabled: !_saving,
              decoration: const InputDecoration(
                labelText: 'شرکت پیشنهادی - اختیاری',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesController,
              enabled: !_saving,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'توضیحات - اختیاری',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'پیوست عکس - اختیاری',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _saving ? null : _choosePhoto,
                          icon: const Icon(Icons.add_a_photo_outlined),
                          label: Text(
                            photo == null ? 'انتخاب عکس' : 'تغییر عکس',
                          ),
                        ),
                      ],
                    ),
                    if (photo != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(
                          photo,
                          height: 180,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'حجم نهایی: ${(photo.length / 1024).toStringAsFixed(1)} KB'
                        '${_originalPhotoSize == null ? '' : '  •  حجم اولیه: ${(_originalPhotoSize! / 1024).toStringAsFixed(1)} KB'}',
                        textAlign: TextAlign.center,
                      ),
                      TextButton(
                        onPressed: _saving
                            ? null
                            : () {
                                setState(() {
                                  _photoBytes = null;
                                  _originalPhotoSize = null;
                                });
                              },
                        child: const Text('حذف عکس'),
                      ),
                    ] else
                      const Text(
                        'عکس قبل از ارسال به‌صورت خودکار به حداکثر 200KB فشرده می‌شود.',
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_outlined),
              label: Text(_saving ? 'در حال ثبت...' : 'ثبت درخواست'),
            ),
          ],
        ),
      ),
    );

    if (widget.embedded) {
      return Directionality(textDirection: TextDirection.rtl, child: content);
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('ثبت درخواست جدید')),
        persistentFooterButtons: [
          TextButton.icon(
            onPressed: _saving
                ? null
                : () {
                    Navigator.of(context).pop();
                  },
            icon: const Icon(Icons.close),
            label: const Text('خروج'),
          ),
        ],
        body: content,
      ),
    );
  }
}
