import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shamsi_date/shamsi_date.dart';

import '../../../../shared/widgets/date_picker/pharmaflow_date_picker.dart';
import '../../../cheques/presentation/utils/cheque_input_formatters.dart';
import '../../data/manager_invoices_repository.dart';
import '../../domain/manager_invoice_settlement.dart';

class InvoiceSettlementPage extends StatefulWidget {
  const InvoiceSettlementPage({
    required this.invoiceIds,
    required this.repository,
    super.key,
  });

  final List<String> invoiceIds;
  final ManagerInvoicesRepository repository;

  @override
  State<InvoiceSettlementPage> createState() => _InvoiceSettlementPageState();
}

class _InvoiceSettlementPageState extends State<InvoiceSettlementPage> {
  final _formKey = GlobalKey<FormState>();
  final _chequeAmountController = TextEditingController();
  final _chequeNumberController = TextEditingController();
  final _cashAmountController = TextEditingController();
  final _trackingNumberController = TextEditingController();
  final _discountController = TextEditingController();
  final _discountDescriptionController = TextEditingController();
  final _notesController = TextEditingController();

  late Future<InvoiceSettlementPreparation> _preparation;
  bool _useCheque = false;
  bool _useCash = false;
  bool _saving = false;
  String? _chequeBankAccountId;
  String? _cashBankAccountId;
  String _cashPaymentMethod = 'BANK_DEPOSIT';
  Jalali _chequeDate = Jalali.now();
  Jalali? _chequeDueDate;
  Jalali _cashDate = Jalali.now();

  @override
  void initState() {
    super.initState();
    _preparation = widget.repository.prepareSettlement(widget.invoiceIds);
    for (final controller in <TextEditingController>[
      _chequeAmountController,
      _cashAmountController,
      _discountController,
    ]) {
      controller.addListener(_amountChanged);
    }
  }

  @override
  void dispose() {
    for (final controller in <TextEditingController>[
      _chequeAmountController,
      _cashAmountController,
      _discountController,
    ]) {
      controller.removeListener(_amountChanged);
    }
    _chequeAmountController.dispose();
    _chequeNumberController.dispose();
    _cashAmountController.dispose();
    _trackingNumberController.dispose();
    _discountController.dispose();
    _discountDescriptionController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _amountChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  double _amount(TextEditingController controller) {
    return double.tryParse(controller.text.replaceAll(',', '').trim()) ?? 0;
  }

  double get _enteredTotal =>
      (_useCheque ? _amount(_chequeAmountController) : 0) +
      (_useCash ? _amount(_cashAmountController) : 0) +
      _amount(_discountController);

  Future<void> _pickDate({required String field}) async {
    final current = switch (field) {
      'cheque' => _chequeDate,
      'due' => _chequeDueDate ?? _chequeDate,
      _ => _cashDate,
    };
    final picked = await PharmaFlowDatePicker.show(
      context: context,
      initialDate: current,
      firstDate: Jalali(1390, 1, 1),
      lastDate: Jalali(1450, 12, 29),
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      if (field == 'cheque') {
        _chequeDate = picked;
      } else if (field == 'due') {
        _chequeDueDate = picked;
      } else {
        _cashDate = picked;
      }
    });
  }

