import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/models/bank_account.dart';
import '../providers/bank_account_provider.dart';
import '../widgets/bank_account_card.dart';
import 'bank_account_form_page.dart';

class BankAccountListPage extends ConsumerStatefulWidget {
  const BankAccountListPage({super.key});

  @override
  ConsumerState<BankAccountListPage> createState() =>
      _BankAccountListPageState();
}

class _BankAccountListPageState
    extends ConsumerState<BankAccountListPage> {
  final TextEditingController _searchController = TextEditingController();
  bool _includeArchived = false;

  @override
  void initState() {
    super.initState();

    Future.microtask(_loadAccounts);
  }

  Future<void> _loadAccounts() async {
    await ref.read(bankAccountProvider.notifier).loadAccounts(
          includeArchived: _includeArchived,
        );
  }

  Future<void> _searchAccounts(String query) async {
    await ref.read(bankAccountProvider.notifier).search(
          query,
          includeArchived: _includeArchived,
        );
  }

  Future<void> _refreshAccounts() async {
    final query = _searchController.text.trim();

    if (query.isEmpty) {
      await _loadAccounts();
      return;
    }

    await _searchAccounts(query);
  }

  Future<void> _openCreatePage() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const BankAccountFormPage(),
      ),
    );

    if (result == true && mounted) {
      await _refreshAccounts();
    }
  }

  Future<void> _openEditPage(BankAccount account) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => BankAccountFormPage(
          account: account,
        ),
      ),
    );

    if (result == true && mounted) {
      await _refreshAccounts();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(bankAccountProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('حساب‌های بانکی'),
          actions: [
            IconButton(
              onPressed: () async {
                setState(() => _includeArchived = !_includeArchived);
                await _refreshAccounts();
              },
              icon: Icon(
                _includeArchived ? Icons.archive_outlined : Icons.archive,
              ),
              tooltip: _includeArchived
                  ? 'نمایش حساب‌های فعال'
                  : 'نمایش همه حساب‌ها',
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
                    hintText: 'جستجو در حساب‌ها...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    _searchAccounts(value);
                  },
                ),
              ),
            ),
            Expanded(
              child: Builder(
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
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              state.errorMessage!,
                              textAlign: TextAlign.right,
                            ),
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: _refreshAccounts,
                              child: const Text('تلاش مجدد'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  if (state.accounts.isEmpty) {
                    return Center(
                      child: Text(
                        _searchController.text.trim().isEmpty
                            ? 'هنوز هیچ حساب بانکی ثبت نشده است.'
                            : 'موردی یافت نشد.',
                        textAlign: TextAlign.right,
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: _refreshAccounts,
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: state.accounts.length,
                      separatorBuilder: (_, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final account = state.accounts[index];

                        return BankAccountCard(
                          account: account,
                          onTap: () => _openEditPage(account),
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