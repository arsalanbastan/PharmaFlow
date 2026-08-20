import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/models/company.dart';
import '../../../../data/repositories/exceptions/repository_exceptions.dart';
import '../providers/company_provider.dart';
import '../widgets/company_name_field.dart';

class CompanyFormPage extends ConsumerStatefulWidget {
  const CompanyFormPage({super.key, this.company});

  final Company? company;

  @override
  ConsumerState<CompanyFormPage> createState() => _CompanyFormPageState();
}

class _CompanyFormPageState extends ConsumerState<CompanyFormPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _nationalIdController;
  late final TextEditingController _economicCodeController;
  late final TextEditingController _bankNameController;
  late final TextEditingController _accountNumberController;
  late final TextEditingController _cardNumberController;
  late final TextEditingController _shebaNumberController;
  late final TextEditingController _notesController;
  late final TextEditingController _visitorNameController;
  late final TextEditingController _visitorPhoneController;
  late final TextEditingController _accountantNameController;
  late final TextEditingController _accountantPhoneController;

  bool _isSaving = false;

  bool get _isEdit => widget.company != null;

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(text: widget.company?.name ?? '');

    _nationalIdController = TextEditingController(
      text: widget.company?.nationalId ?? '',
    );

    _economicCodeController = TextEditingController(
      text: widget.company?.economicCode ?? '',
    );

    _bankNameController = TextEditingController(
      text: widget.company?.bankName ?? '',
    );

    _accountNumberController = TextEditingController(
      text: widget.company?.accountNumber ?? '',
    );

    _cardNumberController = TextEditingController(
      text: _formatCardNumber(widget.company?.cardNumber ?? ''),
    );

    _shebaNumberController = TextEditingController(
      text: _digitsOnly(widget.company?.shebaNumber ?? ''),
    );

    _notesController = TextEditingController(text: widget.company?.notes ?? '');

    _visitorNameController = TextEditingController(
      text: widget.company?.visitorName ?? '',
    );

    _visitorPhoneController = TextEditingController(
      text: widget.company?.visitorPhone ?? '',
    );

    _accountantNameController = TextEditingController(
      text: widget.company?.accountantName ?? '',
    );

    _accountantPhoneController = TextEditingController(
      text: widget.company?.accountantPhone ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nationalIdController.dispose();
    _economicCodeController.dispose();
    _bankNameController.dispose();
    _accountNumberController.dispose();
    _cardNumberController.dispose();
    _shebaNumberController.dispose();
    _notesController.dispose();
    _visitorNameController.dispose();
    _visitorPhoneController.dispose();
    _accountantNameController.dispose();
    _accountantPhoneController.dispose();
    super.dispose();
  }

  String _digitsOnly(String value) {
    return value.replaceAll(RegExp(r'[^0-9]'), '');
  }

  String _formatCardNumber(String value) {
    final digits = _digitsOnly(value);

    if (digits.isEmpty) {
      return '';
    }

    final limited = digits.length > 16 ? digits.substring(0, 16) : digits;

    final groups = <String>[];

    for (var index = 0; index < limited.length; index += 4) {
      final end = (index + 4 < limited.length) ? index + 4 : limited.length;

      groups.add(limited.substring(index, end));
    }

    return groups.join(' ');
  }

  Future<void> _copyBankValue(String value, {bool digitsOnly = false}) async {
    final normalized = digitsOnly
        ? value.replaceAll(RegExp(r'[^0-9]'), '')
        : value.trim();

    if (normalized.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('مقداری برای کپی وجود ندارد.'),
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }

    await Clipboard.setData(ClipboardData(text: normalized));

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('کپی شد'), duration: Duration(seconds: 1)),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      final company = Company(
        id: widget.company?.id,
        name: _nameController.text.trim(),
        nationalId: _nationalIdController.text.trim().isEmpty
            ? null
            : _nationalIdController.text.trim(),
        economicCode: _economicCodeController.text.trim().isEmpty
            ? null
            : _economicCodeController.text.trim(),
        bankName: _bankNameController.text.trim().isEmpty
            ? null
            : _bankNameController.text.trim(),
        accountNumber: _accountNumberController.text.trim().isEmpty
            ? null
            : _accountNumberController.text.trim(),
        cardNumber: _digitsOnly(_cardNumberController.text).isEmpty
            ? null
            : _digitsOnly(_cardNumberController.text),
        shebaNumber: _digitsOnly(_shebaNumberController.text).isEmpty
            ? null
            : _digitsOnly(_shebaNumberController.text),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        visitorName: _visitorNameController.text.trim().isEmpty
            ? null
            : _visitorNameController.text.trim(),
        visitorPhone: _visitorPhoneController.text.trim().isEmpty
            ? null
            : _visitorPhoneController.text.trim(),
        accountantName: _accountantNameController.text.trim().isEmpty
            ? null
            : _accountantNameController.text.trim(),
        accountantPhone: _accountantPhoneController.text.trim().isEmpty
            ? null
            : _accountantPhoneController.text.trim(),
        archivedAt: widget.company?.archivedAt,
        createdAt: widget.company?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (_isEdit) {
        await ref.read(companyProvider.notifier).updateCompany(company);
      } else {
        await ref.read(companyProvider.notifier).addCompany(company);
      }

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      String message;
      if (e is DuplicateCompanyNameException) {
        message = 'این نام شرکت قبلاً ثبت شده است.';
      } else if (e is InvalidNationalIdException) {
        message = 'شناسه ملی وارد شده معتبر نیست.';
      } else if (e is InvalidEconomicCodeException) {
        message = 'کد اقتصادی وارد شده معتبر نیست.';
      } else {
        message = 'ثبت شرکت با خطا روبرو شد. لطفاً دوباره تلاش کنید.';
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _toggleArchiveStatus() async {
    if (!_isEdit || widget.company?.id == null) {
      return;
    }

    try {
      if (widget.company?.archivedAt == null) {
        await ref
            .read(companyProvider.notifier)
            .archiveCompany(widget.company!.id!);
      } else {
        await ref
            .read(companyProvider.notifier)
            .restoreCompany(widget.company!.id!);
      }

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('عملیات با خطا روبرو شد.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'ویرایش شرکت' : 'ثبت شرکت')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              CompanyNameField(
                controller: _nameController,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'نام شرکت الزامی است.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nationalIdController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'شناسه ملی',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return null;
                  }

                  if (!RegExp(r'^\d{11}$').hasMatch(value.trim())) {
                    return 'شناسه ملی باید فقط شامل ۱۱ رقم باشد.';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _economicCodeController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'کد اقتصادی',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'اطلاعات بانکی شرکت',
                textAlign: TextAlign.right,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _bankNameController,
                textAlign: TextAlign.right,
                decoration: const InputDecoration(
                  labelText: 'نام بانک',
                  prefixIcon: Icon(Icons.account_balance_outlined),
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _accountNumberController,
                keyboardType: TextInputType.number,
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.left,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'شماره حساب',
                  suffixIcon: IconButton(
                    tooltip: 'کپی شماره حساب',
                    onPressed: () => _copyBankValue(
                      _accountNumberController.text,
                      digitsOnly: true,
                    ),
                    icon: const Icon(Icons.copy_outlined),
                  ),
                  border: const OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _cardNumberController,
                keyboardType: TextInputType.number,
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.left,
                inputFormatters: const [_CardNumberGroupingFormatter()],
                decoration: InputDecoration(
                  labelText: 'شماره کارت',
                  hintText: '۱۶ رقم',
                  suffixIcon: IconButton(
                    tooltip: 'کپی شماره کارت',
                    onPressed: () => _copyBankValue(
                      _cardNumberController.text,
                      digitsOnly: true,
                    ),
                    icon: const Icon(Icons.copy_outlined),
                  ),
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  final digits = _digitsOnly(value ?? '');

                  if (digits.isEmpty) {
                    return null;
                  }

                  if (!RegExp(r'^\d{16}$').hasMatch(digits)) {
                    return 'شماره کارت باید ۱۶ رقم باشد.';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _shebaNumberController,
                keyboardType: TextInputType.number,
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.left,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(24),
                ],
                decoration: InputDecoration(
                  labelText: 'شماره شبا',
                  hintText: '24 رقم',
                  prefixText: 'IR ',
                  suffixIcon: IconButton(
                    tooltip: 'کپی شماره شبا',
                    onPressed: () => _copyBankValue(
                      _shebaNumberController.text,
                      digitsOnly: true,
                    ),
                    icon: const Icon(Icons.copy_outlined),
                  ),
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  final digits = _digitsOnly(value ?? '');

                  if (digits.isEmpty) {
                    return null;
                  }

                  if (!RegExp(r'^\d{24}$').hasMatch(digits)) {
                    return 'شماره شبا باید دقیقاً ۲۴ رقم باشد.';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 24),

              TextFormField(
                controller: _notesController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'توضیحات',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _visitorNameController,
                decoration: const InputDecoration(
                  labelText: 'نام ویزیتور',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _visitorPhoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'موبایل ویزیتور',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return null;
                  }

                  if (!RegExp(r'^09\d{9}$').hasMatch(value.trim())) {
                    return 'شماره موبایل معتبر نیست.';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _accountantNameController,
                decoration: const InputDecoration(
                  labelText: 'نام حسابدار',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _accountantPhoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'موبایل حسابدار',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return null;
                  }

                  if (!RegExp(r'^09\d{9}$').hasMatch(value.trim())) {
                    return 'شماره موبایل معتبر نیست.';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 32),
              if (_isEdit)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ElevatedButton(
                    onPressed: _toggleArchiveStatus,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.company?.archivedAt == null
                          ? Colors.red
                          : Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(
                      widget.company?.archivedAt == null
                          ? 'غیرفعال‌سازی'
                          : 'فعال‌سازی مجدد',
                    ),
                  ),
                ),
              FilledButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(_isEdit ? 'ذخیره تغییرات' : 'ثبت شرکت'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardNumberGroupingFormatter extends TextInputFormatter {
  const _CardNumberGroupingFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    final limited = digits.length > 16 ? digits.substring(0, 16) : digits;

    final buffer = StringBuffer();

    for (var index = 0; index < limited.length; index++) {
      if (index > 0 && index % 4 == 0) {
        buffer.write(' ');
      }

      buffer.write(limited[index]);
    }

    final formatted = buffer.toString();

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
