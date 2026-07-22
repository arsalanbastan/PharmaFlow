import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/validation/bank_account_validator.dart';
import '../../../../core/widgets/forms/app_text_field.dart';
import '../../../../data/models/bank_account.dart';
import '../../../../data/repositories/exceptions/repository_exceptions.dart';
import '../providers/bank_account_provider.dart';

class BankAccountFormPage extends ConsumerStatefulWidget {
  const BankAccountFormPage({
    super.key,
    this.account,
  });

  final BankAccount? account;

  @override
  ConsumerState<BankAccountFormPage> createState() =>
      _BankAccountFormPageState();
}

class _BankAccountFormPageState
    extends ConsumerState<BankAccountFormPage> {
  final _formKey = GlobalKey<FormState>();

  static const List<String> _banks = [
    'بانک ملت',
    'بانک سامان',
    'بانک ملی',
    'بانک صادرات',
    'بانک تجارت',
    'بانک پاسارگاد',
    'بانک پارسیان',
    'بانک سپه',
    'بانک کشاورزی',
    'بانک آینده',
    'بانک شهر',
    'سایر...',
  ];

  String? _selectedBank;
  bool _customBank = false;
  bool _isSaving = false;

  late final TextEditingController _bankController;
  late final TextEditingController _titleController;
  late final TextEditingController _holderController;
  late final TextEditingController _accountNumberController;
  late final TextEditingController _cardNumberController;
  late final TextEditingController _ibanController;
  late final TextEditingController _noteController;

  bool get _isEdit => widget.account != null;

  @override
  void initState() {
    super.initState();

    final account = widget.account;

    _bankController =
        TextEditingController(text: account?.bankName ?? '');

    _titleController =
        TextEditingController(text: account?.accountTitle ?? '');

    _holderController =
        TextEditingController(text: account?.accountHolder ?? '');

    _accountNumberController =
        TextEditingController(text: account?.accountNumber ?? '');

    _cardNumberController =
        TextEditingController(text: account?.cardNumber ?? '');

    _ibanController =
        TextEditingController(text: account?.iban ?? 'IR');

    _noteController =
        TextEditingController(text: account?.note ?? '');

    if (account != null) {
      if (_banks.contains(account.bankName)) {
        _selectedBank = account.bankName;
      } else {
        _selectedBank = 'سایر...';
        _customBank = true;
      }
    }
  }

  @override
  void dispose() {
    _bankController.dispose();
    _titleController.dispose();
    _holderController.dispose();
    _accountNumberController.dispose();
    _cardNumberController.dispose();
    _ibanController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  String get _bankName =>
      _customBank
          ? BankAccountValidator.normalizeText(_bankController.text)
          : (_selectedBank ?? '');

  BankAccount _buildAccount() {
    return BankAccount(
      id: widget.account?.id,
      bankName: _bankName,
      accountTitle: BankAccountValidator.normalizeText(
        _titleController.text,
      ),
      accountHolder: BankAccountValidator.normalizeText(
        _holderController.text,
      ),
      accountNumber: BankAccountValidator.normalizeDigits(
        _accountNumberController.text,
      ),
      cardNumber: BankAccountValidator.normalizeDigits(
        _cardNumberController.text,
      ),
      iban: BankAccountValidator.normalizeIban(
        _ibanController.text,
      ),
      note: BankAccountValidator.normalizeOptionalText(
        _noteController.text,
      ),
      archivedAt: widget.account?.archivedAt,
      createdAt: widget.account?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  String _errorMessage(Object error) {
    if (error is DuplicateBankAccountNameException) {
      return 'عنوان این حساب قبلاً ثبت شده است.';
    }

    if (error is ArgumentError) {
      return 'اطلاعات حساب بانکی معتبر نیست.';
    }

    return 'ذخیره حساب بانکی با خطا روبه‌رو شد. لطفاً دوباره تلاش کنید.';
  }

  Future<void> _toggleArchiveStatus() async {
    if (!_isEdit || widget.account?.id == null || _isSaving) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      if (widget.account?.archivedAt == null) {
        await ref.read(bankAccountProvider.notifier).archiveAccount(
              widget.account!.id!,
            );
      } else {
        await ref.read(bankAccountProvider.notifier).restoreAccount(
              widget.account!.id!,
            );
      }

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('عملیات با خطا روبه‌رو شد.'),
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

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _isEdit ? 'ویرایش حساب بانکی' : 'ثبت حساب بانکی',
          ),
        ),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _selectedBank,
                  decoration: const InputDecoration(
                    labelText: 'بانک *',
                  ),
                  items: _banks
                      .map(
                        (bank) => DropdownMenuItem(
                          value: bank,
                          child: Text(bank),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedBank = value;
                      _customBank = value == 'سایر...';

                      if (!_customBank) {
                        _bankController.text = value ?? '';
                      }
                    });
                  },
                  validator: (_) {
                    if (_selectedBank == null) {
                      return 'بانک را انتخاب کنید.';
                    }
                    return null;
                  },
                ),

                if (_customBank) ...[
                  const SizedBox(height: 16),
                  AppTextField(
                    controller: _bankController,
                    label: 'نام بانک *',
                    textInputAction: TextInputAction.next,
                    textAlign: TextAlign.right,
                    validator: BankAccountValidator.validateBankName,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                  ),
                ],

                const SizedBox(height: 16),

                AppTextField(
                  controller: _titleController,
                  label: 'عنوان حساب *',
                  textInputAction: TextInputAction.next,
                  textAlign: TextAlign.right,
                  validator: BankAccountValidator.validateAccountTitle,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                ),

                const SizedBox(height: 16),

                AppTextField(
                  controller: _holderController,
                  label: 'صاحب حساب *',
                  textInputAction: TextInputAction.next,
                  textAlign: TextAlign.right,
                  validator: BankAccountValidator.validateAccountHolder,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                ),

                const SizedBox(height: 16),

                AppTextField(
                  controller: _accountNumberController,
                  label: 'شماره حساب',
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  textAlign: TextAlign.right,
                  validator: BankAccountValidator.validateAccountNumber,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),

                const SizedBox(height: 16),

                AppTextField(
                  controller: _cardNumberController,
                  label: 'شماره کارت',
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  textAlign: TextAlign.right,
                  validator: BankAccountValidator.validateCardNumber,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    _CardNumberFormatter(),
                  ],
                ),

                const SizedBox(height: 16),

                AppTextField(
                  controller: _ibanController,
                  label: 'شماره شبا',
                  textInputAction: TextInputAction.next,
                  textAlign: TextAlign.right,
                  validator: BankAccountValidator.validateIban,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                ),

                const SizedBox(height: 16),

                AppTextField(
                  controller: _noteController,
                  label: 'توضیحات',
                  textInputAction: TextInputAction.newline,
                  textAlign: TextAlign.right,
                  maxLines: 5,
                ),

                const SizedBox(height: 32),

                if (_isEdit)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: FilledButton(
                      onPressed: _toggleArchiveStatus,
                      style: FilledButton.styleFrom(
                        backgroundColor: widget.account?.archivedAt == null
                            ? Colors.red
                            : Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(
                        widget.account?.archivedAt == null
                            ? 'غیرفعال‌سازی'
                            : 'فعال‌سازی مجدد',
                      ),
                    ),
                  ),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: _isSaving ? null : _save,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.save),
                    label: Text(
                      _isSaving
                          ? 'در حال ذخیره...'
                          : (_isEdit ? 'ذخیره تغییرات' : 'ثبت حساب بانکی'),
                    ),
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final account = _buildAccount();

      final notifier = ref.read(bankAccountProvider.notifier);

      if (_isEdit) {
        await notifier.updateAccount(account);
      } else {
        await notifier.addAccount(account);
      }

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_errorMessage(e)),
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
}

class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(' ', '');

    final buffer = StringBuffer();

    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && i % 4 == 0) {
        buffer.write(' ');
      }

      buffer.write(digits[i]);
    }

    final text = buffer.toString();

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(
        offset: text.length,
      ),
    );
  }
}