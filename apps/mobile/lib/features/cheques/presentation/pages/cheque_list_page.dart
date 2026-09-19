import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shamsi_date/shamsi_date.dart';

import '../../../../core/database/database_service.dart';
import '../../../../data/repositories/local/local_cheque_repository.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../providers/active_cheques_provider.dart';
import '../../../../shared/widgets/date_picker/pharmaflow_date_picker.dart';
import 'cheque_details_page.dart';
import 'cheque_form_page.dart';
import '../widgets/cheque_compact_card.dart';

enum ChequeSortType { issueDate, chequeNumber, dueDate, sayadStatus }

class ChequeListPage extends ConsumerStatefulWidget {
  const ChequeListPage({super.key});

  @override
  ConsumerState<ChequeListPage> createState() => _ChequeListPageState();
}

class _ChequeListPageState extends ConsumerState<ChequeListPage> {
  final TextEditingController _searchController = TextEditingController();
  late final LocalChequeRepository _chequeRepository;
  Jalali? _fromDate;
  Jalali? _toDate;
  ChequeSortType _sortType = ChequeSortType.issueDate;

  @override
  void initState() {
    super.initState();
    _chequeRepository = LocalChequeRepository(DatabaseService.instance);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _pickFromDate() async {
    final picked = await PharmaFlowDatePicker.show(
      context: context,
      initialDate: _fromDate ?? Jalali.now(),
      firstDate: Jalali(1395, 1, 1),
      lastDate: Jalali(1450, 12, 29),
      autoConfirm: false,
    );

    if (picked == null) {
      return;
    }

    setState(() {
      _fromDate = picked;
    });
  }

  Future<void> _pickToDate() async {
    final picked = await PharmaFlowDatePicker.show(
      context: context,
      initialDate: _toDate ?? _fromDate ?? Jalali.now(),
      firstDate: Jalali(1395, 1, 1),
      lastDate: Jalali(1450, 12, 29),
      autoConfirm: false,
    );

    if (picked == null) {
      return;
    }

    setState(() {
      _toDate = picked;
    });
  }

  void _clearDateFilter() {
    setState(() {
      _fromDate = null;
      _toDate = null;
    });
  }

  List<_ChequeListItem> _filteredItems(List<_ChequeListItem> items) {
    final search = _searchController.text.trim().toLowerCase();

    final fromDate = _fromDate?.toDateTime();
    final toDate = _toDate?.toDateTime();

    final filtered = items
        .where((item) {
          if (search.isNotEmpty) {
            final searchable = '${item.companyName} ${item.chequeNumber}'
                .toLowerCase();
            if (!searchable.contains(search)) {
              return false;
            }
          }

          if (fromDate != null && item.issueDate.isBefore(fromDate)) {
            return false;
          }

          if (toDate != null && item.issueDate.isAfter(toDate)) {
            return false;
          }

          return true;
        })
        .toList(growable: false);

    return _sortItems(filtered);
  }

  List<_ChequeListItem> _sortItems(List<_ChequeListItem> items) {
    final sorted = items.toList(growable: true);

    switch (_sortType) {
      case ChequeSortType.issueDate:
        sorted.sort((a, b) {
          final byIssueDate = b.issueDate.compareTo(a.issueDate);
          if (byIssueDate != 0) {
            return byIssueDate;
          }

          return b.createdAt.compareTo(a.createdAt);
        });
        break;
      case ChequeSortType.chequeNumber:
        sorted.sort((a, b) {
          final aNumber = _parseChequeNumber(a.chequeNumber);
          final bNumber = _parseChequeNumber(b.chequeNumber);

          if (aNumber != null && bNumber != null) {
            final byNumber = bNumber.compareTo(aNumber);
            if (byNumber != 0) {
              return byNumber;
            }
          } else if (aNumber != null && bNumber == null) {
            return -1;
          } else if (aNumber == null && bNumber != null) {
            return 1;
          }

          final byRaw = b.chequeNumber.compareTo(a.chequeNumber);
          if (byRaw != 0) {
            return byRaw;
          }

          return b.createdAt.compareTo(a.createdAt);
        });
        break;
      case ChequeSortType.dueDate:
        sorted.sort((a, b) {
          final byDueDate = b.dueDate.compareTo(a.dueDate);
          if (byDueDate != 0) {
            return byDueDate;
          }

          return b.createdAt.compareTo(a.createdAt);
        });
        break;
      case ChequeSortType.sayadStatus:
        sorted.sort((a, b) {
          final aStatus = a.isRegistered ? 1 : 0;
          final bStatus = b.isRegistered ? 1 : 0;
          final byStatus = aStatus.compareTo(bStatus);
          if (byStatus != 0) {
            return byStatus;
          }

          final byIssueDate = b.issueDate.compareTo(a.issueDate);
          if (byIssueDate != 0) {
            return byIssueDate;
          }

          return b.createdAt.compareTo(a.createdAt);
        });
        break;
    }

    return sorted;
  }

  int? _parseChequeNumber(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return null;
    }

    return int.tryParse(digits);
  }

