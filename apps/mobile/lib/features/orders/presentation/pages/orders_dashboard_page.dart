import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/auth/auth_provider.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_constants.dart';
import '../../../../core/notifications/manager_push_device_registration_service.dart';
import '../../../../shared/app_shell/app_bottom_navigation.dart';
import '../../../../shared/app_shell/app_scaffold.dart';
import '../../../settings/presentation/providers/communication_settings_provider.dart';
import '../../data/manager_orders_auth_service.dart';
import '../../data/order_dashboard_settings.dart';
import '../../data/manager_orders_repository.dart';
import 'order_details_page.dart';
import '../../domain/manager_order.dart';

final managerOrdersRepositoryProvider = Provider<ManagerOrdersRepository>((
  ref,
) {
  return ManagerOrdersRepository(ref.watch(apiClientProvider));
});

final managerOrdersProvider = FutureProvider<List<ManagerOrder>>((ref) async {
  return ref.watch(managerOrdersRepositoryProvider).getAll();
});
const _lastAssignedCompanyIdPreferenceKey = 'manager_orders_last_company_id_v1';

class _AssignableCompany {
  const _AssignableCompany({required this.id, required this.name});

  final String id;
  final String name;
}

final managerOrderCompaniesProvider = FutureProvider<List<_AssignableCompany>>((
  ref,
) async {
  final payload = await ref
      .watch(apiClientProvider)
      .get(ApiConstants.companiesEndpoint);

  if (payload is! List<dynamic>) {
    throw const ApiDecodingException(
      'Expected a JSON list from the Companies endpoint.',
    );
  }

  String? readString(Object? value) {
    if (value is! String) {
      return null;
    }

    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }

  final companies = <_AssignableCompany>[];

  for (final raw in payload) {
    if (raw is! Map<String, dynamic>) {
      continue;
    }

    if (raw['deletedAt'] != null ||
        raw['deleted_at'] != null ||
        raw['archivedAt'] != null ||
        raw['archived_at'] != null) {
      continue;
    }

    final id =
        readString(raw['id']) ??
        readString(raw['serverUuid']) ??
        readString(raw['server_uuid']);
    final name = readString(raw['name']);

    if (id == null || name == null) {
      continue;
    }

    companies.add(_AssignableCompany(id: id, name: name));
  }

  companies.sort(
    (left, right) =>
        left.name.toLowerCase().compareTo(right.name.toLowerCase()),
  );

  return companies;
});

enum _ManagerOrdersAuthPhase { loading, unauthenticated, authenticated, error }

class OrdersDashboardPage extends ConsumerStatefulWidget {
  const OrdersDashboardPage({super.key});

  @override
  ConsumerState<OrdersDashboardPage> createState() =>
      _OrdersDashboardPageState();
}

class _OrdersDashboardPageState extends ConsumerState<OrdersDashboardPage> {
  _ManagerOrdersAuthPhase _authPhase = _ManagerOrdersAuthPhase.loading;
  ManagerOrdersAuthUser? _user;
  String? _authError;
  bool _loginSubmitting = false;

  @override
  void initState() {
    super.initState();

    Future.microtask(_restoreSession);
  }

  ManagerOrdersAuthService _authService() {
    final apiClient = ref.read(apiClientProvider);

    return ManagerOrdersAuthService(
      apiClient: apiClient,
      tokenStorage: ref.read(authTokenStorageProvider),
      pushDevices: ManagerPushDeviceRegistrationService(apiClient: apiClient),
    );
  }

  Future<void> _restoreSession() async {
    if (mounted) {
      setState(() {
        _authPhase = _ManagerOrdersAuthPhase.loading;
        _authError = null;
      });
    }

    final storage = ref.read(authTokenStorageProvider);
    final token = await storage.getToken();

    if (!mounted) {
      return;
    }

    if (token == null) {
      setState(() {
        _user = null;
        _authPhase = _ManagerOrdersAuthPhase.unauthenticated;
      });

      return;
    }

    final service = _authService();

    try {
      final user = await service.me();

      if (!mounted) {
        return;
      }

      setState(() {
        _user = user;
        _authPhase = _ManagerOrdersAuthPhase.authenticated;
        _authError = null;
      });
    } on ApiHttpException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        await service.clearLocalSession();

        if (!mounted) {
          return;
        }

        setState(() {
          _user = null;
          _authPhase = _ManagerOrdersAuthPhase.unauthenticated;
          _authError = null;
        });

        return;
      }

