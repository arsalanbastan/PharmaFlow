import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/company_provider.dart';
import '../widgets/phone_action_row.dart';
import 'company_form_page.dart';

class CompanyListPage extends ConsumerStatefulWidget {
  const CompanyListPage({super.key});

  @override
  ConsumerState<CompanyListPage> createState() => _CompanyListPageState();
}

class _CompanyListPageState extends ConsumerState<CompanyListPage> {
  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      ref.read(companyProvider.notifier).loadCompanies();
    });
  }

  Future<void> _openCreatePage() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const CompanyFormPage(),
      ),
    );

    if (result == true && mounted) {
      await ref.read(companyProvider.notifier).loadCompanies();
    }
  }

  Future<void> _openEditPage(company) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CompanyFormPage(
          company: company,
        ),
      ),
    );

    if (result == true && mounted) {
      await ref.read(companyProvider.notifier).loadCompanies();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(companyProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('شرکت‌ها'),
        ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openCreatePage,
        child: const Icon(Icons.add),
      ),
        body: Builder(
          builder: (_) {
            if (state.isLoading) {
              return const Center(
                child: CircularProgressIndicator(),
              );
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

            return RefreshIndicator(
              onRefresh: () =>
                  ref.read(companyProvider.notifier).loadCompanies(),
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: state.companies.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final company = state.companies[index];

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
                                    phoneNumber: company.visitorPhone ?? '',
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
                                    phoneNumber: company.accountantPhone ?? '',
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
    );
  }
}