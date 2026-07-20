import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/models/company.dart';
import '../providers/company_provider.dart';

class CompanyFormPage extends ConsumerStatefulWidget {
  const CompanyFormPage({
    super.key,
    this.company,
  });

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

  bool _isSaving = false;

  bool get _isEdit => widget.company != null;

  @override
  void initState() {
    super.initState();

    _nameController =
        TextEditingController(text: widget.company?.name ?? '');

    _nationalIdController =
        TextEditingController(text: widget.company?.nationalId ?? '');

    _economicCodeController =
        TextEditingController(text: widget.company?.economicCode ?? '');

    _notesController =
        TextEditingController(text: widget.company?.notes ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nationalIdController.dispose();
    _economicCodeController.dispose();
    _notesController.dispose();
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEdit ? 'ویرایش شرکت' : 'ثبت شرکت',
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'نام شرکت *',
                  border: OutlineInputBorder(),
                ),
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
              const SizedBox(height: 32),
              FilledButton.icon(
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
                  _isEdit ? 'ذخیره تغییرات' : 'ثبت شرکت',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}