      _setRestoreError();
    } on ManagerOrdersAuthException {
      await service.clearLocalSession();

      if (!mounted) {
        return;
      }

      setState(() {
        _user = null;
        _authPhase = _ManagerOrdersAuthPhase.unauthenticated;
        _authError = null;
      });
    } catch (_) {
      _setRestoreError();
    }
  }

  void _setRestoreError() {
    if (!mounted) {
      return;
    }

    setState(() {
      _authPhase = _ManagerOrdersAuthPhase.error;
      _authError =
          'بررسی نشست مدیر انجام نشد. اتصال اینترنت و تنظیمات سرور را بررسی کنید.';
    });
  }

  Future<void> _login({
    required String username,
    required String password,
  }) async {
    if (_loginSubmitting) {
      return;
    }

    setState(() {
      _loginSubmitting = true;
      _authError = null;
    });

    try {
      final user = await _authService().login(
        username: username,
        password: password,
      );

      if (!mounted) {
        return;
      }

      ref.invalidate(managerOrdersProvider);

      setState(() {
        _user = user;
        _authPhase = _ManagerOrdersAuthPhase.authenticated;
        _authError = null;
      });
    } on ApiHttpException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _authError = error.statusCode == 401
            ? 'نام کاربری یا رمز عبور صحیح نیست.'
            : error.message;
      });
    } on ManagerOrdersAuthException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _authError = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _authError = 'ورود انجام نشد. اتصال به سرور را بررسی کنید.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loginSubmitting = false;
        });
      }
    }
  }

  Future<void> _invalidateSession() async {
    await _authService().clearLocalSession();

    if (!mounted) {
      return;
    }

    ref.invalidate(managerOrdersProvider);

    setState(() {
      _user = null;
      _authPhase = _ManagerOrdersAuthPhase.unauthenticated;
      _authError = 'نشست مدیر منقضی شده است. دوباره وارد شوید.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }

        context.go('/');
      },
      child: AppScaffold(
        title: '',
        currentDestination: AppShellDestination.orders,
        body: switch (_authPhase) {
          _ManagerOrdersAuthPhase.loading => const Center(
            child: CircularProgressIndicator(),
          ),
          _ManagerOrdersAuthPhase.unauthenticated => _ManagerOrdersLoginView(
            submitting: _loginSubmitting,
            errorMessage: _authError,
            onLogin: _login,
          ),
          _ManagerOrdersAuthPhase.error => _OrdersAuthErrorView(
            message: _authError ?? 'خطا در بررسی نشست مدیر.',
            onRetry: _restoreSession,
          ),
          _ManagerOrdersAuthPhase.authenticated => _OrdersDashboardContent(
            user: _user!,
            onSessionInvalid: _invalidateSession,
          ),
        },
      ),
    );
  }
}

class _ManagerOrdersLoginView extends StatefulWidget {
  const _ManagerOrdersLoginView({
    required this.submitting,
    required this.errorMessage,
    required this.onLogin,
  });

  final bool submitting;
  final String? errorMessage;
  final Future<void> Function({
    required String username,
    required String password,
  })
  onLogin;

  @override
  State<_ManagerOrdersLoginView> createState() =>
      _ManagerOrdersLoginViewState();
}

