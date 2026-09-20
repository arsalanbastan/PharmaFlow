import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shamsi_date/shamsi_date.dart';

import '../../../../shared/widgets/date_picker/pharmaflow_date_picker.dart';
import '../../../cheques/presentation/utils/cheque_input_formatters.dart';
import '../../data/manager_invoices_repository.dart';
import '../../domain/manager_invoice_settlement.dart';
import '../../domain/invoice_maturity_planner.dart';
import '../../domain/invoice_discount_calculator.dart';

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
  String? _paymentMode;
  final Map<String, TextEditingController> _percentControllers = {};
  int _targetDelayDays = 20;
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
    for (final controller in _percentControllers.values) {
      controller.dispose();
    }
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

  Map<String, BigInt>? _invoiceDiscounts(InvoiceSettlementPreparation data) =>
      InvoiceDiscountCalculator.byInvoice(data.invoices, {
        for (final entry in _percentControllers.entries)
          entry.key: entry.value.text,
      });

  void _discountChanged(InvoiceSettlementPreparation data) {
    final amounts = _invoiceDiscounts(data);
    final total = amounts?.values.fold<BigInt>(
        BigInt.zero, (sum, value) => sum + value);
    _discountController.text = total?.toString() ?? '0';
    if (mounted) setState(() {});
  }

  Future<void> _submit(InvoiceSettlementPreparation data) async {
    if (const bool.fromEnvironment('PHARMAFLOW_INVOICE_PREVIEW')) return;
    final allocations = _invoiceDiscounts(data);
    if (allocations == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('درصد تخفیف یک یا چند فاکتور معتبر نیست.')),
      );
      return;
    }
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

    // Backend DTO currently accepts JSON numbers. Do not silently round Rial
    // values that exceed JavaScript's exact integer range.
    final exactValues = <BigInt?>[
      InvoiceMaturityPlan.parseRials(data.totalRemainingAmount),
      InvoiceMaturityPlan.parseRials(_discountController.text),
      if (_useCheque)
        InvoiceMaturityPlan.parseRials(_chequeAmountController.text),
      if (_useCash)
        InvoiceMaturityPlan.parseRials(_cashAmountController.text),
      ...allocations.values,
    ];
    final maxExact = BigInt.from(9007199254740991);
    if (exactValues.any((value) =>
        value == null || value < BigInt.zero || value > maxExact)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('مبلغ نامعتبر یا بیش از حد مجاز است.')),
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
        'discountAllocations': <Map<String, dynamic>>[
          for (final item in allocations.entries)
            if (item.value > BigInt.zero)
              <String, dynamic>{
                'invoiceId': item.key,
                'amount': item.value.toInt(),
              },
        ],
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
        appBar: AppBar(
          title: Text(_paymentMode == null
              ? 'برنامه‌ریزی تسویه'
              : _paymentMode == 'CHEQUE'
                  ? 'ثبت چک فاکتورها'
                  : _paymentMode == 'CASH'
                      ? 'ثبت واریز فاکتورها'
                      : 'پرداخت ترکیبی فاکتورها'),
          leading: _paymentMode == null
              ? null
              : IconButton(
                  tooltip: 'بازگشت به خلاصه تسویه',
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: () => setState(() => _paymentMode = null),
                ),
        ),
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
    final maturityPlan = InvoiceMaturityPlan.fromInvoices(data.invoices);
    final remaining = double.parse(data.totalRemainingAmount);
    final afterSettlement = remaining - _enteredTotal;

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.42),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(data.company.name, style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 5),
              Text('${data.invoices.length} فاکتور انتخاب شده'),
              const SizedBox(height: 4),
              Text('جمع مانده: ${_formatMoney(remaining)} ریال',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w900)),
              if (maturityPlan != null)
                Text('رأس اولیه: ${maturityPlan.originalMaturityJalali}'),
            ]),
          ),
          const SizedBox(height: 9),
          _discountRows(data),
          const SizedBox(height: 5),
          ExpansionTile(
            initiallyExpanded: false,
            title: const Text('محاسبه رأس چک و تأثیر پرداخت نقدی'),
            leading: const Icon(Icons.calculate_outlined),
            children: [
              if (maturityPlan == null)
                const Padding(padding: EdgeInsets.all(12),
                    child: Text('رأس قابل محاسبه نیست؛ اطلاعات سررسید یا مانده ناقص است.'))
              else
                _buildMaturityPlanner(maturityPlan),
            ],
          ),
          const SizedBox(height: 8),
          if (_paymentMode == null) ...[
            Text('روش پرداخت', style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: FilledButton.tonalIcon(
                onPressed: () => setState(() {
                  _paymentMode = 'CHEQUE'; _useCheque = true; _useCash = false;
                }),
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('ثبت چک'),
              )),
              const SizedBox(width: 7),
              Expanded(child: FilledButton.tonalIcon(
                onPressed: () => setState(() {
                  _paymentMode = 'CASH'; _useCheque = false; _useCash = true;
                }),
                icon: const Icon(Icons.account_balance_outlined),
                label: const Text('واریز نقدی'),
              )),
            ]),
            const SizedBox(height: 7),
            OutlinedButton.icon(
              onPressed: () => setState(() {
                _paymentMode = 'COMBINED'; _useCheque = true; _useCash = true;
              }),
              icon: const Icon(Icons.call_split_outlined),
              label: const Text('پرداخت ترکیبی (نقد + چک)'),
            ),
          ] else ...[
            if (_useCash) _cashFields(data.bankAccounts),
            if (_useCheque) _chequeFields(data.bankAccounts),
          ],
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  TextFormField(
                    controller: _discountController,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'جمع تخفیف نقدی فاکتورهای انتخابی (ریال)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.percent),
                    ),
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
          if (_paymentMode != null)
          FilledButton.icon(
            onPressed: _saving || const bool.fromEnvironment('PHARMAFLOW_INVOICE_PREVIEW')
                ? null
                : () => _submit(data),
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

  Widget _discountRows(InvoiceSettlementPreparation data) {
    final amounts = _invoiceDiscounts(data);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            const Icon(Icons.receipt_long_outlined, size: 18),
            const SizedBox(width: 7),
            Text('فاکتورهای انتخابی و تخفیف نقدی',
                style: Theme.of(context).textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 6),
          for (final invoice in data.invoices) ...[
            const Divider(height: 9),
            Row(children: [
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('فاکتور ${invoice.invoiceNumber ?? '-'}',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text('مانده: ${InvoiceMaturityPlan.formatRials(
                        InvoiceMaturityPlan.parseRials(invoice.remainingAmount)
                            ?? BigInt.zero)} ریال',
                      style: Theme.of(context).textTheme.bodySmall),
                  Text('سررسید: ${invoice.settlementDate ?? '-'}',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              )),
              SizedBox(
                width: 74,
                child: TextFormField(
                  controller: _percentControllers.putIfAbsent(
                      invoice.id, () => TextEditingController()),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.center,
                  inputFormatters: [FilteringTextInputFormatter.allow(
                      RegExp(r'[0-9۰-۹٠-٩.]'))],
                  decoration: const InputDecoration(
                    isDense: true,
                    labelText: '٪ تخفیف',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => _discountChanged(data),
                  validator: (value) =>
                      InvoiceDiscountCalculator.basisPoints(value ?? '') == null
                      ? '۰ تا ۱۰۰' : null,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(width: 97, child: Text(
                '${InvoiceMaturityPlan.formatRials(amounts?[invoice.id]
                    ?? BigInt.zero)} ریال',
                textAlign: TextAlign.left,
                style: const TextStyle(fontWeight: FontWeight.w700),
              )),
            ]),
          ],
          const Divider(height: 14),
          Text(
            amounts == null
              ? 'درصد تخفیف را اصلاح کنید.'
              : 'جمع تخفیف: ${InvoiceMaturityPlan.formatRials(
                  amounts.values.fold<BigInt>(BigInt.zero,
                      (sum, value) => sum + value))} ریال',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const Text('درصد هر فاکتور بر مانده همان فاکتور اعمال می‌شود.'),
        ]),
      ),
    );
  }

  Widget _buildMaturityPlanner(InvoiceMaturityPlan plan) {
    final minimumCash = plan.minimumCashForDelayDays(
      _targetDelayDays,
      _cashDate,
    );
    final chequeAmount = _useCheque
        ? InvoiceMaturityPlan.parseRials(_chequeAmountController.text) ??
            BigInt.zero
        : BigInt.zero;
    final cashAmount = _useCash
        ? InvoiceMaturityPlan.parseRials(_cashAmountController.text) ??
            BigInt.zero
        : BigInt.zero;
    final discount = InvoiceMaturityPlan.parseRials(
      _discountController.text.isEmpty ? '0' : _discountController.text,
    );
    final preview = discount == BigInt.zero
        ? plan.previewFullSettlement(
            chequeRials: chequeAmount,
            chequeDueDate: _chequeDueDate,
            cashRials: cashAmount,
            cashDate: _cashDate,
          )
        : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'برآورد رأس پرداخت (فقط پیش‌نمایش)',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text('رأس موزون سررسید اولیه مانده‌ها: '
                '${plan.originalMaturityJalali}'),
            Text('جمع مانده مبنای محاسبه: '
                '${InvoiceMaturityPlan.formatRials(plan.totalRials)} ریال'),
            const SizedBox(height: 8),
            Row(
              children: [
                const Expanded(child: Text('تعویق فرضی چک نسبت به رأس اولیه')),
                IconButton(
                  tooltip: 'یک روز کمتر',
                  onPressed: _targetDelayDays == 0
                      ? null
                      : () => setState(() => _targetDelayDays--),
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Text('$_targetDelayDays روز'),
                IconButton(
                  tooltip: 'یک روز بیشتر',
                  onPressed: _targetDelayDays >= 365
                      ? null
                      : () => setState(() => _targetDelayDays++),
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            Text('تاریخ چک فرضی: '
                '${plan.targetChequeJalali(_targetDelayDays)}'),
            Text('تاریخ نقد فرضی: ${_formatJalali(_cashDate)}'),
            const SizedBox(height: 5),
            Text(
              minimumCash == null
                  ? 'با تاریخ نقد انتخابی، هم‌تراز کردن رأس با این چک '
                      'از طریق پرداخت نقدی ممکن نیست.'
                  : 'حداقل نقدی برای هم‌تراز کردن رأس: '
                      '${InvoiceMaturityPlan.formatRials(minimumCash)} ریال '
                      '(باقی‌مانده با یک چک)',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const Divider(height: 18),
            Text(
              preview == null
                  ? 'برای مقایسه رأس پرداخت واقعی، تسویه کامل بدون تخفیف '
                      'را با مبالغ چک/نقد و تاریخ سررسید چک وارد کنید.'
                  : 'رأس پرداخت واردشده: ${preview.actualMaturityJalali} '
                      '— اختلاف با رأس اولیه: '
                      '${preview.formattedDayDifference} روز',
            ),
            const SizedBox(height: 6),
            Text(
              'این فقط مقایسه ریاضی روی مانده فعلی است؛ '
              'توافق با شرکت، تخفیف و اقساط قبلی در این برآورد لحاظ نمی‌شود. '
              'هیچ تاریخ یا مبلغی خودکار ثبت یا تغییر نمی‌کند.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
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
