import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/orders/data/manager_orders_auth_service.dart';
import '../../features/settings/presentation/providers/communication_settings_provider.dart';
import '../notifications/manager_push_device_registration_service.dart';
import 'auth_provider.dart';

enum ManagerAppPermission { financialReports }

class ManagerAccessScope extends InheritedWidget {
  const ManagerAccessScope({
    required this.user,
    required super.child,
    super.key,
  });

  final ManagerOrdersAuthUser user;

  static ManagerAccessScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ManagerAccessScope>();
  }

  static ManagerAccessScope of(BuildContext context) {
    final scope = maybeOf(context);

    assert(
      scope != null,
      'ManagerAccessScope was not found in the widget tree.',
    );

    return scope!;
  }

  bool allows(ManagerAppPermission permission) {
    return switch (permission) {
      ManagerAppPermission.financialReports =>
        user.permissions.canViewFinancialReports,
    };
  }

  @override
  bool updateShouldNotify(ManagerAccessScope oldWidget) {
    return oldWidget.user != user;
  }
}

class ManagerPermissionGate extends StatelessWidget {
  const ManagerPermissionGate({
    required this.permission,
    required this.child,
    super.key,
  });

  final ManagerAppPermission permission;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scope = ManagerAccessScope.maybeOf(context);

    if (scope == null || scope.allows(permission)) {
      return child;
    }

    return const _ManagerAccessDeniedPage(
      message: 'برای مشاهده این بخش دسترسی ندارید.',
    );
  }
}

class ManagerAppAuthGate extends ConsumerStatefulWidget {
  const ManagerAppAuthGate({required this.childBuilder, super.key});

  final Widget Function(BuildContext context, ManagerOrdersAuthUser user)
  childBuilder;

  @override
  ConsumerState<ManagerAppAuthGate> createState() => _ManagerAppAuthGateState();
}

enum _ManagerAppAuthPhase { loading, unauthenticated, authenticated }

class _ManagerAppAuthGateState extends ConsumerState<ManagerAppAuthGate> {
  _ManagerAppAuthPhase _phase = _ManagerAppAuthPhase.loading;
  ManagerOrdersAuthUser? _user;
  String? _error;
  bool _working = false;

