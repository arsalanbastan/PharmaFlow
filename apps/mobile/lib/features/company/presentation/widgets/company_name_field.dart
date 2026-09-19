import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/forms/app_text_field.dart';
import '../providers/company_duplicate_provider.dart';
import 'company_duplicate_warning.dart';

class CompanyNameField extends ConsumerStatefulWidget {
  const CompanyNameField({
    super.key,
    required this.controller,
    this.validator,
  });

  final TextEditingController controller;
  final FormFieldValidator<String>? validator;

  @override
  ConsumerState<CompanyNameField> createState() => _CompanyNameFieldState();
}

class _CompanyNameFieldState extends ConsumerState<CompanyNameField> {
  Timer? _debounceTimer;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounceTimer?.cancel();

    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {});
      }
      ref.invalidate(companyDuplicateProvider(value));
    });
  }

  @override
  Widget build(BuildContext context) {
    final duplicateResult = ref.watch(
      companyDuplicateProvider(widget.controller.text),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppTextField(
          controller: widget.controller,
          label: 'نام شرکت *',
          hint: 'مثلاً هجرت',
          textInputAction: TextInputAction.next,
          validator: widget.validator,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          onChanged: (value) => _onChanged(value),
        ),
        const SizedBox(height: 12),
        duplicateResult.when(
          data: (companies) => CompanyDuplicateWarning(
            input: widget.controller.text,
            companies: companies,
          ),
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
        ),
      ],
    );
  }
}
