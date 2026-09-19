import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/models/company.dart';
import '../providers/company_provider.dart';
import '../widgets/phone_action_row.dart';
import 'company_form_page.dart';

class CompanyListPage extends ConsumerStatefulWidget {
  const CompanyListPage({super.key});

  @override
  ConsumerState<CompanyListPage> createState() => _CompanyListPageState();
}

class _CompanyListPageState extends ConsumerState<CompanyListPage> {
  final TextEditingController _searchController = TextEditingController();
  bool _includeArchived = false;

  @override
  void initState() {
    super.initState();

    Future.microtask(_loadCompanies);
  }

  Future<void> _loadCompanies() async {
    await ref
        .read(companyProvider.notifier)
        .loadCompanies(includeArchived: _includeArchived);
  }

  Future<void> _openCreatePage() async {
    final result = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const CompanyFormPage()));

    if (result == true && mounted) {
      await ref.read(companyProvider.notifier).loadCompanies();
    }
  }

  Future<void> _openEditPage(Company company) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => CompanyFormPage(company: company)),
    );

    if (result == true && mounted) {
      await ref.read(companyProvider.notifier).loadCompanies();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(companyProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('شرکت‌ها'),
          actions: [
            IconButton(
              onPressed: () async {
                setState(() => _includeArchived = !_includeArchived);
                await _loadCompanies();
              },
              icon: Icon(
                _includeArchived ? Icons.archive_outlined : Icons.archive,
              ),
              tooltip: _includeArchived
                  ? 'نمایش شرکت‌های فعال'
                  : 'نمایش همه شرکت‌ها',
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _openCreatePage,
          child: const Icon(Icons.add),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: TextField(
                  controller: _searchController,
                  textAlign: TextAlign.right,
                  decoration: const InputDecoration(
                    hintText: 'جستجو...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ),
            Expanded(
              child: Builder(
                builder: (_) {
                  if (state.isLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (state.errorMessage != null) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          state.errorMessage!,
                          textAlign: TextAlign.right,
                        ),
                      ),
                    );
                  }

                  if (state.companies.isEmpty) {
                    return const Center(
                      child: Text(
                        'هنوز هیچ شرکتی ثبت نشده است.',
                        textAlign: TextAlign.right,
                      ),
                    );
                  }

                  final query = _searchController.text.trim().toLowerCase();
                  final filteredCompanies = query.isEmpty
                      ? state.companies
                      : state.companies.where((company) {
                          final searchableValues = [
                            company.name,
                            company.nationalId,
                            company.bankName,
                            company.accountNumber,
                            company.cardNumber,
                            company.shebaNumber,
                            company.visitorName,
                            company.visitorPhone,
                            company.accountantName,
                            company.accountantPhone,
                          ];

                          return searchableValues.any(
                            (value) =>
                                (value ?? '').toLowerCase().contains(query),
                          );
                        }).toList();

                  if (filteredCompanies.isEmpty) {
                    return const Center(
                      child: Text(
                        'موردی یافت نشد.',
                        textAlign: TextAlign.right,
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: _loadCompanies,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      itemCount: filteredCompanies.length,
                      separatorBuilder: (_, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final company = filteredCompanies[index];

                        return GestureDetector(
                          onTap: () => _openEditPage(company),
                          child: Card(
                            clipBehavior: Clip.antiAlias,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    company.name,
                                    textAlign: TextAlign.right,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    company.nationalId ?? 'شناسه ملی ثبت نشده',
                                    textAlign: TextAlign.right,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'ویزیتور: ${company.visitorName ?? '—'}',
                                    textAlign: TextAlign.right,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: PhoneActionRow(
                                          phoneNumber:
                                              company.visitorPhone ?? '',
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'حسابدار: ${company.accountantName ?? '—'}',
                                    textAlign: TextAlign.right,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: PhoneActionRow(
                                          phoneNumber:
                                              company.accountantPhone ?? '',
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
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