  String _sortLabel(ChequeSortType sortType) {
    switch (sortType) {
      case ChequeSortType.issueDate:
        return 'تاریخ صدور';
      case ChequeSortType.chequeNumber:
        return 'شماره چک';
      case ChequeSortType.dueDate:
        return 'تاریخ سررسید';
      case ChequeSortType.sayadStatus:
        return 'وضعیت ثبت در صیاد';
    }
  }

  Future<void> _openSortSheet() async {
    final selected = await showModalBottomSheet<ChequeSortType>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final bottomInset = MediaQuery.of(sheetContext).viewPadding.bottom;

        return Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.only(bottom: bottomInset + 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'مرتب‌سازی چک‌ها',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  ...ChequeSortType.values.map((sortType) {
                    return ListTile(
                      title: Text(
                        _sortLabel(sortType),
                        textAlign: TextAlign.right,
                      ),
                      trailing: _sortType == sortType
                          ? const Icon(Icons.check, color: Colors.blue)
                          : null,
                      onTap: () => Navigator.of(context).pop(sortType),
                    );
                  }),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (selected == null || selected == _sortType || !mounted) {
      return;
    }

    setState(() {
      _sortType = selected;
    });
  }

  String _jalaliText(Jalali? value) {
    if (value == null) {
      return '—';
    }

    final formatted =
        '${value.year.toString().padLeft(4, '0')}/${value.month.toString().padLeft(2, '0')}/${value.day.toString().padLeft(2, '0')}';

    return _toPersianDigits(formatted);
  }

  String _toPersianDigits(String value) {
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const persian = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];

    var result = value;
    for (var i = 0; i < english.length; i++) {
      result = result.replaceAll(english[i], persian[i]);
    }

    return result;
  }

