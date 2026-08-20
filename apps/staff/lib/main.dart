import 'dart:async';

import 'package:flutter/material.dart';

import 'core/auth/staff_auth_api_service.dart';
import 'core/auth/staff_auth_session.dart';
import 'core/auth/staff_auth_token_storage.dart';
import 'core/auth/staff_auth_user.dart';
import 'core/navigation/staff_back_navigation_scope.dart';
import 'core/update/staff_app_version.dart';
import 'core/update/staff_update_runner.dart';
import 'features/orders/presentation/staff_order_form_page.dart';
import 'features/orders/presentation/staff_orders_dashboard.dart';
import 'core/auth/staff_login_page.dart';

void main() {
  runApp(const PharmaFlowStaffApp());
}

class PharmaFlowStaffApp extends StatelessWidget {
  const PharmaFlowStaffApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PharmaFlow Staff',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF176B5B),
      ),
      home: const StaffAuthGate(),
    );
  }
}

class StaffAuthGate extends StatefulWidget {
  const StaffAuthGate({super.key});

  @override
  State<StaffAuthGate> createState() => _StaffAuthGateState();
}

class _StaffAuthGateState extends State<StaffAuthGate> {
  final _storage = StaffAuthTokenStorage();

  StaffAuthSession? _session;
  bool _loading = true;

  @override
  void initState() {
    super.initState();

    unawaited(_restore());
  }

  Future<void> _restore() async {
    StaffAuthSession? session;

    try {
      session = await _storage.load();
    } catch (_) {
      // A blocked/corrupted browser storage must not leave the app on a
      // permanent loading screen. The login page remains the safe fallback.
      session = null;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _session = session;
      _loading = false;
    });

    if (session != null) {
      unawaited(_verifyInBackground());
    }
  }

  Future<void> _verifyInBackground() async {
    final service = StaffAuthApiService(storage: _storage);

    try {
      final user = await service.me();

      if (!mounted) {
        return;
      }

      final current = _session;

      if (current == null) {
        return;
      }

      final refreshed = StaffAuthSession(
        token: current.token,
        user: user,
        expiresAt: current.expiresAt,
      );

      await _storage.save(refreshed);

      if (!mounted) {
        return;
      }

      setState(() {
        _session = refreshed;
      });
    } on StaffAuthApiException catch (error) {
      if (error.statusCode == 401) {
        await _storage.clear();

        if (!mounted) {
          return;
        }

        setState(() {
          _session = null;
        });
      }
    } catch (_) {
      // Keep the locally stored session while offline.
      // The backend remains the source of truth for protected requests.
    } finally {
      service.close();
    }
  }

  void _onAuthenticated(StaffAuthSession session) {
    setState(() {
      _session = session;
    });
  }

  Future<void> _logout() async {
    final service = StaffAuthApiService(storage: _storage);

    try {
      await service.logout();
    } catch (_) {
      await _storage.clear();
    } finally {
      service.close();
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _session = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    final session = _session;

    if (session == null) {
      return StaffLoginPage(onAuthenticated: _onAuthenticated);
    }

    return StaffHomePage(user: session.user, onLogout: _logout);
  }
}

class StaffHomePage extends StatefulWidget {
  const StaffHomePage({super.key, required this.user, required this.onLogout});

  final StaffAuthUser user;
  final Future<void> Function() onLogout;

  @override
  State<StaffHomePage> createState() => _StaffHomePageState();
}

class _StaffHomePageState extends State<StaffHomePage> {
  final _dashboardKey = GlobalKey<StaffOrdersDashboardState>();
  final _updateRunner = StaffUpdateRunner();

  bool _checking = false;
  bool _downloading = false;
  bool _loggingOut = false;
  double? _progress;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();

