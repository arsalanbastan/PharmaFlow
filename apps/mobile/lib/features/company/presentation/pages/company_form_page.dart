import 'package:flutter/material.dart';
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
    _notesController.dispose();
    _visitorNameController.dispose();
    _visitorPhoneController.dispose();
    _accountantNameController.dispose();
    _accountantPhoneController.dispose();
    super.dispose();
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
                decoration: const InputDecoration(
                  labelText: 'کد اقتصادی',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
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