  ManagerOrdersAuthService _authService() {
    final apiClient = ref.read(apiClientProvider);

    return ManagerOrdersAuthService(
      apiClient: apiClient,
      tokenStorage: ref.read(authTokenStorageProvider),
      pushDevices: ManagerPushDeviceRegistrationService(apiClient: apiClient),
    );
  }

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_bootstrap);
  }

  Future<void> _bootstrap() async {
    try {
      final hasToken = await ref.read(authTokenStorageProvider).hasToken();

      if (!hasToken) {
        if (mounted) {
          setState(() {
            _phase = _ManagerAppAuthPhase.unauthenticated;
          });
        }

        return;
      }

      final user = await _authService().me();

      if (!mounted) {
        return;
      }

      setState(() {
        _user = user;
        _error = null;
        _phase = _ManagerAppAuthPhase.authenticated;
      });

      unawaited(ref.read(syncServiceProvider).syncNow());
    } catch (_) {
      await _authService().clearLocalSession();

      if (!mounted) {
        return;
      }

      setState(() {
        _user = null;
        _error = 'نشست قبلی معتبر نیست. دوباره وارد شوید.';
        _phase = _ManagerAppAuthPhase.unauthenticated;
      });
    }
  }

  Future<bool> _login({
    required String username,
    required String password,
  }) async {
    if (_working) {
      return false;
    }

    setState(() {
      _working = true;
      _error = null;
    });

    try {
      final user = await _authService().login(
        username: username,
        password: password,
      );

      await ref.read(authStateProvider.notifier).refresh();
      unawaited(ref.read(syncServiceProvider).syncNow());

      if (!mounted) {
        return false;
      }

      setState(() {
        _user = user;
        _phase = _ManagerAppAuthPhase.authenticated;
      });
      return true;
    } on ManagerOrdersAuthException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
        });
      }
      return false;
    } catch (_) {
      if (mounted) {
        setState(() {
          _error =
              'ورود انجام نشد. نام کاربری، رمز و اتصال اینترنت را بررسی کنید.';
        });
      }
      return false;
    } finally {
      if (mounted) {
        setState(() {
          _working = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return switch (_phase) {
      _ManagerAppAuthPhase.loading => const Material(
        child: Center(child: CircularProgressIndicator()),
      ),
      _ManagerAppAuthPhase.unauthenticated => _ManagerAppLoginView(
        working: _working,
        error: _error,
        onLogin: _login,
      ),
      _ManagerAppAuthPhase.authenticated => ManagerAccessScope(
        user: _user!,
        child: widget.childBuilder(context, _user!),
      ),
    };
  }
}

class _ManagerAppLoginView extends StatefulWidget {
  const _ManagerAppLoginView({
    required this.working,
    required this.error,
    required this.onLogin,
  });

  final bool working;
  final String? error;
  final Future<bool> Function({
    required String username,
    required String password,
  })
  onLogin;

  @override
  State<_ManagerAppLoginView> createState() => _ManagerAppLoginViewState();
}

class _ManagerAppLoginViewState extends State<_ManagerAppLoginView> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _passwordFieldKey = GlobalKey();

  bool _passwordVisible = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _usernameFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      return;
    }

    FocusScope.of(context).unfocus();
    final succeeded = await widget.onLogin(
      username: username,
      password: password,
    );

    if (!mounted || succeeded) {
      return;
    }

    // Some Android keyboards keep the old composing region after a failed
    // secure-field submission. Replacing the complete editing value prevents
    // the previous password from being appended as hidden characters.
    _passwordController.value = TextEditingValue.empty;
    _passwordFocusNode.requestFocus();
    _ensurePasswordFieldVisible();
  }

  void _ensurePasswordFieldVisible() {
    final fieldContext = _passwordFieldKey.currentContext;
    if (fieldContext == null) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_passwordFocusNode.hasFocus) {
        return;
      }

      Scrollable.ensureVisible(
        fieldContext,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        alignment: 0.45,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + keyboardHeight),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.local_pharmacy_outlined, size: 52),
                        const SizedBox(height: 12),
                        Text(
                          'ورود به PharmaFlow Manager',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: _usernameController,
                          focusNode: _usernameFocusNode,
                          enabled: !widget.working,
                          textInputAction: TextInputAction.next,
                          autofillHints: const <String>[AutofillHints.username],
                          onSubmitted: (_) {
                            _passwordFocusNode.requestFocus();
                            _ensurePasswordFieldVisible();
                          },
                          decoration: const InputDecoration(
                            labelText: 'نام کاربری',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          key: _passwordFieldKey,
                          controller: _passwordController,
                          focusNode: _passwordFocusNode,
                          enabled: !widget.working,
                          obscureText: !_passwordVisible,
                          enableSuggestions: false,
                          autocorrect: false,
                          textInputAction: TextInputAction.done,
                          autofillHints: const <String>[AutofillHints.password],
                          onTap: _ensurePasswordFieldVisible,
                          onSubmitted: (_) => _submit(),
                          decoration: InputDecoration(
                            labelText: 'رمز عبور',
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              tooltip: _passwordVisible
                                  ? 'مخفی کردن رمز'
                                  : 'نمایش رمز',
                              onPressed: () {
                                setState(() {
                                  _passwordVisible = !_passwordVisible;
                                });
                              },
                              icon: Icon(
                                _passwordVisible
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                            ),
                          ),
                        ),
                        if (widget.error != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            widget.error!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: widget.working ? null : _submit,
                            icon: widget.working
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.login),
                            label: const Text('ورود'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ManagerAccessDeniedPage extends StatelessWidget {
  const _ManagerAccessDeniedPage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('دسترسی محدود')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(message, textAlign: TextAlign.center),
          ),
        ),
      ),
    );
  }
}