    if (_updateRunner.isSupported) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_checkForUpdate(silent: true));
      });
    }
  }

  @override
  void dispose() {
    _updateRunner.close();
    super.dispose();
  }

  void _selectPage(int index) {
    if (_selectedIndex == index) {
      if (index == 0) {
        unawaited(
          _dashboardKey.currentState?.refresh() ?? Future<void>.value(),
        );
      }
      return;
    }

    setState(() {
      _selectedIndex = index;
    });
  }

  void _onOrderCreated() {
    unawaited(
      _dashboardKey.currentState?.refresh(silent: true) ?? Future<void>.value(),
    );
  }

  Future<void> _logout() async {
    if (_loggingOut) {
      return;
    }

    setState(() {
      _loggingOut = true;
    });

    try {
      await widget.onLogout();
    } finally {
      if (mounted) {
        setState(() {
          _loggingOut = false;
        });
      }
    }
  }

  Future<void> _checkForUpdate({required bool silent}) async {
    if (!_updateRunner.isSupported || _checking || _downloading) {
      return;
    }

    setState(() {
      _checking = true;
    });

    try {
      final manifest = await _updateRunner.check();

      if (!mounted) {
        return;
      }

      if (!manifest.updateAvailableFor(StaffAppVersion.versionCode)) {
        if (!silent) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('نسخه نصب‌شده آخرین نسخه موجود است.')),
          );
        }

        return;
      }

      final versionName = manifest.latestVersionName ?? 'نسخه جدید';

      final mandatory = manifest.isMandatoryFor(StaffAppVersion.versionCode);

      final accepted = await showDialog<bool>(
        context: context,
        barrierDismissible: !mandatory,
        builder: (dialogContext) {
          return PopScope(
            canPop: !mandatory,
            child: AlertDialog(
              title: const Text('بروزرسانی PharmaFlow Staff'),
              content: Text(
                'نسخه $versionName آماده نصب است.'
                '${manifest.releaseNotes == null ? '' : '\n\n${manifest.releaseNotes}'}',
              ),
              actions: [
                if (!mandatory)
                  TextButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop(false);
                    },
                    child: const Text('بعداً'),
                  ),
                FilledButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop(true);
                  },
                  child: const Text('دانلود و نصب'),
                ),
              ],
            ),
          );
        },
      );

      if (accepted != true || !mounted) {
        return;
      }

      setState(() {
        _downloading = true;
        _progress = 0;
      });

      await _updateRunner.downloadAndInstall(
        manifest: manifest,
        onProgress: (value) {
          if (!mounted) {
            return;
          }

          setState(() {
            _progress = value;
          });
        },
      );
    } catch (error) {
      if (!mounted || silent) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خطا در بروزرسانی: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _checking = false;
          _downloading = false;
          _progress = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      SafeArea(
        bottom: false,
        child: StaffOrdersDashboard(key: _dashboardKey, user: widget.user),
      ),
      StaffOrderFormPage(embedded: true, onOrderCreated: _onOrderCreated),
    ];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: StaffBackNavigationScope(
        isHome: _selectedIndex == 0,
        onReturnHome: () => _selectPage(0),
        child: Scaffold(
          appBar: _selectedIndex == 0
              ? null
              : AppBar(
                  centerTitle: true,
                  title: const Text('ثبت درخواست جدید'),
                ),
          body: IndexedStack(index: _selectedIndex, children: pages),
          bottomNavigationBar: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_downloading)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 4, 18, 0),
                    child: Column(
                      children: [
                        LinearProgressIndicator(value: _progress),
                        const SizedBox(height: 4),
                        Text(
                          _progress == null
                              ? 'در حال دانلود بروزرسانی...'
                              : 'دانلود ${(100 * _progress!).round()}٪',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                _StaffBottomMenu(
                  selectedIndex: _selectedIndex,
                  showUpdate: _updateRunner.isSupported,
                  checkingUpdate: _checking || _downloading,
                  loggingOut: _loggingOut,
                  onSelect: _selectPage,
                  onUpdate: () => _checkForUpdate(silent: false),
                  onLogout: _logout,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StaffBottomMenu extends StatelessWidget {
  const _StaffBottomMenu({
    required this.selectedIndex,
    required this.showUpdate,
    required this.checkingUpdate,
    required this.loggingOut,
    required this.onSelect,
    required this.onUpdate,
    required this.onLogout,
  });

  final int selectedIndex;
  final bool showUpdate;
  final bool checkingUpdate;
  final bool loggingOut;
  final ValueChanged<int> onSelect;
  final VoidCallback onUpdate;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const ValueKey('staff-persistent-bottom-menu'),
      elevation: 5,
      margin: const EdgeInsets.fromLTRB(10, 6, 10, 8),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
        child: Row(
          children: [
            _StaffMenuButton(
              icon: Icons.home_outlined,
              selectedIcon: Icons.home,
              label: 'خانه',
              selected: selectedIndex == 0,
              onTap: () => onSelect(0),
            ),
            _StaffMenuButton(
              icon: Icons.add_shopping_cart_outlined,
              selectedIcon: Icons.add_shopping_cart,
              label: 'ثبت درخواست',
              selected: selectedIndex == 1,
              onTap: () => onSelect(1),
            ),
            if (showUpdate)
              _StaffMenuButton(
                icon: Icons.system_update_alt_outlined,
                selectedIcon: Icons.system_update_alt,
                label: checkingUpdate ? 'در حال بررسی' : 'بروزرسانی',
                selected: false,
                onTap: checkingUpdate ? null : onUpdate,
              ),
            _StaffMenuButton(
              icon: Icons.logout_outlined,
              selectedIcon: Icons.logout,
              label: loggingOut ? 'در حال خروج' : 'خروج',
              selected: false,
              onTap: loggingOut ? null : onLogout,
            ),
          ],
        ),
      ),
    );
  }
}

class _StaffMenuButton extends StatelessWidget {
  const _StaffMenuButton({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 7),
          decoration: BoxDecoration(
            color: selected
                ? colors.primaryContainer.withValues(alpha: 0.72)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected ? selectedIcon : icon,
                size: 23,
                color: onTap == null
                    ? colors.onSurface.withValues(alpha: 0.35)
                    : selected
                    ? colors.primary
                    : colors.onSurfaceVariant,
              ),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: onTap == null
                      ? colors.onSurface.withValues(alpha: 0.35)
                      : selected
                      ? colors.primary
                      : colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