  Future<void> _openChequeDetails(int chequeId) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ChequeDetailsPage(chequeId: chequeId)),
    );
  }

  Future<void> _toggleRegistered(_ChequeListItem item, bool value) async {
    final providerContainer = ProviderScope.containerOf(context, listen: false);

    if (value && !item.isRegistered) {
      final confirmed = await _confirmSayadRegistration(item);
      if (confirmed != true) {
        return;
      }
    }

    final cheque = await _chequeRepository.findById(item.id);
    if (cheque == null) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('چک انتخاب شده پیدا نشد.', textAlign: TextAlign.right),
        ),
      );
      return;
    }

    await _chequeRepository.update(
      cheque.copyWith(isRegisteredInSayad: value, updatedAt: DateTime.now()),
    );

    invalidateChequeDependentProviders(providerContainer);

    if (!mounted) {
      return;
    }
  }

  Future<bool?> _confirmSayadRegistration(_ChequeListItem item) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('ثبت در سامانه صیاد'),
          content: Text(
            'آیا چک شماره ${item.chequeNumber} مربوط به شرکت ${item.companyName} در سامانه صیاد ثبت شده است؟',
            textAlign: TextAlign.right,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Yes, Registered'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _requestDelete(_ChequeListItem item) async {
    final providerContainer = ProviderScope.containerOf(context, listen: false);

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Cheque'),
          content: Text(
            'Are you sure you want to delete cheque\n'
            '${item.chequeNumber}\n'
            'for company\n'
            '${item.companyName} ?\n\n'
            'This action cannot be undone after synchronization.',
            textAlign: TextAlign.left,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(dialogContext).colorScheme.error,
                foregroundColor: Theme.of(dialogContext).colorScheme.onError,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }

    try {
      await _chequeRepository.requestDelete(item.id);

      invalidateChequeDependentProviders(providerContainer);
      providerContainer.invalidate(dashboardSummaryProvider);
      providerContainer.invalidate(unregisteredChequesCardProvider);
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Unable to delete cheque.')));
      return;
    }

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'چک ${item.chequeNumber} در صف حذف قرار گرفت.',
          textAlign: TextAlign.right,
        ),
      ),
    );
  }

  Future<void> _openCreateCheque() async {
    await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const ChequeFormPage()));
  }

  @override
  Widget build(BuildContext context) {
    final lookupAsync = ref.watch(activeChequeLookupProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('چک‌ها'),
          actions: [
            IconButton(
              onPressed: _openSortSheet,
              tooltip: 'مرتب‌سازی',
              icon: const Icon(Icons.sort),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _openCreateCheque,
          backgroundColor: Colors.blue,
          child: const Icon(Icons.add),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchController,
                textAlign: TextAlign.right,
                decoration: const InputDecoration(
                  hintText: 'جستجو بر اساس شرکت یا شماره چک...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: OutlinedButton.icon(
                      onPressed: _pickFromDate,
                      icon: const Icon(Icons.event_outlined, size: 18),
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('از: ${_jalaliText(_fromDate)}'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 4,
                    child: OutlinedButton.icon(
                      onPressed: _pickToDate,
                      icon: const Icon(Icons.event, size: 18),
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('تا: ${_jalaliText(_toDate)}'),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _clearDateFilter,
                    tooltip: 'پاک کردن فیلتر تاریخ',
                    icon: const Icon(Icons.clear),
                  ),
                ],
              ),
            ),
            Expanded(
              child: lookupAsync.when(
                data: (lookup) {
                  final items = lookup.cheques
                      .map(
                        (cheque) => _ChequeListItem(
                          id: cheque.id,
                          bankName:
                              lookup.bankAccountNames[cheque.bankAccountId] ??
                              '—',
                          chequeNumber: cheque.chequeNumber,
                          issueDate: cheque.issueDate,
                          dueDate: cheque.dueDate,
                          companyName:
                              lookup.companyNames[cheque.companyId] ?? '—',
                          amountRial: cheque.amountRial,
                          isRegistered: cheque.isRegisteredInSayad,
                          createdAt: cheque.createdAt,
                        ),
                      )
                      .toList(growable: false);

                  final filtered = _filteredItems(items);
                  if (filtered.isEmpty) {
                    return const Center(
                      child: Text(
                        'چکی برای نمایش وجود ندارد.',
                        textAlign: TextAlign.right,
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final item = filtered[index];

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: ChequeCompactCard(
                          id: item.id,
                          bankName: item.bankName,
                          chequeNumber: item.chequeNumber,
                          dueDate: item.dueDate,
                          companyName: item.companyName,
                          amountRial: item.amountRial,
                          isRegistered: item.isRegistered,
                          onToggleRegistered: (value) async {
                            final messenger = ScaffoldMessenger.of(
                              this.context,
                            );
                            try {
                              await _toggleRegistered(item, value);
                            } catch (_) {
                              if (!mounted) {
                                rethrow;
                              }

                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'به‌روزرسانی وضعیت ثبت در صیاد با خطا مواجه شد.',
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                              );

                              rethrow;
                            }
                          },
                          onTap: () => _openChequeDetails(item.id),
                          onEdit: () => _openChequeDetails(item.id),
                          onCancel: () => _requestDelete(item),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => const Center(
                  child: Text(
                    'بارگذاری چک‌ها با خطا مواجه شد.',
                    textAlign: TextAlign.right,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChequeListItem {
  const _ChequeListItem({
    required this.id,
    required this.bankName,
    required this.chequeNumber,
    required this.issueDate,
    required this.dueDate,
    required this.companyName,
    required this.amountRial,
    required this.isRegistered,
    required this.createdAt,
  });

  final int id;
  final String bankName;
  final String chequeNumber;
  final DateTime issueDate;
  final DateTime dueDate;
  final String companyName;
  final int amountRial;
  final bool isRegistered;
  final DateTime createdAt;

  _ChequeListItem copyWith({
    int? id,
    String? bankName,
    String? chequeNumber,
    DateTime? issueDate,
    DateTime? dueDate,
    String? companyName,
    int? amountRial,
    bool? isRegistered,
    DateTime? createdAt,
  }) {
    return _ChequeListItem(
      id: id ?? this.id,
      bankName: bankName ?? this.bankName,
      chequeNumber: chequeNumber ?? this.chequeNumber,
      issueDate: issueDate ?? this.issueDate,
      dueDate: dueDate ?? this.dueDate,
      companyName: companyName ?? this.companyName,
      amountRial: amountRial ?? this.amountRial,
      isRegistered: isRegistered ?? this.isRegistered,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseService.instance.initialize();
  runApp(const _ChequeListPrototypeApp());
}

class _ChequeListPrototypeApp extends StatelessWidget {
  const _ChequeListPrototypeApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('fa'), Locale('en')],
      locale: const Locale('fa'),
      theme: ThemeData(useMaterial3: true, fontFamily: 'Vazirmatn'),
      home: const ChequeListPage(),
    );
  }
}
