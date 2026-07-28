import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shamsi_date/shamsi_date.dart';

import '../../../../data/models/bank_account.dart';
import '../../../../data/models/cheque.dart';
import '../../../../data/models/company.dart';
import '../../../../data/repositories/local/local_bank_account_repository.dart';
import '../../../../data/repositories/local/local_cheque_repository.dart';
import '../../../../data/repositories/local/local_company_repository.dart';
import '../../../../core/database/database_service.dart';
import '../../../../shared/widgets/date_picker/pharmaflow_date_picker.dart';
import '../utils/cheque_input_formatters.dart';
import '../utils/cheque_text_utils.dart';
import '../widgets/cheque_compact_card.dart';
import '../widgets/searchable_selector_field.dart';

class ChequeFormPage extends StatefulWidget {
  const ChequeFormPage({super.key});

  @override
  State<ChequeFormPage> createState() => _ChequeFormPageState();
}

class _ChequeFormPageState extends State<ChequeFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _imagePicker = ImagePicker();

  late final LocalCompanyRepository _companyRepository;
  late final LocalBankAccountRepository _bankAccountRepository;
  late final LocalChequeRepository _chequeRepository;

  final _chequeNumberController = TextEditingController();
  final _amountController = TextEditingController();
  final _sayadIdController = TextEditingController();
  final _descriptionController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  final bool _isRegisteredInSayad = false;
  bool _showValidationErrors = false;

  String? _loadError;
  Uint8List? _imageData;
  Jalali? _dueDate;
  Company? _selectedCompany;
  BankAccount? _selectedBankAccount;

  List<Company> _companies = const [];
  List<BankAccount> _bankAccounts = const [];

  @override
  void initState() {
    super.initState();

    _companyRepository = LocalCompanyRepository(DatabaseService.instance);
    _bankAccountRepository = LocalBankAccountRepository(
      DatabaseService.instance,
    );
    _chequeRepository = LocalChequeRepository(DatabaseService.instance);

    _loadInitialData();
  }

  @override
  void dispose() {
    _chequeNumberController.dispose();
    _amountController.dispose();
    _sayadIdController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final companies = await _companyRepository.getAll();
      final accounts = await _bankAccountRepository.getAll();

      if (!mounted) {
        return;
      }

      setState(() {
        _companies = companies;
        _bankAccounts = accounts;
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      debugPrint('ChequeFormPage._loadInitialData failed: $e');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _loadError = 'بارگذاری اطلاعات اولیه با خطا مواجه شد.';
      });
    }
  }

  int? get _amountValue {
    final digits = extractEnglishDigits(_amountController.text);
    if (digits.isEmpty) {
      return null;
    }

    return int.tryParse(digits);
  }

  String? get _amountInWords {
    return amountToPersianWords(_amountValue);
  }

  String _formatJalali(Jalali value) {
    final raw =
        '${value.year.toString().padLeft(4, '0')}/${value.month.toString().padLeft(2, '0')}/${value.day.toString().padLeft(2, '0')}';
    return toPersianDigits(raw);
  }

  String? get _bankError {
    if (!_showValidationErrors || _selectedBankAccount != null) {
      return null;
    }
    return 'انتخاب حساب بانکی الزامی است.';
  }

  String? get _companyError {
    if (!_showValidationErrors || _selectedCompany != null) {
      return null;
    }
    return 'انتخاب شرکت الزامی است.';
  }

  String? get _dueDateError {
    if (!_showValidationErrors || _dueDate != null) {
      return null;
    }
    return 'تاریخ سررسید الزامی است.';
  }

  Future<void> _pickDueDate() async {
    final picked = await PharmaFlowDatePicker.show(
      context: context,
      initialDate: _dueDate ?? Jalali.now(),
      firstDate: Jalali(1390, 1, 1),
      lastDate: Jalali(1450, 12, 29),
      autoConfirm: false,
    );

    if (picked == null) {
      return;
    }

    setState(() {
      _dueDate = picked;
    });
  }

  Future<void> _selectBankAccount() async {
    final selected = await _showSearchSelector<BankAccount>(
      title: 'انتخاب حساب بانکی',
      items: _bankAccounts,
      itemLabel: (item) => item.accountTitle,
      itemSubtitle: (item) => item.bankName,
    );

    if (selected == null || !mounted) {
      return;
    }

    setState(() {
      _selectedBankAccount = selected;
    });

    await _suggestNextChequeNumber(selected.id);
  }

  Future<void> _selectCompany() async {
    final selected = await _showSearchSelector<Company>(
      title: 'انتخاب شرکت',
      items: _companies,
      itemLabel: (item) => item.name,
      itemSubtitle: (item) => item.nationalId,
    );

    if (selected == null || !mounted) {
      return;
    }

    setState(() {
      _selectedCompany = selected;
    });
  }

  Future<void> _suggestNextChequeNumber(int? bankAccountId) async {
    if (bankAccountId == null) {
      return;
    }

    try {
      final latest = await _chequeRepository.suggestLatestChequeNumber(
        bankAccountId,
      );
      if (latest == null || latest.trim().isEmpty) {
        return;
      }

      final normalized = extractEnglishDigits(latest);
      if (normalized.isEmpty) {
        return;
      }

      final parsed = int.tryParse(normalized);
      final suggested = parsed == null ? normalized : (parsed + 1).toString();

      _chequeNumberController
        ..text = suggested
        ..selection = TextSelection.collapsed(offset: suggested.length);

      if (mounted) {
        setState(() {});
      }
    } catch (_) {
      // Best-effort suggestion only.
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _imagePicker.pickImage(
      source: source,
      imageQuality: 75,
      maxWidth: 1920,
    );

    if (picked == null) {
      return;
    }

    final bytes = await picked.readAsBytes();
    if (!mounted) {
      return;
    }

    setState(() {
      _imageData = bytes;
    });
  }

  Future<void> _openImagePreview() async {
    if (_imageData == null) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (_) {
        return Dialog.fullscreen(
          child: Scaffold(
            appBar: AppBar(title: const Text('پیش‌نمایش تصویر چک')),
            body: Center(
              child: InteractiveViewer(child: Image.memory(_imageData!)),
            ),
          ),
        );
      },
    );
  }

  bool _validateForSave() {
    final formValid = _formKey.currentState?.validate() ?? false;

    final customValid =
        _selectedBankAccount != null &&
        _selectedCompany != null &&
        _dueDate != null;

    return formValid && customValid;
  }

  Future<bool> _confirmDuplicateIfNeeded(
    int bankAccountId,
    String chequeNumber,
  ) async {
    final duplicates = await _chequeRepository
        .findDuplicatesByBankAccountAndChequeNumber(
          bankAccountId: bankAccountId,
          chequeNumber: chequeNumber,
        );

    if (!mounted) {
      return false;
    }

    if (duplicates.isEmpty) {
      return true;
    }

    final first = duplicates.first;
    final due = Jalali.fromDateTime(first.dueDate);
    final dueText = toPersianDigits(
      '${due.year}/${due.month.toString().padLeft(2, '0')}/${due.day.toString().padLeft(2, '0')}',
    );

    final continueSave = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('هشدار شماره چک تکراری'),
          content: Text(
            'این شماره چک قبلاً برای همین حساب ثبت شده است.\n\n'
            'شماره: ${toPersianDigits(first.chequeNumber)}\n'
            'سررسید: $dueText\n'
            'مبلغ: ${toPersianDigits(first.amountRial.toString())} ریال\n\n'
            'آیا مایل به ادامه ثبت هستید؟',
            textAlign: TextAlign.right,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('انصراف'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('ادامه ثبت'),
            ),
          ],
        );
      },
    );

    return continueSave ?? false;
  }

  Future<void> _save() async {
    setState(() {
      _showValidationErrors = true;
    });

    if (!_validateForSave()) {
      return;
    }

    final bankId = _selectedBankAccount!.id;
    final companyId = _selectedCompany!.id;
    final amount = _amountValue;
    final dueDate = _dueDate;

    if (bankId == null ||
        companyId == null ||
        amount == null ||
        dueDate == null) {
      return;
    }

    final chequeNumber = extractEnglishDigits(_chequeNumberController.text);

    final shouldContinue = await _confirmDuplicateIfNeeded(
      bankId,
      chequeNumber,
    );
    if (!shouldContinue) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final now = DateTime.now();
      final sayadIdDigits = extractEnglishDigits(_sayadIdController.text);
      final description = _descriptionController.text.trim();

      final cheque = Cheque(
        id: 0,
        companyId: companyId,
        bankAccountId: bankId,
        chequeNumber: chequeNumber,
        amountRial: amount,
        issueDate: DateTime(now.year, now.month, now.day),
        dueDate: dueDate.toDateTime(),
        status: ChequeStatus.issued,
        isRegisteredInSayad: _isRegisteredInSayad,
        sayadId: sayadIdDigits.isEmpty ? null : sayadIdDigits,
        description: description.isEmpty ? null : description,
        receiverName: null,
        archivedAt: null,
        imageData: _imageData,
        createdAt: now,
        updatedAt: now,
      );

      await _chequeRepository.insert(cheque);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('چک با موفقیت ثبت شد.')));

      Navigator.of(context).pop(true);
    } catch (e, stackTrace) {
      debugPrint('ChequeFormPage._save failed: $e');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ثبت چک با خطا مواجه شد.')));
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<T?> _showSearchSelector<T>({
    required String title,
    required List<T> items,
    required String Function(T item) itemLabel,
    String? Function(T item)? itemSubtitle,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) {
        return _SearchSelectionSheet<T>(
          title: title,
          items: items,
          itemLabel: itemLabel,
          itemSubtitle: itemSubtitle,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_loadError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('ثبت چک')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_loadError!, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _loadInitialData,
                  child: const Text('تلاش مجدد'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final amountWords = _amountInWords;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('ثبت چک')),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SearchableSelectorField(
                    label: 'حساب بانکی *',
                    value: _selectedBankAccount == null
                        ? null
                        : '${_selectedBankAccount!.bankName} - ${_selectedBankAccount!.accountTitle}',
                    errorText: _bankError,
                    onTap: _selectBankAccount,
                  ),
                  const SizedBox(height: 12),
                  SearchableSelectorField(
                    label: 'شرکت *',
                    value: _selectedCompany?.name,
                    errorText: _companyError,
                    onTap: _selectCompany,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _chequeNumberController,
                    decoration: const InputDecoration(
                      labelText: 'شماره چک *',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: const [ChequeDigitOnlyFormatter()],
                    onChanged: (_) => setState(() {}),
                    validator: (value) {
                      if ((value ?? '').trim().isEmpty) {
                        return 'شماره چک الزامی است.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _amountController,
                    decoration: const InputDecoration(
                      labelText: 'مبلغ *',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: const [ChequeAmountFormatter()],
                    onChanged: (_) => setState(() {}),
                    validator: (value) {
                      final digits = extractEnglishDigits(value ?? '');
                      if (digits.isEmpty) {
                        return 'مبلغ الزامی است.';
                      }

                      final amount = int.tryParse(digits);
                      if (amount == null || amount <= 0) {
                        return 'مبلغ باید بزرگ‌تر از صفر باشد.';
                      }

                      return null;
                    },
                  ),
                  if (_amountValue != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      '${toPersianDigits(_amountController.text)} ریال',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.right,
                    ),
                  ],
                  if (amountWords != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      amountWords,
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.right,
                    ),
                  ],
                  const SizedBox(height: 12),
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: _pickDueDate,
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'تاریخ سررسید *',
                        border: const OutlineInputBorder(),
                        suffixIcon: const Icon(Icons.calendar_today_outlined),
                        errorText: _dueDateError,
                      ),
                      child: Text(
                        _dueDate == null
                            ? 'انتخاب کنید'
                            : _formatJalali(_dueDate!),
                        style: _dueDate == null
                            ? Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).hintColor,
                              )
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _sayadIdController,
                    decoration: const InputDecoration(
                      labelText: 'شناسه ۱۶ رقمی صیاد',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: const [SayadIdFormatter()],
                    validator: (value) {
                      final digits = extractEnglishDigits(value ?? '');
                      if (digits.isEmpty) {
                        return null;
                      }

                      if (digits.length != 16) {
                        return 'شناسه صیاد باید دقیقاً ۱۶ رقم باشد.';
                      }

                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'تصویر چک',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pickImage(ImageSource.camera),
                          icon: const Icon(Icons.photo_camera_outlined),
                          label: const Text('Camera'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pickImage(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library_outlined),
                          label: const Text('Gallery'),
                        ),
                      ),
                    ],
                  ),
                  if (_imageData != null) ...[
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Stack(
                        children: [
                          InkWell(
                            onTap: _openImagePreview,
                            borderRadius: BorderRadius.circular(10),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.memory(
                                _imageData!,
                                width: 110,
                                height: 110,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Positioned(
                            top: -4,
                            right: -4,
                            child: IconButton(
                              onPressed: () {
                                setState(() {
                                  _imageData = null;
                                });
                              },
                              icon: const CircleAvatar(
                                radius: 11,
                                child: Icon(Icons.close, size: 14),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'توضیحات',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 4,
                    minLines: 3,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'پیش‌نمایش چک',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  IgnorePointer(
                    ignoring: true,
                    child: ChequeCompactCard(
                      id: 0,
                      bankName: _selectedBankAccount?.bankName ?? '—',
                      chequeNumber: _chequeNumberController.text.trim().isEmpty
                          ? '—'
                          : _chequeNumberController.text.trim(),
                      dueDate: (_dueDate ?? Jalali.now()).toDateTime(),
                      companyName: _selectedCompany?.name ?? '—',
                      amountRial: _amountValue ?? 0,
                      isRegistered: _isRegisteredInSayad,
                      onToggleRegistered: (_) {},
                      onTap: () {},
                      onEdit: () {},
                      onCancel: () {},
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _isSaving ? null : _save,
                      child: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('ثبت چک'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchSelectionSheet<T> extends StatefulWidget {
  const _SearchSelectionSheet({
    required this.title,
    required this.items,
    required this.itemLabel,
    required this.itemSubtitle,
  });

  final String title;
  final List<T> items;
  final String Function(T item) itemLabel;
  final String? Function(T item)? itemSubtitle;

  @override
  State<_SearchSelectionSheet<T>> createState() =>
      _SearchSelectionSheetState<T>();
}

class _SearchSelectionSheetState<T> extends State<_SearchSelectionSheet<T>> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();

    final items = widget.items
        .where((item) {
          if (query.isEmpty) {
            return true;
          }

          final label = widget.itemLabel(item).toLowerCase();
          final subtitle = (widget.itemSubtitle?.call(item) ?? '')
              .toLowerCase();

          return label.contains(query) || subtitle.contains(query);
        })
        .toList(growable: false);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
              child: Column(
                children: [
                  Text(
                    widget.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'جستجو...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
            ),
            Flexible(
              child: items.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text('موردی یافت نشد.'),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: items.length,
                      separatorBuilder: (_, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return ListTile(
                          title: Text(widget.itemLabel(item)),
                          subtitle: widget.itemSubtitle?.call(item) == null
                              ? null
                              : Text(widget.itemSubtitle!(item)!),
                          onTap: () => Navigator.of(context).pop(item),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