class _ManagerOrdersLoginViewState extends State<_ManagerOrdersLoginView> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (widget.submitting) {
      return;
    }

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    await widget.onLogin(
      username: _usernameController.text,
      password: _passwordController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.admin_panel_settings_outlined,
                    size: 68,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'ورود مدیر',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'برای مشاهده و مدیریت سفارشات وارد حساب مدیر شوید.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _usernameController,
                    enabled: !widget.submitting,
                    autofocus: true,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'نام کاربری',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value?.trim().isEmpty ?? true) {
                        return 'نام کاربری را وارد کنید.';
                      }

                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _passwordController,
                    enabled: !widget.submitting,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      labelText: 'رمز عبور',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        onPressed: widget.submitting
                            ? null
                            : () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.length < 6) {
                        return 'رمز عبور را وارد کنید.';
                      }

                      return null;
                    },
                  ),
                  if (widget.errorMessage != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      widget.errorMessage!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: widget.submitting ? null : _submit,
                    icon: widget.submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.login),
                    label: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      child: Text(
                        widget.submitting ? 'در حال ورود...' : 'ورود',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OrdersAuthErrorView extends StatelessWidget {
  const _OrdersAuthErrorView({required this.message, required this.onRetry});

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
            const SizedBox(height: 16),
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

class _OrdersDashboardContent extends ConsumerStatefulWidget {
  const _OrdersDashboardContent({
    required this.user,
    required this.onSessionInvalid,
  });

  final ManagerOrdersAuthUser user;
  final Future<void> Function() onSessionInvalid;

  @override
  ConsumerState<_OrdersDashboardContent> createState() =>
      _OrdersDashboardContentState();
}

class _OrdersDashboardContentState
    extends ConsumerState<_OrdersDashboardContent> {
  final _searchController = TextEditingController();

  String _selectedStatus = 'PENDING';
  String? _selectedCategory;
  String? _lastCompanyId;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadLastCompany);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadLastCompany() async {
    final preferences = await SharedPreferences.getInstance();
    final value = preferences.getString(_lastAssignedCompanyIdPreferenceKey);

    if (!mounted) {
      return;
    }

    setState(() {
      _lastCompanyId = value;
    });
  }

  Future<void> _setLastCompany(_AssignableCompany company) async {
    if (mounted) {
      setState(() {
        _lastCompanyId = company.id;
      });
    }

    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _lastAssignedCompanyIdPreferenceKey,
      company.id,
    );
  }

  void _refreshAll() {
    ref.invalidate(managerOrdersProvider);
    ref.invalidate(managerOrderCompaniesProvider);
  }

  void _setSearchQuery(String value) {
    setState(() {
      _searchQuery = value;
    });
  }

  void _clearSearch() {
    _searchController.clear();

    if (_searchQuery.isEmpty) {
      return;
    }

    setState(() {
      _searchQuery = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(managerOrdersProvider);
    final companiesAsync = ref.watch(managerOrderCompaniesProvider);
    final shortageDaysAsync = ref.watch(orderShortageDaysProvider);
    final shortageDays =
        shortageDaysAsync.valueOrNull ?? defaultOrderShortageDays;

    return KeyedSubtree(
      key: ValueKey(widget.user.displayName),
      child: ordersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) {
          final unauthorized =
              error is ApiHttpException &&
              (error.statusCode == 401 || error.statusCode == 403);

          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    unauthorized
                        ? Icons.lock_clock_outlined
                        : Icons.error_outline,
                    size: 42,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    unauthorized
                        ? 'نشست مدیر معتبر نیست.'
                        : 'بارگذاری سفارشات انجام نشد.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: unauthorized
                        ? widget.onSessionInvalid
                        : _refreshAll,
                    icon: Icon(unauthorized ? Icons.login : Icons.refresh),
                    label: Text(unauthorized ? 'ورود مجدد' : 'بارگذاری مجدد'),
                  ),
                ],
              ),
            ),
          );
        },
        data: (orders) {
          final searchableOrders = orders
              .where((order) {
                final category = _selectedCategory;

                if (category != null && order.category != category) {
                  return false;
                }

                return _matchesOrderSearch(order, _searchQuery);
              })
              .toList(growable: false);

          final counts = <String, int>{
            'PENDING': 0,
            'ORDERED': 0,
            'SHORTAGE': 0,
            'CANCELED': 0,
          };

          for (final order in searchableOrders) {
            if (order.status == 'PENDING') {
              counts['PENDING'] = counts['PENDING']! + 1;

              if (_isShortage(order, shortageDays)) {
                counts['SHORTAGE'] = counts['SHORTAGE']! + 1;
              }
            } else if (order.status == 'ORDERED') {
              counts['ORDERED'] = counts['ORDERED']! + 1;
            } else if (order.status == 'CANCELED') {
              counts['CANCELED'] = counts['CANCELED']! + 1;
            }
          }

          final filtered = searchableOrders
              .where((order) {
                if (_selectedStatus == 'SHORTAGE') {
                  return _isShortage(order, shortageDays);
                }

                return order.status == _selectedStatus;
              })
              .toList(growable: false);

          final companies =
              companiesAsync.asData?.value ?? const <_AssignableCompany>[];

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 4, 6, 0),
                child: Column(
                  children: [
                    _DenseOrdersHeader(onRefresh: _refreshAll),
                    const SizedBox(height: 5),
                    _DenseStatusBar(
                      counts: counts,
                      selectedStatus: _selectedStatus,
                      onSelected: (status) {
                        setState(() {
                          _selectedStatus = status;
                        });
                      },
                    ),
                    const SizedBox(height: 5),
                    _DenseCategoryBar(
                      selectedCategory: _selectedCategory,
                      onSelected: (category) {
                        setState(() {
                          _selectedCategory = _selectedCategory == category
                              ? null
                              : category;
                        });
                      },
                    ),
                    const SizedBox(height: 5),
                    _DenseSearchBar(
                      controller: _searchController,
                      query: _searchQuery,
                      onChanged: _setSearchQuery,
                      onClear: _clearSearch,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 5),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    _refreshAll();
                    await ref.read(managerOrdersProvider.future);
                  },
                  child: _DenseOrdersList(
                    orders: filtered,
                    status: _selectedStatus,
                    companies: companies,
                    companiesLoading: companiesAsync.isLoading,
                    companiesError: companiesAsync.hasError,
                    lastCompanyId: _lastCompanyId,
                    onDefaultCompanyChanged: _setLastCompany,
                    onSessionInvalid: widget.onSessionInvalid,
                    onRetryCompanies: () {
                      ref.invalidate(managerOrderCompaniesProvider);
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DenseOrdersHeader extends StatelessWidget {
  const _DenseOrdersHeader({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return SizedBox(
      height: 34,
      child: Material(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsetsDirectional.only(start: 9, end: 2),
          child: Row(
            children: [
              Icon(
                Icons.shopping_cart_checkout,
                size: 17,
                color: colors.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'داشبورد سفارشات',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'بروزرسانی',
                onPressed: onRefresh,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 30,
                  height: 30,
                ),
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.refresh, size: 19),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DenseStatusBar extends StatelessWidget {
  const _DenseStatusBar({
    required this.counts,
    required this.selectedStatus,
    required this.onSelected,
  });

  final Map<String, int> counts;
  final String selectedStatus;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: Row(
        children: [
          Expanded(
            child: _DenseStatusButton(
              status: 'PENDING',
              label: 'در انتظار',
              icon: Icons.pending_actions_outlined,
              count: counts['PENDING'] ?? 0,
              selected: selectedStatus == 'PENDING',
              onTap: onSelected,
            ),
          ),
          const SizedBox(width: 3),
          Expanded(
            child: _DenseStatusButton(
              status: 'ORDERED',
              label: 'سفارش‌شده',
              icon: Icons.inventory_2_outlined,
              count: counts['ORDERED'] ?? 0,
              selected: selectedStatus == 'ORDERED',
              onTap: onSelected,
            ),
          ),
          const SizedBox(width: 3),
          Expanded(
            child: _DenseStatusButton(
              status: 'SHORTAGE',
              label: 'کسری‌ها',
              icon: Icons.report_problem_outlined,
              count: counts['SHORTAGE'] ?? 0,
              selected: selectedStatus == 'SHORTAGE',
              onTap: onSelected,
            ),
          ),
          const SizedBox(width: 3),
          Expanded(
            child: _DenseStatusButton(
              status: 'CANCELED',
              label: 'لغوشده',
              icon: Icons.cancel_outlined,
              count: counts['CANCELED'] ?? 0,
              selected: selectedStatus == 'CANCELED',
              onTap: onSelected,
            ),
          ),
        ],
      ),
    );
  }
}

class _DenseStatusButton extends StatelessWidget {
  const _DenseStatusButton({
    required this.status,
    required this.label,
    required this.icon,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String status;
  final String label;
  final IconData icon;
  final int count;
  final bool selected;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final foreground = selected
        ? colors.onPrimaryContainer
        : colors.onSurfaceVariant;

    return Material(
      color: selected ? colors.primaryContainer : colors.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(7),
        side: BorderSide(
          color: selected ? colors.primary : colors.outlineVariant,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => onTap(status),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 13, color: foreground),
              const SizedBox(width: 2),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: foreground,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 3),
              Text(
                _toPersianDigits(count.toString()),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DenseCategoryBar extends StatelessWidget {
  const _DenseCategoryBar({
    required this.selectedCategory,
    required this.onSelected,
  });

  final String? selectedCategory;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(7),
        child: Row(
          children: [
            Expanded(
              child: _DenseCategoryButton(
                category: 'DRUG',
                label: 'دارو',
                icon: Icons.medication_outlined,
                selected: selectedCategory == 'DRUG',
                onTap: onSelected,
              ),
            ),
            const SizedBox(width: 3),
            Expanded(
              child: _DenseCategoryButton(
                category: 'GOODS',
                label: 'کالا',
                icon: Icons.shopping_bag_outlined,
                selected: selectedCategory == 'GOODS',
                onTap: onSelected,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DenseCategoryButton extends StatelessWidget {
  const _DenseCategoryButton({
    required this.category,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String category;
  final String label;
  final IconData icon;
  final bool selected;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final foreground = selected
        ? colors.onPrimaryContainer
        : colors.onSurfaceVariant;

    return Material(
      color: selected ? colors.primaryContainer : Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => onTap(category),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: foreground),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: foreground,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DenseSearchBar extends StatelessWidget {
  const _DenseSearchBar({
    required this.controller,
    required this.query,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 31,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              maxLines: 1,
              textInputAction: TextInputAction.search,
              style: const TextStyle(fontSize: 11.5),
              decoration: const InputDecoration(
                isDense: true,
                hintText: 'جستجو',
                prefixIcon: Icon(Icons.search, size: 17),
                prefixIconConstraints: BoxConstraints.tightFor(
                  width: 29,
                  height: 29,
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 6,
                ),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 3),
          SizedBox(
            width: 31,
            height: 31,
            child: IconButton(
              tooltip: 'پاک کردن جستجو',
              onPressed: query.isEmpty ? null : onClear,
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.close, size: 17),
            ),
          ),
        ],
      ),
    );
  }
}

class _DenseOrdersList extends StatelessWidget {
  const _DenseOrdersList({
    required this.orders,
    required this.status,
    required this.companies,
    required this.companiesLoading,
    required this.companiesError,
    required this.lastCompanyId,
    required this.onDefaultCompanyChanged,
    required this.onSessionInvalid,
    required this.onRetryCompanies,
  });

  final List<ManagerOrder> orders;
  final String status;
  final List<_AssignableCompany> companies;
  final bool companiesLoading;
  final bool companiesError;
  final String? lastCompanyId;
  final Future<void> Function(_AssignableCompany company)
  onDefaultCompanyChanged;
  final Future<void> Function() onSessionInvalid;
  final VoidCallback onRetryCompanies;

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(6, 28, 6, 8),
        children: [
          Text(
            'آیتمی برای نمایش وجود ندارد.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];

        if (status == 'PENDING' || status == 'SHORTAGE') {
          return _DensePendingOrderRow(
            key: ValueKey(order.id),
            order: order,
            companies: companies,
            companiesLoading: companiesLoading,
            companiesError: companiesError,
            lastCompanyId: lastCompanyId,
            onDefaultCompanyChanged: onDefaultCompanyChanged,
            onSessionInvalid: onSessionInvalid,
            onRetryCompanies: onRetryCompanies,
          );
        }

        return _DenseReadOnlyOrderRow(
          key: ValueKey(order.id),
          order: order,
          onSessionInvalid: onSessionInvalid,
        );
      },
    );
  }
}

class _DensePendingOrderRow extends ConsumerStatefulWidget {
  const _DensePendingOrderRow({
    required this.order,
    required this.companies,
    required this.companiesLoading,
    required this.companiesError,
    required this.lastCompanyId,
    required this.onDefaultCompanyChanged,
    required this.onSessionInvalid,
    required this.onRetryCompanies,
    super.key,
  });

  final ManagerOrder order;
  final List<_AssignableCompany> companies;
  final bool companiesLoading;
  final bool companiesError;
  final String? lastCompanyId;
  final Future<void> Function(_AssignableCompany company)
  onDefaultCompanyChanged;
  final Future<void> Function() onSessionInvalid;
  final VoidCallback onRetryCompanies;

  @override
  ConsumerState<_DensePendingOrderRow> createState() =>
      _DensePendingOrderRowState();
}

class _DensePendingOrderRowState extends ConsumerState<_DensePendingOrderRow> {
  _AssignableCompany? _selectedCompany;
  bool _busy = false;
  int? _lastCompanyFieldTapAt;

  _AssignableCompany? _companyById(String? id) {
    final normalized = id?.trim();

    if (normalized == null || normalized.isEmpty) {
      return null;
    }

    for (final company in widget.companies) {
      if (company.id == normalized) {
        return company;
      }
    }

    return null;
  }

  _AssignableCompany? _companyByName(String value) {
    final normalized = value.trim().toLowerCase();

    if (normalized.isEmpty) {
      return null;
    }

    for (final company in widget.companies) {
      if (company.name.trim().toLowerCase() == normalized) {
        return company;
      }
    }

    return null;
  }

  void _openCompanyOptionsForEmptyField(TextEditingController controller) {
    if (controller.text.isNotEmpty) {
      return;
    }

    controller.value = const TextEditingValue(
      text: ' ',
      selection: TextSelection.collapsed(offset: 1),
    );

    controller.value = const TextEditingValue(
      text: '',
      selection: TextSelection.collapsed(offset: 0),
    );
  }

  void _handleCompanyFieldTap(TextEditingController controller) {
    if (_busy) {
      return;
    }

    if (controller.text.isEmpty) {
      _openCompanyOptionsForEmptyField(controller);
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final previous = _lastCompanyFieldTapAt;

    _lastCompanyFieldTapAt = now;

    if (previous == null || now - previous > 450) {
      return;
    }

    _lastCompanyFieldTapAt = null;

    final company = _selectedCompany ?? _companyByName(controller.text);

    if (company == null) {
      return;
    }

    if (_selectedCompany?.id != company.id) {
      setState(() {
        _selectedCompany = company;
      });
    }

    unawaited(_assign());
  }

  Iterable<_AssignableCompany> _optionsFor(String query) {
    final normalized = query.trim().toLowerCase();

    if (normalized.isEmpty) {
      final preferred = _companyById(widget.lastCompanyId);
      final result = <_AssignableCompany>[];

      if (preferred != null) {
        result.add(preferred);
      }

      for (final company in widget.companies) {
        if (result.length >= 12) {
          break;
        }

        if (preferred != null && company.id == preferred.id) {
          continue;
        }

        result.add(company);
      }

      return result;
    }

    return widget.companies
        .where((company) => company.name.toLowerCase().contains(normalized))
        .take(12);
  }

  void _selectFirstVisibleCompanyAndClose(
    TextEditingController controller,
    FocusNode focusNode,
  ) {
    final options = _optionsFor(controller.text).toList(growable: false);

    if (options.isEmpty) {
      focusNode.unfocus();
      return;
    }

    final firstCompany = options.first;

    controller.value = TextEditingValue(
      text: firstCompany.name,
      selection: TextSelection.collapsed(offset: firstCompany.name.length),
    );

    setState(() {
      _selectedCompany = firstCompany;
    });

    focusNode.unfocus();
  }

  Future<void> _assign() async {
    if (_busy) {
      return;
    }

    final company = _selectedCompany;

    if (company == null) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              duration: Duration(milliseconds: 900),
              content: Text('ابتدا شرکت پخش را انتخاب کنید.'),
            ),
          );
      }

      return;
    }

    setState(() {
      _busy = true;
    });

    try {
      await ref
          .read(managerOrdersRepositoryProvider)
          .assign(orderId: widget.order.id, companyId: company.id);

      await widget.onDefaultCompanyChanged(company);
      ref.invalidate(managerOrdersProvider);
    } on ApiHttpException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        await widget.onSessionInvalid();
        return;
      }

      _showMutationError(error.message);
    } catch (_) {
      _showMutationError('ثبت سفارش انجام نشد. دوباره تلاش کنید.');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _openDetails() async {
    if (_busy) {
      return;
    }

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => OrderDetailsPage(
          orderId: widget.order.id,
          repository: ref.read(managerOrdersRepositoryProvider),
        ),
      ),
    );
  }

  Future<void> _edit() async {
    if (_busy) {
      return;
    }

    final result = await showModalBottomSheet<_PendingOrderEditResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _PendingOrderEditSheet(order: widget.order),
    );

    if (result == null || !mounted) {
      return;
    }

    setState(() {
      _busy = true;
    });

    try {
      await ref
          .read(managerOrdersRepositoryProvider)
          .updatePending(
            orderId: widget.order.id,
            category: result.category,
            itemText: result.itemText,
            requestedQuantity: result.requestedQuantity,
            suggestedCompanyText: result.suggestedCompanyText,
            notes: result.notes,
          );

      ref.invalidate(managerOrdersProvider);
    } on ApiHttpException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        await widget.onSessionInvalid();
        return;
      }

      _showMutationError(error.message);
    } catch (_) {
      _showMutationError('ویرایش درخواست انجام نشد.');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _cancel() async {
    if (_busy) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('لغو درخواست'),
          content: Text(
            '«${widget.order.itemText}» لغو شود؟',
            textAlign: TextAlign.right,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('خیر'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('لغو شود'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _busy = true;
    });

    try {
      await ref
          .read(managerOrdersRepositoryProvider)
          .cancel(orderId: widget.order.id);

      ref.invalidate(managerOrdersProvider);
    } on ApiHttpException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        await widget.onSessionInvalid();
        return;
      }

      _showMutationError(error.message);
    } catch (_) {
      _showMutationError('لغو درخواست انجام نشد.');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  void _showMutationError(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(duration: const Duration(seconds: 2), content: Text(message)),
      );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final quantity = widget.order.requestedQuantity;
    final quantityText = quantity == null
        ? '—'
        : _toPersianDigits(quantity.toString());
    final suggestedCompanyText = widget.order.suggestedCompanyText?.trim();
    final notes = widget.order.notes?.trim();

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onDoubleTap: _busy ? null : _assign,
      child: Container(
        margin: const EdgeInsets.only(bottom: 3),
        padding: const EdgeInsets.fromLTRB(4, 3, 5, 3),
        decoration: BoxDecoration(
          color: colors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 25,
              child: Row(
                children: [
                  SizedBox(
                    width: 27,
                    child: _busy
                        ? const Padding(
                            padding: EdgeInsets.all(5),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Checkbox(
                            value: false,
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            onChanged: (value) {
                              if (value == true) {
                                _assign();
                              }
                            },
                          ),
                  ),
                  _DenseRowAction(
                    tooltip: 'جزئیات',
                    icon: Icons.more_horiz,
                    onPressed: _busy ? null : _openDetails,
                  ),
                  const SizedBox(width: 1),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: widget.order.itemText,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                            ),
                          ),
                          if (suggestedCompanyText != null &&
                              suggestedCompanyText.isNotEmpty)
                            TextSpan(
                              text: '  $suggestedCompanyText',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colors.onSurfaceVariant,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (widget.order.possibleDuplicate) ...[
                    const SizedBox(width: 2),
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 14,
                      color: colors.error,
                    ),
                  ],
                  const SizedBox(width: 3),
                  Text(
                    quantityText,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 3),
                  _MiniCategoryBadge(category: widget.order.category),
                  const SizedBox(width: 1),
                  _DenseRowAction(
                    tooltip: 'ویرایش',
                    icon: Icons.edit_outlined,
                    onPressed: _busy ? null : _edit,
                  ),
                  _DenseRowAction(
                    tooltip: 'لغو',
                    icon: Icons.close_rounded,
                    foregroundColor: colors.error,
                    onPressed: _busy ? null : _cancel,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            SizedBox(
              height: 30,
              child: Row(
                children: [
                  SizedBox(
                    width: 56,
                    child: Text(
                      widget.order.requestedByName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontSize: 9.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 3),
                  Expanded(
                    child: Autocomplete<_AssignableCompany>(
                      displayStringForOption: (company) => company.name,
                      optionsMaxHeight: 220,
                      optionsBuilder: (textEditingValue) {
                        if (widget.companiesLoading || widget.companiesError) {
                          return const <_AssignableCompany>[];
                        }

                        return _optionsFor(textEditingValue.text);
                      },
                      onSelected: (company) {
                        setState(() {
                          _selectedCompany = company;
                        });
                      },
                      fieldViewBuilder:
                          (
                            context,
                            textController,
                            focusNode,
                            onFieldSubmitted,
                          ) {
                            return TextField(
                              controller: textController,
                              focusNode: focusNode,
                              enabled: !_busy,
                              style: const TextStyle(fontSize: 11.5),
                              maxLines: 1,
                              onTapAlwaysCalled: true,
                              onTap: () {
                                if (!widget.companiesLoading &&
                                    !widget.companiesError) {
                                  _handleCompanyFieldTap(textController);
                                }
                              },
                              onTapOutside: (_) {
                                _selectFirstVisibleCompanyAndClose(
                                  textController,
                                  focusNode,
                                );
                              },
                              onChanged: (value) {
                                final selected = _selectedCompany;

                                if (selected != null &&
                                    value.trim() != selected.name) {
                                  setState(() {
                                    _selectedCompany = null;
                                  });
                                }
                              },
                              decoration: InputDecoration(
                                isDense: true,
                                hintText: widget.companiesLoading
                                    ? 'در حال بارگذاری شرکت‌ها...'
                                    : widget.companiesError
                                    ? 'خطا در شرکت‌ها'
                                    : 'شرکت پخش',
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 6,
                                ),
                                border: const OutlineInputBorder(),
                                suffixIconConstraints:
                                    const BoxConstraints.tightFor(
                                      width: 28,
                                      height: 28,
                                    ),
                                suffixIcon: widget.companiesLoading
                                    ? const Padding(
                                        padding: EdgeInsets.all(7),
                                        child: CircularProgressIndicator(
                                          strokeWidth: 1.7,
                                        ),
                                      )
                                    : widget.companiesError
                                    ? IconButton(
                                        tooltip: 'تلاش مجدد',
                                        padding: EdgeInsets.zero,
                                        onPressed: widget.onRetryCompanies,
                                        icon: const Icon(
                                          Icons.refresh,
                                          size: 17,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.arrow_drop_down,
                                        size: 18,
                                      ),
                              ),
                            );
                          },
                    ),
                  ),
                ],
              ),
            ),
            if (notes != null && notes.isNotEmpty) ...[
              const SizedBox(height: 2),
              Row(
                children: [
                  const SizedBox(width: 59),
                  Expanded(
                    child: Text(
                      notes,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DenseRowAction extends StatelessWidget {
  const _DenseRowAction({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.foregroundColor,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 25,
      height: 25,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        color: foregroundColor,
        icon: Icon(icon, size: 16),
      ),
    );
  }
}

class _PendingOrderEditResult {
  const _PendingOrderEditResult({
    required this.category,
    required this.itemText,
    required this.requestedQuantity,
    required this.suggestedCompanyText,
    required this.notes,
  });

  final String category;
  final String itemText;
  final int? requestedQuantity;
  final String? suggestedCompanyText;
  final String? notes;
}

class _PendingOrderEditSheet extends StatefulWidget {
  const _PendingOrderEditSheet({required this.order});

  final ManagerOrder order;

  @override
  State<_PendingOrderEditSheet> createState() => _PendingOrderEditSheetState();
}

class _PendingOrderEditSheetState extends State<_PendingOrderEditSheet> {
  late final TextEditingController _itemController;
  late final TextEditingController _quantityController;
  late final TextEditingController _suggestedCompanyController;
  late final TextEditingController _notesController;

  late String _category;
  String? _error;

  @override
  void initState() {
    super.initState();

    _category = widget.order.category;
    _itemController = TextEditingController(text: widget.order.itemText);
    _quantityController = TextEditingController(
      text: widget.order.requestedQuantity?.toString() ?? '',
    );
    _suggestedCompanyController = TextEditingController(
      text: widget.order.suggestedCompanyText ?? '',
    );
    _notesController = TextEditingController(text: widget.order.notes ?? '');
  }

  @override
  void dispose() {
    _itemController.dispose();
    _quantityController.dispose();
    _suggestedCompanyController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _submit() {
    final itemText = _itemController.text.trim();

    if (itemText.isEmpty || itemText.length > 300) {
      setState(() {
        _error = 'نام قلم باید بین ۱ تا ۳۰۰ کاراکتر باشد.';
      });
      return;
    }

    final quantityText = _quantityController.text.trim();
    int? quantity;

    if (quantityText.isNotEmpty) {
      quantity = int.tryParse(_toEnglishDigits(quantityText));

      if (quantity == null || quantity < 1 || quantity > 1000000) {
        setState(() {
          _error = 'تعداد واردشده معتبر نیست.';
        });
        return;
      }
    }

    final suggestedCompany = _suggestedCompanyController.text.trim();
    final notes = _notesController.text.trim();

    if (suggestedCompany.length > 200) {
      setState(() {
        _error = 'شرکت پیشنهادی بیش از حد طولانی است.';
      });
      return;
    }

    if (notes.length > 1000) {
      setState(() {
        _error = 'یادداشت بیش از حد طولانی است.';
      });
      return;
    }

    Navigator.of(context).pop(
      _PendingOrderEditResult(
        category: _category,
        itemText: itemText,
        requestedQuantity: quantity,
        suggestedCompanyText: suggestedCompany.isEmpty
            ? null
            : suggestedCompany,
        notes: notes.isEmpty ? null : notes,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(14, 12, 14, 12 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'ویرایش درخواست',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _itemController,
              autofocus: true,
              maxLength: 300,
              decoration: const InputDecoration(
                isDense: true,
                labelText: 'قلم',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 7),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _category,
                    isDense: true,
                    decoration: const InputDecoration(
                      labelText: 'دسته',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'DRUG', child: Text('دارو')),
                      DropdownMenuItem(value: 'GOODS', child: Text('کالا')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _category = value;
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: TextField(
                    controller: _quantityController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      isDense: true,
                      labelText: 'تعداد',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            TextField(
              controller: _suggestedCompanyController,
              maxLength: 200,
              decoration: const InputDecoration(
                isDense: true,
                labelText: 'شرکت پیشنهادی',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 7),
            TextField(
              controller: _notesController,
              maxLength: 1000,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(
                isDense: true,
                labelText: 'یادداشت',
                border: OutlineInputBorder(),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 5),
              Text(
                _error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.save_outlined),
              label: const Text('ذخیره تغییرات'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DenseReadOnlyOrderRow extends ConsumerStatefulWidget {
  const _DenseReadOnlyOrderRow({
    required this.order,
    required this.onSessionInvalid,
    super.key,
  });

  final ManagerOrder order;
  final Future<void> Function() onSessionInvalid;

  @override
  ConsumerState<_DenseReadOnlyOrderRow> createState() =>
      _DenseReadOnlyOrderRowState();
}

class _DenseReadOnlyOrderRowState
    extends ConsumerState<_DenseReadOnlyOrderRow> {
  bool _busy = false;

  Future<void> _openDetails() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => OrderDetailsPage(
          orderId: widget.order.id,
          repository: ref.read(managerOrdersRepositoryProvider),
        ),
      ),
    );
  }

  Future<void> _returnToPending() async {
    if (_busy || widget.order.status != 'ORDERED') {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('بازگشت به در انتظار'),
          content: Text(
            '«${widget.order.itemText}» از حالت سفارش‌شده به در انتظار برگردد؟\n\n'
            'شرکت نهایی و اطلاعات ثبت سفارش پاک می‌شود. سپس می‌توانید درخواست را ویرایش کنید یا دوباره به یک شرکت بدهید.',
            textAlign: TextAlign.right,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('انصراف'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              icon: const Icon(Icons.undo_rounded),
              label: const Text('بازگردانی'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _busy = true;
    });

    try {
      await ref
          .read(managerOrdersRepositoryProvider)
          .returnToPending(orderId: widget.order.id);

      ref.invalidate(managerOrdersProvider);

      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              duration: Duration(seconds: 2),
              content: Text('سفارش به فهرست در انتظار برگشت.'),
            ),
          );
      }
    } on ApiHttpException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        await widget.onSessionInvalid();
        return;
      }

      _showMutationError(error.message);
    } catch (_) {
      _showMutationError('بازگردانی سفارش انجام نشد. دوباره تلاش کنید.');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  void _showMutationError(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(duration: const Duration(seconds: 2), content: Text(message)),
      );
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final quantity = order.orderedQuantity ?? order.requestedQuantity;
    final quantityText = quantity == null
        ? '—'
        : _toPersianDigits(quantity.toString());
    final companyText = order.assignedCompanyName ?? '—';

    return Container(
      height: 38,
      margin: const EdgeInsets.only(bottom: 3),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        children: [
          _MiniCategoryBadge(category: order.category),
          const SizedBox(width: 2),
          _DenseRowAction(
            tooltip: 'جزئیات',
            icon: Icons.more_horiz,
            onPressed: _busy ? null : _openDetails,
          ),
          const SizedBox(width: 2),
          if (order.status == 'ORDERED') ...[
            _DenseRowAction(
              tooltip: 'بازگشت به در انتظار',
              icon: Icons.undo_rounded,
              foregroundColor: colors.primary,
              onPressed: _busy ? null : _returnToPending,
            ),
            const SizedBox(width: 2),
          ],
          Expanded(
            child: Text(
              order.itemText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 5),
          Text(
            quantityText,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 7),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 112),
            child: Text(
              companyText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colors.onSurfaceVariant,
                fontSize: 9.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniCategoryBadge extends StatelessWidget {
  const _MiniCategoryBadge({required this.category});

  final String category;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDrug = category == 'DRUG';

    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        isDrug ? 'د' : 'ک',
        style: TextStyle(
          color: colors.onSurfaceVariant,
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

bool _isShortage(ManagerOrder order, int shortageDays) {
  if (order.status != 'PENDING') {
    return false;
  }

  return DateTime.now().difference(order.createdAt.toLocal()).inDays >
      shortageDays;
}

bool _matchesOrderSearch(ManagerOrder order, String rawQuery) {
  final query = _normalizeOrderSearch(rawQuery);

  if (query.isEmpty) {
    return true;
  }

  final haystack = _normalizeOrderSearch(
    <String>[
      order.itemText,
      order.requestedByName,
      order.suggestedCompanyText ?? '',
      order.notes ?? '',
      order.assignedCompanyName ?? '',
      order.requestedQuantity?.toString() ?? '',
      order.orderedQuantity?.toString() ?? '',
    ].join(' '),
  );

  return haystack.contains(query);
}

String _normalizeOrderSearch(String value) {
  const english = '0123456789';
  const persian = '۰۱۲۳۴۵۶۷۸۹';
  const arabic = '٠١٢٣٤٥٦٧٨٩';

  var output = value
      .trim()
      .toLowerCase()
      .replaceAll('ي', 'ی')
      .replaceAll('ك', 'ک')
      .replaceAll('\u200c', ' ');

  for (var index = 0; index < english.length; index++) {
    output = output
        .replaceAll(persian[index], english[index])
        .replaceAll(arabic[index], english[index]);
  }

  return output.replaceAll(RegExp(r'\s+'), ' ');
}

String _toEnglishDigits(String value) {
  const english = '0123456789';
  const persian = '۰۱۲۳۴۵۶۷۸۹';
  const arabic = '٠١٢٣٤٥٦٧٨٩';

  var output = value;

  for (var index = 0; index < english.length; index++) {
    output = output
        .replaceAll(persian[index], english[index])
        .replaceAll(arabic[index], english[index]);
  }

  return output;
}

String _toPersianDigits(String value) {
  const english = '0123456789';
  const persian = '۰۱۲۳۴۵۶۷۸۹';

  var output = value;

  for (var index = 0; index < english.length; index++) {
    output = output.replaceAll(english[index], persian[index]);
  }

  return output;
}
