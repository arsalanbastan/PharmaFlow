import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:shamsi_date/shamsi_date.dart';

import '../../../../core/database/database_service.dart';
import '../../../../data/models/cash_payment.dart';
import '../../../../data/models/cheque.dart';
import '../../../../data/models/company.dart';
import '../../../../data/repositories/local/local_cash_payment_repository.dart';
import '../../../../data/repositories/local/local_cheque_repository.dart';
import '../../../../data/repositories/local/local_company_repository.dart';
import '../models/company_account_activity_report_data.dart';
import '../services/company_account_activity_export_service.dart';

class CompanyAccountActivityReportPage extends StatefulWidget {
  const CompanyAccountActivityReportPage({super.key});

  @override
  State<CompanyAccountActivityReportPage> createState() =>
      _CompanyAccountActivityReportPageState();
}

class _CompanyAccountActivityReportPageState
    extends State<CompanyAccountActivityReportPage> {
  final LocalCompanyRepository _companyRepository = LocalCompanyRepository(
    DatabaseService.instance,
  );

  final LocalChequeRepository _chequeRepository = LocalChequeRepository(
    DatabaseService.instance,
  );

  final LocalCashPaymentRepository _cashPaymentRepository =
      LocalCashPaymentRepository(DatabaseService.instance);

  final CompanyAccountActivityExportService _exportService =
      const CompanyAccountActivityExportService();

  final NumberFormat _numberFormat = NumberFormat.decimalPattern('en');

  List<Company> _companies = const [];
  List<Cheque> _cheques = const [];
  List<CashPayment> _cashPayments = const [];

  Company? _selectedCompany;

  bool _isLoading = true;
  bool _exportingExcel = false;
  bool _exportingPdf = false;

  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _loadError = null;
      });
    }

    try {
      final companies = await _companyRepository.getAll();
      final cheques = await _chequeRepository.getAll();
      final cashPayments = await _cashPaymentRepository.getAll();

      Company? selectedCompany = _selectedCompany;
      final selectedCompanyId = selectedCompany?.id;

      if (selectedCompanyId != null) {
        for (final company in companies) {
          if (company.id == selectedCompanyId) {
            selectedCompany = company;
            break;
          }
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _companies = companies;
        _cheques = cheques;
        _cashPayments = cashPayments;
        _selectedCompany = selectedCompany;
        _isLoading = false;
      });
    } catch (error, stackTrace) {
      debugPrint('CompanyAccountActivityReportPage._load failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _loadError = 'بارگذاری گزارش با خطا مواجه شد.';
      });
    }
  }

  List<CompanyAccountActivityRow> get _rows {
    final companyId = _selectedCompany?.id;

    if (companyId == null) {
      return const [];
    }

    return buildCompanyAccountActivityRows(
      companyId: companyId,
      cheques: _cheques,
      cashPayments: _cashPayments,
    );
  }

  int _sumByKind(
    Iterable<CompanyAccountActivityRow> rows,
    CompanyAccountActivityKind kind,
  ) {
    return rows
        .where((row) => row.kind == kind)
        .fold<int>(0, (sum, row) => sum + row.amountRial);
  }

  Future<void> _selectCompany() async {
    final selected = await showModalBottomSheet<Company>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) {
        return _CompanySelectionSheet(
          companies: _companies,
          selectedCompanyId: _selectedCompany?.id,
        );
      },
    );

    if (selected == null || !mounted) {
      return;
    }

    setState(() {
      _selectedCompany = selected;
    });
  }

  Future<void> _shareExcel() async {
    final company = _selectedCompany;
    final rows = _rows;

    if (company == null || rows.isEmpty || _exportingExcel || _exportingPdf) {
      return;
    }

    setState(() {
      _exportingExcel = true;
    });

    try {
      await _exportService.shareExcel(companyName: company.name, rows: rows);
    } catch (error, stackTrace) {
      debugPrint('CompanyAccountActivityReportPage._shareExcel failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      _showMessage('ساخت خروجی Excel با خطا مواجه شد.');
    } finally {
      if (mounted) {
        setState(() {
          _exportingExcel = false;
        });
      }
    }
  }

  Future<void> _sharePdf() async {
    final company = _selectedCompany;
    final rows = _rows;

    if (company == null || rows.isEmpty || _exportingExcel || _exportingPdf) {
      return;
    }

    setState(() {
      _exportingPdf = true;
    });

    try {
      await _exportService.sharePdf(companyName: company.name, rows: rows);
    } catch (error, stackTrace) {
      debugPrint('CompanyAccountActivityReportPage._sharePdf failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      _showMessage('ساخت خروجی PDF با خطا مواجه شد.');
    } finally {
      if (mounted) {
        setState(() {
          _exportingPdf = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    messenger.showSnackBar(
      SnackBar(content: Text(message, textAlign: TextAlign.right)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('گردش حساب طرف حساب‌ها')),
        body: RefreshIndicator(onRefresh: _load, child: _buildBody(rows)),
      ),
    );
  }

  Widget _buildBody(List<CompanyAccountActivityRow> rows) {
    if (_isLoading) {
      return ListView(
        physics: AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: 180),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }

    if (_loadError != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 100),
          Text(_loadError!, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Center(
            child: FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('تلاش مجدد'),
            ),
          ),
        ],
      );
    }

    final selectedCompany = _selectedCompany;

    if (selectedCompany == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _companySelectorCard(),
          const SizedBox(height: 16),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(Icons.account_balance_wallet_outlined, size: 46),
                  SizedBox(height: 12),
                  Text(
                    'برای مشاهده گردش حساب، طرف حساب را انتخاب کنید.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    final totalCheques = _sumByKind(rows, CompanyAccountActivityKind.cheque);

    final totalCashPayments = _sumByKind(
      rows,
      CompanyAccountActivityKind.cashPayment,
    );

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
      itemCount: rows.length + 4,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _companySelectorCard(),
          );
        }

        if (index == 1) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _summaryCard(
              totalCheques: totalCheques,
              totalCashPayments: totalCashPayments,
            ),
          );
        }

        if (index == 2) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _exportButtons(rows),
          );
        }

        if (index == 3) {
          if (rows.isEmpty) {
            return const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'برای این طرف حساب هنوز چک یا واریزی فعالی ثبت نشده است.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
            child: Text(
              'گردش حساب • جدیدترین به قدیمی‌ترین',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          );
        }

        return _activityCard(rows[index - 4]);
      },
    );
  }

  Widget _companySelectorCard() {
    final selectedCompany = _selectedCompany;

    return Card(
      child: ListTile(
        leading: const Icon(Icons.apartment_outlined),
        title: Text(
          selectedCompany?.name ?? 'انتخاب طرف حساب',
          textAlign: TextAlign.right,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          selectedCompany == null
              ? '${_companies.length} طرف حساب فعال'
              : 'برای تغییر طرف حساب لمس کنید',
          textAlign: TextAlign.right,
        ),
        trailing: const Icon(Icons.expand_more),
        onTap: _companies.isEmpty ? null : _selectCompany,
      ),
    );
  }

  Widget _summaryCard({
    required int totalCheques,
    required int totalCashPayments,
  }) {
    final total = totalCheques + totalCashPayments;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'خلاصه پرداخت‌ها',
              textAlign: TextAlign.right,
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 10),
            _summaryLine('جمع چک‌ها', totalCheques),
            const SizedBox(height: 6),
            _summaryLine('جمع واریزی‌ها', totalCashPayments),
            const Divider(height: 18),
            _summaryLine('جمع کل پرداخت‌ها', total, bold: true),
            const SizedBox(height: 8),
            const Text(
              'مانده حساب در این گزارش محاسبه نمی‌شود؛ '
              'فاکتورهای خرید هنوز در گردش بدهکار/بستانکار وارد نشده‌اند.',
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryLine(String label, int amount, {bool bold = false}) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
    );

    return Row(
      children: [
        Expanded(
          child: Text(label, textAlign: TextAlign.right, style: style),
        ),
        const SizedBox(width: 8),
        Text(
          '${_numberFormat.format(amount)} ریال',
          textDirection: TextDirection.ltr,
          style: style,
        ),
      ],
    );
  }

  Widget _exportButtons(List<CompanyAccountActivityRow> rows) {
    final disabled = rows.isEmpty || _exportingExcel || _exportingPdf;

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: disabled ? null : _shareExcel,
            icon: _exportingExcel
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.table_view_outlined),
            label: const Text('Excel'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: disabled ? null : _sharePdf,
            icon: _exportingPdf
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.picture_as_pdf_outlined),
            label: const Text('PDF'),
          ),
        ),
      ],
    );
  }

  Widget _activityCard(CompanyAccountActivityRow row) {
    final isCheque = row.kind == CompanyAccountActivityKind.cheque;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          child: Icon(
            isCheque
                ? Icons.receipt_long_outlined
                : Icons.account_balance_outlined,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                row.typeLabel,
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              _formatJalali(row.effectiveDate),
              textDirection: TextDirection.ltr,
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            'مبلغ: ${_numberFormat.format(row.amountRial)} ریال\n'
            '${isCheque ? 'شماره چک' : 'شماره پیگیری'}: ${row.reference}\n'
            'روش: ${row.method}\n'
            'توضیحات: ${row.description}',
            textAlign: TextAlign.right,
          ),
        ),
        isThreeLine: true,
      ),
    );
  }

  String _formatJalali(DateTime date) {
    final jalali = Jalali.fromDateTime(date.toLocal());

    return '${jalali.year.toString().padLeft(4, '0')}/'
        '${jalali.month.toString().padLeft(2, '0')}/'
        '${jalali.day.toString().padLeft(2, '0')}';
  }
}