  Future<void> _submit(InvoiceSettlementPreparation data) async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_useCheque && _chequeDueDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تاریخ سررسید چک را انتخاب کنید.')),
      );
      return;
    }

    final totalRemaining = double.parse(data.totalRemainingAmount);
    if (_enteredTotal <= 0 || _enteredTotal > totalRemaining) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _enteredTotal <= 0
                ? 'حداقل یک مبلغ برای چک، نقد یا تخفیف وارد کنید.'
                : 'جمع پرداخت و تخفیف از مانده فاکتورها بیشتر است.',
          ),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await widget.repository.createSettlement(<String, dynamic>{
        'invoiceIds': widget.invoiceIds,
        if (_useCheque)
          'cheque': <String, dynamic>{
            'amount': _amount(_chequeAmountController),
            'bankAccountId': _chequeBankAccountId,
            'chequeNumber': _chequeNumberController.text.trim(),
            'chequeDate': _chequeDate.toDateTime().toIso8601String(),
            if (_chequeDueDate != null)
              'dueDate': _chequeDueDate!.toDateTime().toIso8601String(),
          },
        if (_useCash)
          'cash': <String, dynamic>{
            'amount': _amount(_cashAmountController),
            'bankAccountId': _cashBankAccountId,
            'paymentDate': _cashDate.toDateTime().toIso8601String(),
            'paymentMethod': _cashPaymentMethod,
            if (_trackingNumberController.text.trim().isNotEmpty)
              'trackingNumber': _trackingNumberController.text.trim(),
          },
        'discountAmount': _amount(_discountController),
        if (_discountDescriptionController.text.trim().isNotEmpty)
          'discountDescription': _discountDescriptionController.text.trim(),
        if (_notesController.text.trim().isNotEmpty)
          'notes': _notesController.text.trim(),
      });
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('پرداخت فاکتورها با موفقیت ثبت شد.')),
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ثبت پرداخت انجام نشد؛ اطلاعات را بررسی کنید.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('تسویه فاکتورهای انتخابی')),
        body: FutureBuilder<InvoiceSettlementPreparation>(
          future: _preparation,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || snapshot.data == null) {
              return Center(
                child: FilledButton.icon(
                  onPressed: () {
                    setState(() {
                      _preparation = widget.repository.prepareSettlement(
                        widget.invoiceIds,
                      );
                    });
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('تلاش مجدد'),
                ),
              );
            }
            return _buildForm(snapshot.data!);
          },
        ),
      ),
    );
  }

  Widget _buildForm(InvoiceSettlementPreparation data) {
    final remaining = double.parse(data.totalRemainingAmount);
    final afterSettlement = remaining - _enteredTotal;

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    data.company.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('${data.invoices.length} فاکتور انتخاب شده'),
                  const SizedBox(height: 6),
                  Text(
                    'جمع مانده: ${_formatMoney(remaining)} ریال',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Divider(height: 22),
                  ...data.invoices.map(
                    (invoice) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'فاکتور ${invoice.invoiceNumber ?? '-'} — ${invoice.invoiceDate ?? '-'}',
                            ),
                          ),
                          Text(
                            '${_formatMoney(double.parse(invoice.remainingAmount))} ریال',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            value: _useCheque,
            title: const Text('صدور چک'),
            secondary: const Icon(Icons.receipt_long_outlined),
            onChanged: _saving
                ? null
                : (value) => setState(() => _useCheque = value),
          ),
          if (_useCheque) _chequeFields(data.bankAccounts),
          SwitchListTile(
            value: _useCash,
            title: const Text('پرداخت نقدی / واریز'),
            secondary: const Icon(Icons.payments_outlined),
            onChanged: _saving
                ? null
                : (value) => setState(() => _useCash = value),
          ),
          if (_useCash) _cashFields(data.bankAccounts),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  _amountField(
                    controller: _discountController,
                    label: 'تخفیف نقدی شرکت (ریال)',
                    isRequired: false,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _discountDescriptionController,
                    decoration: const InputDecoration(
                      labelText: 'شرح تخفیف نقدی',
                      hintText: 'مثلاً تخفیف تسویه همان روز شرکت الیت',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _notesController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'توضیحات تسویه',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            color: afterSettlement < 0
                ? Theme.of(context).colorScheme.errorContainer
                : afterSettlement == 0
                ? Colors.green.withValues(alpha: 0.12)
                : Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'جمع پرداخت و تخفیف: ${_formatMoney(_enteredTotal)} ریال',
                  ),
                  const SizedBox(height: 5),
                  Text(
                    afterSettlement < 0
                        ? 'مبلغ ${_formatMoney(-afterSettlement)} ریال بیشتر از مانده است'
                        : afterSettlement == 0
                        ? 'فاکتورهای انتخابی به‌طور کامل تسویه می‌شوند'
                        : 'پس از ثبت ${_formatMoney(afterSettlement)} ریال مانده باقی می‌ماند',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _saving ? null : () => _submit(data),
            icon: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_circle_outline),
            label: const Text('ثبت پرداخت'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _chequeFields(List<InvoiceSettlementBankAccount> accounts) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            _amountField(
              controller: _chequeAmountController,
              label: 'مبلغ چک (ریال)',
              isRequired: true,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _chequeNumberController,
              keyboardType: TextInputType.number,
              inputFormatters: const <TextInputFormatter>[
                ChequeDigitOnlyFormatter(),
              ],
              decoration: const InputDecoration(
                labelText: 'شماره چک',
                border: OutlineInputBorder(),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'شماره چک را وارد کنید'
                  : null,
            ),
            const SizedBox(height: 10),
            _bankField(
              accounts: accounts,
              value: _chequeBankAccountId,
              label: 'حساب صادرکننده چک',
              onChanged: (value) =>
                  setState(() => _chequeBankAccountId = value),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _dateButton(
                    label: 'تاریخ صدور',
                    value: _chequeDate,
                    onPressed: () => _pickDate(field: 'cheque'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _dateButton(
                    label: 'تاریخ سررسید',
                    value: _chequeDueDate,
                    onPressed: () => _pickDate(field: 'due'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _cashFields(List<InvoiceSettlementBankAccount> accounts) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            _amountField(
              controller: _cashAmountController,
              label: 'مبلغ نقد / واریز (ریال)',
              isRequired: true,
            ),
            const SizedBox(height: 10),
            _bankField(
              accounts: accounts,
              value: _cashBankAccountId,
              label: 'حساب پرداخت',
              onChanged: (value) => setState(() => _cashBankAccountId = value),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _cashPaymentMethod,
              decoration: const InputDecoration(
                labelText: 'روش پرداخت',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'BANK_DEPOSIT',
                  child: Text('واریز بانکی / نقدی'),
                ),
                DropdownMenuItem(value: 'POS_PAYMENT', child: Text('کارتخوان')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _cashPaymentMethod = value);
                }
              },
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _trackingNumberController,
              decoration: const InputDecoration(
                labelText: 'شماره پیگیری (اختیاری)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            _dateButton(
              label: 'تاریخ پرداخت',
              value: _cashDate,
              onPressed: () => _pickDate(field: 'cash'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _amountField({
    required TextEditingController controller,
    required String label,
    required bool isRequired,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: const <TextInputFormatter>[ChequeAmountFormatter()],
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      validator: (value) {
        final amount = _amount(controller);
        if (isRequired && amount <= 0) {
          return 'مبلغ را وارد کنید';
        }
        return null;
      },
    );
  }

  Widget _bankField({
    required List<InvoiceSettlementBankAccount> accounts,
    required String? value,
    required String label,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: accounts
          .map(
            (account) => DropdownMenuItem(
              value: account.id,
              child: Text(account.displayName, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(growable: false),
      onChanged: onChanged,
      validator: (selected) =>
          selected == null ? 'حساب بانکی را انتخاب کنید' : null,
    );
  }

  Widget _dateButton({
    required String label,
    required Jalali? value,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.calendar_month_outlined),
      label: Text(value == null ? label : '$label: ${_formatJalali(value)}'),
    );
  }
}

String _formatJalali(Jalali date) =>
    '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';

String _formatMoney(double amount) {
  final digits = amount.round().toString();
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(digits[index]);
  }
  return buffer.toString();
}
