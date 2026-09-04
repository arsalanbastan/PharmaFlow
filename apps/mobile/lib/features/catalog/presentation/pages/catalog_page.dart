import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../settings/presentation/providers/communication_settings_provider.dart';
import '../../data/manager_catalog_repository.dart';
import '../../domain/manager_catalog_item.dart';

class CatalogPage extends ConsumerStatefulWidget {
  const CatalogPage({super.key});

  @override
  ConsumerState<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends ConsumerState<CatalogPage> {
  final _searchController = TextEditingController();
  final List<ManagerCatalogSummary> _items = [];

  Timer? _searchDebounce;
  int _requestSerial = 0;

  bool _loading = true;
  bool _loadingMore = false;

  String? _error;
  String _query = '';
  String? _category;

  int _page = 1;
  int _totalPages = 1;
  int _totalCount = 0;

  ManagerCatalogRepository get _repository =>
      ManagerCatalogRepository(ref.read(apiClientProvider));

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _load(reset: true));
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({required bool reset}) async {
    final requestId = reset ? ++_requestSerial : _requestSerial;
    final querySnapshot = _query;
    final categorySnapshot = _category;

    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
        _page = 1;
      });
    } else {
      if (_loadingMore || _page >= _totalPages) {
        return;
      }

      setState(() {
        _loadingMore = true;
      });
    }

    try {
      final requestedPage = reset ? 1 : _page + 1;

      final result = await _repository.getPage(
        query: querySnapshot,
        category: categorySnapshot,
        page: requestedPage,
      );

      if (!mounted ||
          requestId != _requestSerial ||
          querySnapshot != _query ||
          categorySnapshot != _category) {
        return;
      }

      setState(() {
        if (reset) {
          _items
            ..clear()
            ..addAll(result.items);
        } else {
          _items.addAll(result.items);
        }

        _page = result.page;
        _totalPages = result.totalPages;
        _totalCount = result.totalCount;
        _error = null;
      });
    } catch (_) {
      if (!mounted || requestId != _requestSerial) {
        return;
      }

      setState(() {
        _error = 'دریافت فهرست دارو و کالا انجام نشد.';
      });
    } finally {
      if (mounted && requestId == _requestSerial) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  void _scheduleLiveSearch(String value) {
    _searchDebounce?.cancel();

    final nextQuery = value.trim();

    setState(() {
      _query = nextQuery;
    });

    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) {
        return;
      }

      _load(reset: true);
    });
  }

  Future<void> _search() async {
    _searchDebounce?.cancel();
    FocusScope.of(context).unfocus();

    setState(() {
      _query = _searchController.text.trim();
    });

    await _load(reset: true);
  }

  Future<void> _clearSearch() async {
    _searchDebounce?.cancel();
    _searchController.clear();

    setState(() {
      _query = '';
    });

    await _load(reset: true);
  }

  Future<void> _setCategory(String? category) async {
    if (_category == category) {
      return;
    }

    _searchDebounce?.cancel();

    setState(() {
      _category = category;
    });

    await _load(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('دارو / کالاها'),
          actions: [
            IconButton(
              tooltip: 'بروزرسانی',
              onPressed: _loading ? null : () => _load(reset: true),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                onChanged: _scheduleLiveSearch,
                onSubmitted: (_) => _search(),
                decoration: InputDecoration(
                  labelText: 'جستجوی هوشمند دارو یا کالا',
                  hintText: 'نام ژنریک، برند یا بخشی از نام',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isEmpty
                      ? IconButton(
                          tooltip: 'جستجو',
                          onPressed: _search,
                          icon: const Icon(Icons.arrow_back),
                        )
                      : IconButton(
                          tooltip: 'پاک کردن',
                          onPressed: _clearSearch,
                          icon: const Icon(Icons.close),
                        ),
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  ChoiceChip(
                    label: const Text('همه'),
                    selected: _category == null,
                    onSelected: (_) => _setCategory(null),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('دارو'),
                    selected: _category == 'DRUG',
                    onSelected: (_) => _setCategory('DRUG'),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('کالا'),
                    selected: _category == 'GOODS',
                    onSelected: (_) => _setCategory('GOODS'),
                  ),
                ],
              ),
            ),
            if (!_loading && _error == null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'نمایش ${_items.length} از $_totalCount مورد',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _items.isEmpty) {
      return _CatalogErrorView(
        message: _error!,
        onRetry: () => _load(reset: true),
      );
    }

    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _load(reset: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 120),
            Icon(Icons.inventory_2_outlined, size: 60),
            SizedBox(height: 12),
            Center(child: Text('موردی پیدا نشد.')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _load(reset: true),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(10, 4, 10, 24),
        itemCount: _items.length + 1,
        itemBuilder: (context, index) {
          if (index == _items.length) {
            if (_page >= _totalPages) {
              return const SizedBox(height: 12);
            }

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: _loadingMore
                    ? const CircularProgressIndicator()
                    : OutlinedButton.icon(
                        onPressed: () => _load(reset: false),
                        icon: const Icon(Icons.expand_more),
                        label: const Text('نمایش موارد بیشتر'),
                      ),
              ),
            );
          }

          final item = _items[index];

          return _CatalogCard(
            item: item,
            onTap: () {
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => CatalogDetailsPage(
                    itemId: item.id,
                    repository: _repository,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _CatalogCard extends StatelessWidget {
  const _CatalogCard({required this.item, required this.onTap});

  final ManagerCatalogSummary item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = _catalogTitle(item);
    final secondary = _catalogSecondary(item);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  _CatalogBadge(
                    text: item.category == 'DRUG' ? 'دارو' : 'کالا',
                  ),
                  if (!item.isActive) ...[
                    const SizedBox(width: 6),
                    const _CatalogBadge(text: 'غیرفعال'),
                  ],
                ],
              ),
              if (secondary != null) ...[
                const SizedBox(height: 5),
                Text(secondary, style: Theme.of(context).textTheme.bodySmall),
              ],
              const SizedBox(height: 9),
              Wrap(
                spacing: 14,
                runSpacing: 7,
                children: [
                  if (item.shapeName != null)
                    _CatalogInfo(text: item.shapeName!),
                  if (item.unit != null)
                    _CatalogInfo(text: 'واحد: ${item.unit}'),
                  if (item.packetQuantity != null)
                    _CatalogInfo(text: 'بسته: ${item.packetQuantity}'),
                  _CatalogInfo(text: 'آرسن: ${item.arsenDrugId}'),
                ],
              ),
              const Divider(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _PriceBlock(
                      label: 'آخرین خرید',
                      value: item.lastPurchasePrice,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _PriceBlock(
                      label: 'قیمت فروش',
                      value: item.salesPrice,
                    ),
                  ),
                  const Icon(Icons.chevron_left),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CatalogDetailsPage extends StatefulWidget {
  const CatalogDetailsPage({
    required this.itemId,
    required this.repository,
    super.key,
  });

  final String itemId;
  final ManagerCatalogRepository repository;

  @override
  State<CatalogDetailsPage> createState() => _CatalogDetailsPageState();
}

class _CatalogDetailsPageState extends State<CatalogDetailsPage> {
  late Future<ManagerCatalogDetails> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.getById(widget.itemId);
  }

  void _retry() {
    setState(() {
      _future = widget.repository.getById(widget.itemId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('جزئیات دارو / کالا')),
        body: FutureBuilder<ManagerCatalogDetails>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError || snapshot.data == null) {
              return _CatalogErrorView(
                message: 'دریافت جزئیات انجام نشد.',
                onRetry: () async => _retry(),
              );
            }

            final item = snapshot.data!;

            return ListView(
              padding: const EdgeInsets.all(12),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          item.displayName,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 14),
                        _DetailRow(
                          label: 'نوع',
                          value: item.category == 'DRUG' ? 'دارو' : 'کالا',
                        ),
                        _DetailRow(
                          label: 'وضعیت',
                          value: item.isActive ? 'فعال' : 'غیرفعال',
                        ),
                        _DetailRow(label: 'کد آرسن', value: item.arsenDrugId),
                        if (item.persianName != null)
                          _DetailRow(
                            label: 'نام فارسی',
                            value: item.persianName!,
                          ),
                        if (item.genericName != null)
                          _DetailRow(
                            label: 'نام ژنریک',
                            value: item.genericName!,
                          ),
                        if (item.persianBrandName != null)
                          _DetailRow(
                            label: 'برند فارسی',
                            value: item.persianBrandName!,
                          ),
                        if (item.brandName != null)
                          _DetailRow(label: 'برند', value: item.brandName!),
                        if (item.shapeName != null)
                          _DetailRow(label: 'شکل', value: item.shapeName!),
                        if (item.unit != null)
                          _DetailRow(label: 'واحد', value: item.unit!),
                        if (item.packetQuantity != null)
                          _DetailRow(
                            label: 'تعداد در بسته',
                            value: item.packetQuantity.toString(),
                          ),
                        _DetailRow(
                          label: 'آخرین قیمت خرید',
                          value: _formatAmount(item.lastPurchasePrice),
                        ),
                        _DetailRow(
                          label: 'قیمت فروش',
                          value: _formatAmount(item.salesPrice),
                        ),
                        if (item.description != null)
                          _DetailRow(
                            label: 'توضیحات',
                            value: item.description!,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CatalogBadge extends StatelessWidget {
  const _CatalogBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(text, style: const TextStyle(fontSize: 11)),
      ),
    );
  }
}

class _CatalogInfo extends StatelessWidget {
  const _CatalogInfo({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: Theme.of(context).textTheme.bodySmall);
  }
}

class _PriceBlock extends StatelessWidget {
  const _PriceBlock({required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 3),
        Text(
          _formatAmount(value),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 125, child: Text('$label:')),
          Expanded(child: Text(value, textAlign: TextAlign.left)),
        ],
      ),
    );
  }
}

class _CatalogErrorView extends StatelessWidget {
  const _CatalogErrorView({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 52),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('تلاش مجدد'),
            ),
          ],
        ),
      ),
    );
  }
}

