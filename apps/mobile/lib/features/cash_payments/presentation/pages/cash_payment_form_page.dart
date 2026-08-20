import 'package:flutter/material.dart';
import 'package:shamsi_date/shamsi_date.dart';

import '../../../../core/database/database_service.dart';
import '../../../../data/models/bank_account.dart';
import '../../../../data/models/cash_payment.dart';
import '../../../../data/models/company.dart';
import '../../../../data/repositories/local/local_bank_account_repository.dart';
import '../../../../data/repositories/local/local_cash_payment_repository.dart';
import '../../../../data/repositories/local/local_company_repository.dart';
import '../../../../shared/widgets/date_picker/pharmaflow_date_picker.dart';
import '../../../cheques/presentation/utils/cheque_input_formatters.dart';
import '../../../cheques/presentation/utils/cheque_text_utils.dart';
import '../../../cheques/presentation/widgets/searchable_selector_field.dart';
import '../widgets/cash_payment_attachment_section.dart';

class CashPaymentFormPage extends StatefulWidget {
  const CashPaymentFormPage({super.key, this.paymentId});

  final int? paymentId;

  @override
  State<CashPaymentFormPage> createState() => _CashPaymentFormPageState();
}

class _CashPaymentFormPageState extends State<CashPaymentFormPage> {
  final _formKey = GlobalKey<FormState>();

  late final LocalCashPaymentRepository _cashPaymentRepository;

  late final LocalCompanyRepository _companyRepository;

  late final LocalBankAccountRepository _bankAccountRepository;

  final _amountController = TextEditingController();

  final _trackingController = TextEditingController();

  final _descriptionController = TextEditingController();

  final _notesController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;

  List<CashPaymentAttachmentDraft> _pendingAttachmentDrafts = const [];
  bool _showValidationErrors = false;

  String? _loadError;

  CashPayment? _editingPayment;

  Company? _selectedCompany;

  BankAccount? _selectedBankAccount;

  Jalali? _paymentDate;

  CashPaymentMethod _paymentMethod = CashPaymentMethod.bankDeposit;

  List<Company> _companies = const [];

  List<BankAccount> _bankAccounts = const [];

  @override
  void initState() {
    super.initState();

    _cashPaymentRepository = LocalCashPaymentRepository(
      DatabaseService.instance,
    );

    _companyRepository = LocalCompanyRepository(DatabaseService.instance);

    _bankAccountRepository = LocalBankAccountRepository(
      DatabaseService.instance,
    );

    _loadInitialData();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _trackingController.dispose();
    _descriptionController.dispose();
    _notesController.dispose();

    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final companies = await _companyRepository.getAll();

      final bankAccounts = await _bankAccountRepository.getAll();

      CashPayment? existing;

      if (widget.paymentId != null) {
        existing = await _cashPaymentRepository.findById(widget.paymentId!);
      }

      if (!mounted) {
        return;
      }

      Company? selectedCompany;
      BankAccount? selectedBank;

      if (existing != null) {
        for (final company in companies) {
          if (company.id == existing.companyId) {
            selectedCompany = company;
            break;
          }
        }

        for (final account in bankAccounts) {
          if (account.id == existing.bankAccountId) {
            selectedBank = account;
            break;
          }
        }
      }

      setState(() {
        _companies = companies;
        _bankAccounts = bankAccounts;

        _editingPayment = existing;

        if (existing != null) {
          final amountText = existing.amountRial.toString();
          _amountController.value = const ChequeAmountFormatter()
              .formatEditUpdate(
                const TextEditingValue(),
                TextEditingValue(
                  text: amountText,
                  selection: TextSelection.collapsed(offset: amountText.length),
                ),
              );

          _trackingController.text = existing.trackingNumber ?? '';

          _descriptionController.text = existing.description ?? '';

          _notesController.text = existing.notes ?? '';

          _paymentDate = Jalali.fromDateTime(existing.paymentDate.toLocal());

          _paymentMethod = existing.paymentMethod;

          _selectedCompany = selectedCompany;

          _selectedBankAccount = selectedBank;
        } else {
          _paymentDate = Jalali.now();
        }

        _isLoading = false;
      });
    } catch (error, stackTrace) {
      debugPrint(
        'CashPaymentFormPage._loadInitialData failed: '
        '$error',
      );

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

  String? get _companyError {
    if (!_showValidationErrors || _selectedCompany != null) {
      return null;
    }

    return 'انتخاب شرکت الزامی است.';
  }

  String? get _bankError {
    if (!_showValidationErrors || _selectedBankAccount != null) {
      return null;
    }

    return 'انتخاب حساب بانکی مبدأ الزامی است.';
  }

  String? get _dateError {
    if (!_showValidationErrors || _paymentDate != null) {
      return null;
    }

    return 'تاریخ پرداخت الزامی است.';
  }

  int? get _amountValue {
    final normalized = _extractEnglishDigits(_amountController.text);

    if (normalized.isEmpty) {
      return null;
    }

    return int.tryParse(normalized);
  }

  String? get _amountInWords => amountToPersianWords(_amountValue);

  Future<void> _pickPaymentDate() async {
    final picked = await PharmaFlowDatePicker.show(
      context: context,
      initialDate: _paymentDate ?? Jalali.now(),
      firstDate: Jalali(1395, 1, 1),
      lastDate: Jalali(1450, 12, 29),
      autoConfirm: false,
    );

    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      _paymentDate = picked;
    });
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