class _CompanySelectionSheet extends StatefulWidget {
  const _CompanySelectionSheet({
    required this.companies,
    required this.selectedCompanyId,
  });

  final List<Company> companies;
  final int? selectedCompanyId;

  @override
  State<_CompanySelectionSheet> createState() => _CompanySelectionSheetState();
}

class _CompanySelectionSheetState extends State<_CompanySelectionSheet> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();

    final filtered = widget.companies
        .where(
          (company) =>
              query.isEmpty ||
              company.name.toLowerCase().contains(query) ||
              (company.nationalId?.toLowerCase().contains(query) ?? false),
        )
        .toList(growable: false);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.only(
          left: 12,
          right: 12,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 12,
        ),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.72,
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                autofocus: true,
                textAlign: TextAlign.right,
                onChanged: (_) {
                  setState(() {});
                },
                decoration: const InputDecoration(
                  hintText: 'جستجو بر اساس نام یا شناسه ملی...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: filtered.isEmpty
                    ? const Center(child: Text('طرف حسابی پیدا نشد.'))
                    : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final company = filtered[index];

                          return ListTile(
                            leading: Icon(
                              company.id == widget.selectedCompanyId
                                  ? Icons.check_circle
                                  : Icons.apartment_outlined,
                            ),
                            title: Text(
                              company.name,
                              textAlign: TextAlign.right,
                            ),
                            subtitle: company.nationalId == null
                                ? null
                                : Text(
                                    company.nationalId!,
                                    textAlign: TextAlign.right,
                                  ),
                            onTap: () {
                              Navigator.of(context).pop(company);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