String _catalogTitle(ManagerCatalogSummary item) {
  final generic = _cleanLabel(item.genericName);
  final primary = generic ?? item.displayName.trim();

  final brandCandidates = <String?>[item.persianBrandName, item.brandName];

  for (final rawBrand in brandCandidates) {
    final brand = _cleanLabel(rawBrand);

    if (brand == null) {
      continue;
    }

    if (_sameCatalogLabel(brand, primary)) {
      continue;
    }

    return '$primary ($brand)';
  }

  return primary;
}

String? _catalogSecondary(ManagerCatalogSummary item) {
  final generic = _cleanLabel(item.genericName);
  final persianBrand = _cleanLabel(item.persianBrandName);
  final brand = _cleanLabel(item.brandName);

  final candidates = <String?>[item.persianName, item.displayName];

  for (final value in candidates) {
    final normalized = _cleanLabel(value);

    if (normalized == null) {
      continue;
    }

    if (generic != null && _sameCatalogLabel(normalized, generic)) {
      continue;
    }

    if (persianBrand != null && _sameCatalogLabel(normalized, persianBrand)) {
      continue;
    }

    if (brand != null && _sameCatalogLabel(normalized, brand)) {
      continue;
    }

    return normalized;
  }

  return null;
}

String? _cleanLabel(String? value) {
  final normalized = value?.trim();

  if (normalized == null || normalized.isEmpty) {
    return null;
  }

  return normalized;
}

bool _sameCatalogLabel(String left, String right) {
  return _normalizeCatalogLabel(left) == _normalizeCatalogLabel(right);
}

String _normalizeCatalogLabel(String value) {
  return value
      .replaceAll('ي', 'ی')
      .replaceAll('ى', 'ی')
      .replaceAll('ك', 'ک')
      .replaceAll('\u200c', ' ')
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String _formatAmount(String? raw) {
  final normalized = raw?.trim();

  if (normalized == null || normalized.isEmpty) {
    return '-';
  }

  final split = normalized.split('.');
  var integerPart = split.first;

  final negative = integerPart.startsWith('-');

  if (negative) {
    integerPart = integerPart.substring(1);
  }

  final buffer = StringBuffer();

  for (var index = 0; index < integerPart.length; index++) {
    if (index > 0 && (integerPart.length - index) % 3 == 0) {
      buffer.write(',');
    }

    buffer.write(integerPart[index]);
  }

  final result = '${negative ? '-' : ''}$buffer';

  if (split.length < 2) {
    return result;
  }

  final decimalPart = split[1].replaceFirst(RegExp(r'0+$'), '');

  return decimalPart.isEmpty ? result : '$result.$decimalPart';
}