  Future<void> _selectBankAccount() async {
    final selected = await _showSearchSelector<BankAccount>(
      title: 'انتخاب حساب بانکی مبدأ',
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
  }

  Future<void> _save() async {
    final isCreating = _editingPayment == null;

    setState(() {
      _showValidationErrors = true;
    });

    final formValid = _formKey.currentState?.validate() ?? false;

    if (!formValid ||
        _selectedCompany == null ||
        _selectedBankAccount == null ||
        _paymentDate == null) {
      return;
    }

    final amount = _amountValue;

    final companyId = _selectedCompany!.id;

    final bankAccountId = _selectedBankAccount!.id;

    if (amount == null ||
        amount <= 0 ||
        companyId == null ||
        bankAccountId == null) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final now = DateTime.now().toUtc();

      final paymentDateGregorian = _paymentDate!.toDateTime();

      // Noon keeps this date stable when it is
      // converted to UTC for synchronization.
      final paymentDate = DateTime(
        paymentDateGregorian.year,
        paymentDateGregorian.month,
        paymentDateGregorian.day,
        12,
      ).toUtc();

      final payment = CashPayment(
        id: _editingPayment?.id,
        serverUuid: _editingPayment?.serverUuid,
        amountRial: amount,
        paymentDate: paymentDate,
        companyId: companyId,
        bankAccountId: bankAccountId,
        paymentMethod: _paymentMethod,
        trackingNumber: _nullableText(_trackingController.text),
        description: _nullableText(_descriptionController.text),
        notes: _nullableText(_notesController.text),
        archivedAt: _editingPayment?.archivedAt,
        deleteRequestedAt: _editingPayment?.deleteRequestedAt,
        deletedAt: _editingPayment?.deletedAt,
        createdAt: _editingPayment?.createdAt ?? now,
        updatedAt: now,
      );

      int? attachmentPaymentId;

      if (_editingPayment == null) {
        final insertedPaymentId = await _cashPaymentRepository.insert(payment);

        final insertedPayment = await _cashPaymentRepository.findById(
          insertedPaymentId,
        );

        if (insertedPayment == null) {
          throw StateError(
            'New cash payment could not be reloaded after insert.',
          );
        }

        // Switch this form to edit mode immediately after the parent insert.
        // If a later attachment persist fails, pressing Save again updates the
        // existing payment instead of creating a duplicate parent.
        _editingPayment = insertedPayment;
        attachmentPaymentId = insertedPaymentId;
      } else {
        await _cashPaymentRepository.update(payment);
        attachmentPaymentId = _editingPayment!.id;
      }

      if (_pendingAttachmentDrafts.isNotEmpty) {
        final paymentId = attachmentPaymentId;

        if (paymentId == null) {
          throw StateError(
            'Cash payment local id is missing before attachment persist.',
          );
        }

        for (final draft in _pendingAttachmentDrafts) {
          await draft.persist(paymentId);
        }

        _pendingAttachmentDrafts = const [];
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isCreating
                ? 'واریزی با موفقیت ثبت شد.'
                : 'واریزی با موفقیت به‌روزرسانی شد.',
            textAlign: TextAlign.right,
          ),
        ),
      );

