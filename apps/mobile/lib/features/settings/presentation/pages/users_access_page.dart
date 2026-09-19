import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../data/manager_users_access_service.dart';
import '../providers/communication_settings_provider.dart';

class UsersAccessPage extends ConsumerStatefulWidget {
  const UsersAccessPage({super.key});

  @override
  ConsumerState<UsersAccessPage> createState() => _UsersAccessPageState();
}

class _UsersAccessPageState extends ConsumerState<UsersAccessPage> {
  List<ManagedAppUser> _users = const <ManagedAppUser>[];
  ManagedAppUser? _currentUser;
  bool _loading = true;
  bool _working = false;
  String? _error;

  ManagerUsersAccessService get _service {
    return ManagerUsersAccessService(apiClient: ref.read(apiClientProvider));
  }

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final results = await Future.wait<dynamic>(<Future<dynamic>>[
        _service.listUsers(),
        _service.me(),
      ]);

      if (!mounted) {
        return;
      }

      setState(() {
        _users = results[0] as List<ManagedAppUser>;
        _currentUser = results[1] as ManagedAppUser;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _error = _messageForError(error);
      });
    }
  }

  Future<void> _runMutation(Future<void> Function() operation) async {
    if (_working) {
      return;
    }

    setState(() {
      _working = true;
    });

    try {
      await operation();
      await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_messageForError(error))));
      }
    } finally {
      if (mounted) {
        setState(() {
          _working = false;
        });
      }
    }
  }

  Future<void> _createUser() async {
    final usernameController = TextEditingController();
    final displayNameController = TextEditingController();
    final passwordController = TextEditingController();

    var role = 'STAFF';
    var permissions = ManagerUserPermissions.staffDefaults;

    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final effectivePermissions = role == 'MANAGER'
                ? ManagerUserPermissions.managerFull
                : permissions;

            return AlertDialog(
              title: const Text('کاربر جدید'),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 420,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: displayNameController,
                        textAlign: TextAlign.right,
                        decoration: const InputDecoration(
                          labelText: 'نام نمایشی',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: usernameController,
                        textAlign: TextAlign.left,
                        decoration: const InputDecoration(
                          labelText: 'نام کاربری',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: passwordController,
                        obscureText: true,
                        textAlign: TextAlign.left,
                        decoration: const InputDecoration(
                          labelText: 'رمز عبور',
                          helperText: 'حداقل ۶ کاراکتر',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: role,
                        decoration: const InputDecoration(
                          labelText: 'نقش',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'STAFF',
                            child: Text('کارمند'),
                          ),
                          DropdownMenuItem(
                            value: 'MANAGER',
                            child: Text('مدیر'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }

                          setDialogState(() {
                            role = value;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      _PermissionsEditor(
                        enabled: role != 'MANAGER',
                        permissions: effectivePermissions,
                        onChanged: (value) {
                          setDialogState(() {
                            permissions = value;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('انصراف'),
                ),
                FilledButton(
                  onPressed: () {
                    if (displayNameController.text.trim().isEmpty ||
                        usernameController.text.trim().length < 3 ||
                        passwordController.text.length < 6) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(
                          content: Text('اطلاعات کاربر را کامل وارد کنید.'),
                        ),
                      );
                      return;
                    }

                    Navigator.pop(dialogContext, true);
                  },
                  child: const Text('ایجاد کاربر'),
                ),
              ],
            );
          },
        );
      },
    );

    if (submitted != true) {
      usernameController.dispose();
      displayNameController.dispose();
      passwordController.dispose();
      return;
    }

    final finalPermissions = role == 'MANAGER'
        ? ManagerUserPermissions.managerFull
        : permissions;

    await _runMutation(() async {
      await _service.createUser(
        username: usernameController.text,
        displayName: displayNameController.text,
        password: passwordController.text,
        role: role,
        permissions: finalPermissions,
      );
    });

    usernameController.dispose();
    displayNameController.dispose();
    passwordController.dispose();
  }

  Future<void> _editPermissions(ManagedAppUser user) async {
    if (user.isManager) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('مدیر همیشه دسترسی کامل دارد.')),
      );
      return;
    }

    var permissions = user.permissions;

    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('دسترسی‌های ${user.displayName}'),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 420,
                  child: _PermissionsEditor(
                    enabled: true,
                    permissions: permissions,
                    onChanged: (value) {
                      setDialogState(() {
                        permissions = value;
                      });
                    },
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('انصراف'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('ذخیره دسترسی‌ها'),
                ),
              ],
            );
          },
        );
      },
    );

    if (submitted != true) {
      return;
    }

    await _runMutation(() async {
      await _service.setPermissions(
        userId: user.userId,
        permissions: permissions,
      );
    });
  }

  Future<void> _resetPassword(ManagedAppUser user) async {
    final controller = TextEditingController();

    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('تغییر رمز ${user.displayName}'),
          content: TextField(
            controller: controller,
            obscureText: true,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'رمز جدید',
              helperText: 'حداقل ۶ کاراکتر؛ نشست‌های قبلی کاربر بسته می‌شوند.',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('انصراف'),
            ),
            FilledButton(
              onPressed: () {
                if (controller.text.length < 6) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text('رمز عبور باید حداقل ۶ کاراکتر باشد.'),
                    ),
                  );
                  return;
                }

                Navigator.pop(dialogContext, true);
              },
              child: const Text('تغییر رمز'),
            ),
          ],
        );
      },
    );

    if (submitted == true) {
      await _runMutation(() async {
        await _service.resetPassword(
          userId: user.userId,
          password: controller.text,
        );
      });
    }

    controller.dispose();
  }

  Future<void> _setActive(ManagedAppUser user, bool isActive) async {
    if (user.userId == _currentUser?.userId && !isActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'نمی‌توانید حسابی را که با آن وارد شده‌اید غیرفعال کنید.',
          ),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(isActive ? 'فعال کردن کاربر' : 'غیرفعال کردن کاربر'),
          content: Text(
            isActive
                ? 'حساب ${user.displayName} دوباره فعال شود؟'
                : 'حساب ${user.displayName} غیرفعال شود؟ نشست‌های فعال او نیز بسته می‌شوند.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('انصراف'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(isActive ? 'فعال شود' : 'غیرفعال شود'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await _runMutation(() async {
      await _service.setActive(userId: user.userId, isActive: isActive);
    });
  }

  Future<void> _showActivity(ManagedAppUser user) async {
    try {
      final items = await _service.listActivity(user.userId);

      if (!mounted) {
        return;
      }

      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (sheetContext) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: SafeArea(
              child: SizedBox(
                height: MediaQuery.sizeOf(sheetContext).height * 0.78,
                child: Column(
                  children: [
                    ListTile(
                      title: Text(
                        'سوابق ${user.displayName}',
                        style: Theme.of(sheetContext).textTheme.titleLarge,
                      ),
                      subtitle: const Text('حداکثر ۱۰۰ رویداد اخیر'),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: items.isEmpty
                          ? const Center(
                              child: Text(
                                'هنوز رویدادی برای این کاربر ثبت نشده است.',
                              ),
                            )
                          : ListView.separated(
                              itemCount: items.length,
                              separatorBuilder: (_, _) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final item = items[index];

                                return ListTile(
                                  dense: true,
                                  title: Text(_activityLabel(item.action)),
                                  subtitle: Text(
                                    '${item.entityType} • ${_formatDate(item.createdAt)}',
                                  ),
                                  trailing: item.actorDisplayName.isEmpty
                                      ? null
                                      : Text(item.actorDisplayName),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_messageForError(error))));
      }
    }
  }

  String _activityLabel(String action) {
    return switch (action) {
      'USER_CREATED' => 'ایجاد کاربر',
      'USER_ACTIVATED' => 'فعال کردن کاربر',
      'USER_DEACTIVATED' => 'غیرفعال کردن کاربر',
      'PASSWORD_RESET' => 'تغییر رمز عبور',
      'PERMISSIONS_UPDATED' => 'تغییر سطح دسترسی',
      'CREATE' => 'ثبت',
      'UPDATE' => 'ویرایش',
      'DELETE' => 'حذف',
      _ => action.isEmpty ? 'رویداد' : action,
    };
  }

  String _formatDate(DateTime? value) {
    if (value == null) {
      return '—';
    }

    final local = value.toLocal();
    final two = (int number) => number.toString().padLeft(2, '0');

    return '${local.year}/${two(local.month)}/${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  String _messageForError(Object error) {
    if (error is ApiHttpException) {
      if (error.statusCode == 409) {
        return 'این نام کاربری قبلاً ثبت شده است.';
      }

      if (error.statusCode == 401) {
        return 'نشست شما منقضی شده است. دوباره وارد شوید.';
      }

      if (error.statusCode == 403) {
        return 'این عملیات برای حساب فعلی مجاز نیست.';
      }

      return error.message;
    }

    return 'انجام عملیات با خطا مواجه شد.';
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('کاربران و دسترسی‌ها'),
          actions: [
            IconButton(
              tooltip: 'بروزرسانی',
              onPressed: _working ? null : _load,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _working ? null : _createUser,
          icon: const Icon(Icons.person_add_alt_1),
          label: const Text('کاربر جدید'),
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final error = _error;

    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(error, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('تلاش دوباره'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
        itemCount: _users.length,
        itemBuilder: (context, index) {
          final user = _users[index];
          final isCurrent = user.userId == _currentUser?.userId;

          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      child: Icon(
                        user.isManager
                            ? Icons.admin_panel_settings_outlined
                            : Icons.person_outline,
                      ),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            user.displayName,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (isCurrent)
                          const Chip(
                            visualDensity: VisualDensity.compact,
                            label: Text('شما'),
                          ),
                      ],
                    ),
                    subtitle: Text(
                      '${user.username} • ${user.isManager ? 'مدیر' : 'کارمند'}',
                    ),
                    trailing: Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text(user.isActive ? 'فعال' : 'غیرفعال'),
                    ),
                  ),
                  const Divider(),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _working
                            ? null
                            : () => _editPermissions(user),
                        icon: const Icon(Icons.shield_outlined),
                        label: const Text('دسترسی‌ها'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _working ? null : () => _resetPassword(user),
                        icon: const Icon(Icons.password_outlined),
                        label: const Text('رمز جدید'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _working ? null : () => _showActivity(user),
                        icon: const Icon(Icons.history_outlined),
                        label: const Text('سوابق'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: _working || (isCurrent && user.isActive)
                            ? null
                            : () => _setActive(user, !user.isActive),
                        icon: Icon(
                          user.isActive
                              ? Icons.person_off_outlined
                              : Icons.person_add_alt,
                        ),
                        label: Text(user.isActive ? 'غیرفعال' : 'فعال'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PermissionsEditor extends StatelessWidget {
  const _PermissionsEditor({
    required this.enabled,
    required this.permissions,
    required this.onChanged,
  });

  final bool enabled;
  final ManagerUserPermissions permissions;
  final ValueChanged<ManagerUserPermissions> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (!enabled)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              'حساب مدیر همیشه دسترسی کامل دارد.',
              textAlign: TextAlign.right,
            ),
          ),
        SwitchListTile(
          value: permissions.managerAppAccess,
          onChanged: enabled
              ? (value) =>
                    onChanged(permissions.copyWith(managerAppAccess: value))
              : null,
          title: const Text('ورود به اپ Manager'),
        ),
        SwitchListTile(
          value: permissions.canCreateOrders,
          onChanged: enabled
              ? (value) =>
                    onChanged(permissions.copyWith(canCreateOrders: value))
              : null,
          title: const Text('ثبت سفارش'),
        ),
        SwitchListTile(
          value: permissions.canCreateCheques,
          onChanged: enabled
              ? (value) =>
                    onChanged(permissions.copyWith(canCreateCheques: value))
              : null,
          title: const Text('ثبت و مدیریت چک'),
        ),
        SwitchListTile(
          value: permissions.canCreateCashPayments,
          onChanged: enabled
              ? (value) => onChanged(
                  permissions.copyWith(canCreateCashPayments: value),
                )
              : null,
          title: const Text('ثبت و مدیریت واریزی'),
        ),
        SwitchListTile(
          value: permissions.canViewFinancialReports,
          onChanged: enabled
              ? (value) => onChanged(
                  permissions.copyWith(canViewFinancialReports: value),
                )
              : null,
          title: const Text('مشاهده گزارش‌های مالی'),
        ),
      ],
    );
  }
}