      Navigator.of(context).pop(true);
    } catch (error, stackTrace) {
      debugPrint(
        'CashPaymentFormPage._save failed: '
        '$error',
      );

      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'ثبت واریزی با خطا مواجه شد.',
            textAlign: TextAlign.right,
          ),
        ),
      );
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

  String _formatJalali(Jalali value) {
    final raw =
        '${value.year.toString().padLeft(4, '0')}/'
        '${value.month.toString().padLeft(2, '0')}/'
        '${value.day.toString().padLeft(2, '0')}';

    return _toPersianDigits(raw);
  }

  String _extractEnglishDigits(String value) {
    const persian = '۰۱۲۳۴۵۶۷۸۹';

    const arabic = '٠١٢٣٤٥٦٧٨٩';

    var result = value;

    for (var index = 0; index < 10; index++) {
      result = result
          .replaceAll(persian[index], index.toString())
          .replaceAll(arabic[index], index.toString());
    }

    return result.replaceAll(RegExp(r'[^0-9]'), '');
  }

  String _toPersianDigits(String value) {
    const english = '0123456789';

    const persian = '۰۱۲۳۴۵۶۷۸۹';

    var result = value;

    for (var index = 0; index < 10; index++) {
      result = result.replaceAll(english[index], persian[index]);
    }

    return result;
  }

  String? _nullableText(String value) {
    final normalized = value.trim();

    return normalized.isEmpty ? null : normalized;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_loadError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('واریزی')),
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

    final amountInWords = _amountInWords;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_editingPayment == null ? 'ثبت واریزی' : 'ویرایش واریزی'),
        ),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.right,
                    inputFormatters: const [ChequeAmountFormatter()],
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'مبلغ *',
                      suffixText: 'ریال',
                      border: OutlineInputBorder(),
                    ),
                    validator: (_) {
                      final amount = _amountValue;

                      if (amount == null || amount <= 0) {
                        return 'مبلغ معتبر وارد کنید.';
                      }

                      return null;
                    },
                  ),
                  if (amountInWords != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      amountInWords,
                      textAlign: TextAlign.right,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  SearchableSelectorField(
                    label: 'تاریخ پرداخت *',
                    value: _paymentDate == null
                        ? null
                        : _formatJalali(_paymentDate!),
                    errorText: _dateError,
                    onTap: _pickPaymentDate,
                  ),
                  const SizedBox(height: 12),
                  SearchableSelectorField(
                    label: 'شرکت طرف حساب *',
                    value: _selectedCompany?.name,
                    errorText: _companyError,
                    onTap: _selectCompany,
                  ),
                  const SizedBox(height: 12),
                  SearchableSelectorField(
                    label: 'حساب بانکی مبدأ *',
                    value: _selectedBankAccount == null
                        ? null
                        : '${_selectedBankAccount!.bankName} - '
                              '${_selectedBankAccount!.accountTitle}',
                    errorText: _bankError,
                    onTap: _selectBankAccount,
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'روش پرداخت *',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<CashPaymentMethod>(
                    segments: const [
                      ButtonSegment<CashPaymentMethod>(
                        value: CashPaymentMethod.bankDeposit,
                        label: Text('واریز به حساب'),
                        icon: Icon(Icons.account_balance_outlined),
                      ),
                      ButtonSegment<CashPaymentMethod>(
                        value: CashPaymentMethod.posPayment,
                        label: Text('پرداخت توسط پوز'),
                        icon: Icon(Icons.point_of_sale_outlined),
                      ),
                    ],
                    selected: {_paymentMethod},
                    onSelectionChanged: _isSaving
                        ? null
                        : (selection) {
                            if (selection.isEmpty) {
                              return;
                            }

                            setState(() {
                              _paymentMethod = selection.first;
                            });
                          },
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: _trackingController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.right,
                    decoration: const InputDecoration(
                      labelText: 'شماره پیگیری / مرجع',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descriptionController,
                    textAlign: TextAlign.right,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'شرح پرداخت / بابت چه بوده',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _notesController,
                    textAlign: TextAlign.right,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'توضیحات تکمیلی',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  CashPaymentAttachmentSection(
                    cashPaymentId: _editingPayment?.id,
                    onDraftsChanged: (drafts) {
                      _pendingAttachmentDrafts = drafts;
                    },
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _isSaving ? null : _save,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(_isSaving ? 'در حال ذخیره...' : 'ذخیره واریزی'),
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
    this.itemSubtitle,
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

    final filtered = widget.items
        .where((item) {
          final label = widget.itemLabel(item);

          final subtitle = widget.itemSubtitle?.call(item) ?? '';

          final searchable = '$label $subtitle'.toLowerCase();

          return query.isEmpty || searchable.contains(query);
        })
        .toList(growable: false);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.72,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                textAlign: TextAlign.right,
                decoration: const InputDecoration(
                  hintText: 'جستجو...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text('موردی یافت نشد.'))
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = filtered[index];

                        final subtitle = widget.itemSubtitle?.call(item);

                        return ListTile(
                          title: Text(
                            widget.itemLabel(item),
                            textAlign: TextAlign.right,
                          ),
                          subtitle: subtitle == null || subtitle.trim().isEmpty
                              ? null
                              : Text(subtitle, textAlign: TextAlign.right),
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
