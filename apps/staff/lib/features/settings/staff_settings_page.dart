import 'package:flutter/material.dart';

import '../../core/auth/staff_auth_api_service.dart';
import '../../core/auth/staff_auth_user.dart';
import '../../core/pos/staff_pos_bridge.dart';
import '../../core/settings/staff_settings_api.dart';

class StaffSettingsPage extends StatefulWidget {
  const StaffSettingsPage({
    super.key,
    required this.user,
    required this.onUserUpdated,
  });

  final StaffAuthUser user;
  final ValueChanged<StaffAuthUser> onUserUpdated;

  @override
  State<StaffSettingsPage> createState() => _StaffSettingsPageState();
}

class _StaffSettingsPageState extends State<StaffSettingsPage> {
  final _authApi = StaffAuthApiService();
  final _settingsApi = StaffSettingsApi();
  late final TextEditingController _displayName;
  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _bridgeHost = TextEditingController();
  final _bridgePort = TextEditingController(text: '17905');

  List<StaffPosDevice> _devices = [];
  bool _loadingPos = true;
  bool _savingPos = false;
  bool _savingProfile = false;
  bool _savingPassword = false;
  String? _posError;

  @override
  void initState() {
    super.initState();
    _displayName = TextEditingController(text: widget.user.displayName);
    _loadPosSettings();
  }

  @override
  void dispose() {
    _authApi.close();
    _settingsApi.close();
    _displayName.dispose();
    _currentPassword.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    _bridgeHost.dispose();
    _bridgePort.dispose();
    super.dispose();
  }

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _loadPosSettings() async {
    setState(() {
      _loadingPos = true;
      _posError = null;
    });
    try {
      final settings = await _settingsApi.posSettings();
      if (!mounted) return;
      setState(() {
        _bridgeHost.text = settings.bridgeHost;
        _bridgePort.text = settings.bridgePort.toString();
        _devices = settings.devices.toList(growable: true);
      });
    } catch (error) {
      if (mounted) setState(() => _posError = '$error');
    } finally {
      if (mounted) setState(() => _loadingPos = false);
    }
  }

  Future<void> _saveProfile() async {
    final name = _displayName.text.trim();
    if (name.isEmpty || _savingProfile) return;
    setState(() => _savingProfile = true);
    try {
      final updated = await _authApi.updateProfile(displayName: name);
      widget.onUserUpdated(updated);
      _notify('نام نمایشی ذخیره شد.');
    } catch (error) {
      _notify('ذخیره نام انجام نشد: $error');
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  Future<void> _changePassword() async {
    if (_savingPassword) return;
    if (_currentPassword.text.isEmpty || _newPassword.text.length < 6) {
      _notify('رمز فعلی و رمز جدید حداقل ۶ کاراکتری را وارد کنید.');
      return;
    }
    if (_newPassword.text != _confirmPassword.text) {
      _notify('تکرار رمز جدید یکسان نیست.');
      return;
    }
    setState(() => _savingPassword = true);
    try {
      await _authApi.changePassword(
        currentPassword: _currentPassword.text,
        newPassword: _newPassword.text,
      );
      _currentPassword.clear();
      _newPassword.clear();
      _confirmPassword.clear();
      _notify('رمز عبور تغییر کرد. نشست‌های دیگر از حساب خارج شدند.');
    } catch (error) {
      _notify('تغییر رمز انجام نشد: $error');
    } finally {
      if (mounted) setState(() => _savingPassword = false);
    }
  }

  StaffPosSettings? _draftSettings() {
    final host = _bridgeHost.text.trim();
    final port = int.tryParse(_bridgePort.text.trim());
    if (host.isEmpty || port == null || port < 1 || port > 65535) {
      _notify('IP سیستم POS Bridge و پورت را صحیح وارد کنید.');
      return null;
    }
    return StaffPosSettings(bridgeHost: host, bridgePort: port, devices: _devices);
  }

  Future<void> _savePosSettings() async {
    if (_savingPos) return;
    final draft = _draftSettings();
    if (draft == null) return;
    setState(() => _savingPos = true);
    try {
      final saved = await _settingsApi.updatePosSettings(draft);
      if (!mounted) return;
      setState(() {
        _bridgeHost.text = saved.bridgeHost;
        _bridgePort.text = saved.bridgePort.toString();
        _devices = saved.devices.toList(growable: true);
      });
      _notify('تنظیمات پوز ذخیره شد.');
    } catch (error) {
      _notify('ذخیره تنظیمات پوز انجام نشد: $error');
    } finally {
      if (mounted) setState(() => _savingPos = false);
    }
  }

  Future<bool> _bridgeReady(StaffPosSettings settings) async {
    final result = await staffPosBridgeRequest(
      baseUrl: settings.bridgeBaseUrl,
      path: '/health',
      timeoutMs: 3500,
    );
    if (!result.ok || result.data['pharmaFlowLan'] != true) {
      _notify('به شبکه داروخانه متصل نیستید.');
      return false;
    }
    return true;
  }

  Future<void> _testBridge() async {
    final draft = _draftSettings();
    if (draft == null) return;
    final ready = await _bridgeReady(draft);
    if (ready) _notify('ارتباط با POS Bridge برقرار است.');
  }

  Future<void> _testDevice(StaffPosDevice device) async {
    final draft = _draftSettings();
    if (draft == null || !await _bridgeReady(draft)) return;
    _notify('در حال تست ${device.name}...');
    final requestId = 'test-${DateTime.now().microsecondsSinceEpoch}';
    String grant;
    try {
      grant = await _settingsApi.requestPosGrant(
        operation: 'test',
        deviceId: device.id,
        requestId: requestId,
        amount: 0,
      );
    } catch (_) {
      _notify('برای تست دستگاه، ابتدا تنظیمات POS را ذخیره و اتصال امن را فعال کنید.');
      return;
    }
    final result = await staffPosBridgeRequest(
      grant: grant,
      baseUrl: draft.bridgeBaseUrl,
      path: '/pos/test',
      method: 'POST',
      body: {
        'requestId': requestId,
        'posId': device.id,
        'posName': device.name,
        'ip': device.ip,
        'terminalId': device.terminalId,
        'timeout': device.timeout,
        'amount': 0,
      },
      timeoutMs: device.timeout * 1000 + 5000,
    );
    if (result.ok && result.responseCode == '00') {
      _notify('اتصال به ${device.name} موفق بود.');
    } else {
      _notify('تست ${device.name} ناموفق بود: ${result.description}');
    }
  }

  Future<void> _editDevice({StaffPosDevice? current}) async {
    final name = TextEditingController(text: current?.name ?? '');
    final ip = TextEditingController(text: current?.ip ?? '');
    final terminalId = TextEditingController(text: current?.terminalId ?? '');
    final timeout = TextEditingController(text: (current?.timeout ?? 60).toString());
    var enabled = current?.enabled ?? true;

    final result = await showDialog<StaffPosDevice>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: Text(current == null ? 'افزودن دستگاه پوز' : 'ویرایش دستگاه پوز'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: name, decoration: const InputDecoration(labelText: 'نام نمایشی')),
                  TextField(
                    controller: ip,
                    textDirection: TextDirection.ltr,
                    decoration: const InputDecoration(labelText: 'IP دستگاه پوز', hintText: '192.168.1.164'),
                  ),
                  TextField(
                    controller: terminalId,
                    textDirection: TextDirection.ltr,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Terminal ID'),
                  ),
                  TextField(
                    controller: timeout,
                    textDirection: TextDirection.ltr,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Timeout (ثانیه)'),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('فعال'),
                    value: enabled,
                    onChanged: (value) => setDialogState(() => enabled = value),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('انصراف')),
              FilledButton(
                onPressed: () {
                  final timeoutValue = int.tryParse(timeout.text.trim()) ?? 60;
                  if (name.text.trim().isEmpty || ip.text.trim().isEmpty || terminalId.text.trim().isEmpty) return;
                  Navigator.pop(
                    dialogContext,
                    StaffPosDevice(
                      id: current?.id ?? 'pos-${DateTime.now().microsecondsSinceEpoch}',
                      name: name.text.trim(),
                      ip: ip.text.trim(),
                      terminalId: terminalId.text.trim(),
                      timeout: timeoutValue.clamp(10, 180).toInt(),
                      enabled: enabled,
                    ),
                  );
                },
                child: const Text('ذخیره'),
              ),
            ],
          ),
        ),
      ),
    );

    name.dispose();
    ip.dispose();
    terminalId.dispose();
    timeout.dispose();

    if (result == null || !mounted) return;
    setState(() {
      final index = _devices.indexWhere((value) => value.id == result.id);
      if (index >= 0) {
        _devices[index] = result;
      } else {
        _devices.add(result);
      }
    });
  }

  Widget _section({required String title, required IconData icon, required List<Widget> children}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [Icon(icon), const SizedBox(width: 8), Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))]),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('تنظیمات Staff')),
        body: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            _section(
              title: 'حساب کاربری',
              icon: Icons.person_outline,
              children: [
                TextField(controller: _displayName, decoration: const InputDecoration(labelText: 'نام نمایشی')),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: _savingProfile ? null : _saveProfile,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(_savingProfile ? 'در حال ذخیره...' : 'ذخیره نام نمایشی'),
                ),
              ],
            ),
            _section(
              title: 'رمز عبور',
              icon: Icons.password_outlined,
              children: [
                TextField(controller: _currentPassword, obscureText: true, decoration: const InputDecoration(labelText: 'رمز فعلی')),
                TextField(controller: _newPassword, obscureText: true, decoration: const InputDecoration(labelText: 'رمز جدید')),
                TextField(controller: _confirmPassword, obscureText: true, decoration: const InputDecoration(labelText: 'تکرار رمز جدید')),
                const SizedBox(height: 10),
                FilledButton.tonalIcon(
                  onPressed: _savingPassword ? null : _changePassword,
                  icon: const Icon(Icons.key_outlined),
                  label: Text(_savingPassword ? 'در حال تغییر...' : 'تغییر رمز عبور'),
                ),
              ],
            ),
            _section(
              title: 'اتصال POS Bridge',
              icon: Icons.router_outlined,
              children: [
                if (_loadingPos) const LinearProgressIndicator(),
                if (_posError != null) Text(_posError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                TextField(
                  controller: _bridgeHost,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(labelText: 'IP سیستم داخل داروخانه', hintText: '192.168.1.10'),
                ),
                TextField(
                  controller: _bridgePort,
                  textDirection: TextDirection.ltr,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'پورت POS Bridge'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(onPressed: _testBridge, icon: const Icon(Icons.wifi_find), label: const Text('تست اتصال به شبکه داروخانه')),
              ],
            ),
            _section(
              title: 'دستگاه‌های پوز',
              icon: Icons.point_of_sale_outlined,
              children: [
                if (_devices.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('هنوز دستگاه پوزی تعریف نشده است.'),
                  ),
                ..._devices.map(
                  (device) => Card.outlined(
                    child: ListTile(
                      leading: Icon(device.enabled ? Icons.point_of_sale : Icons.block),
                      title: Text(device.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text('${device.ip} • Terminal ${device.terminalId} • ${device.timeout}s', textDirection: TextDirection.ltr),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'test') _testDevice(device);
                          if (value == 'edit') _editDevice(current: device);
                          if (value == 'toggle') setState(() {
                            final index = _devices.indexWhere((item) => item.id == device.id);
                            _devices[index] = device.copyWith(enabled: !device.enabled);
                          });
                          if (value == 'delete') setState(() => _devices.removeWhere((item) => item.id == device.id));
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(value: 'test', child: Text('تست اتصال')),
                          const PopupMenuItem(value: 'edit', child: Text('ویرایش')),
                          PopupMenuItem(value: 'toggle', child: Text(device.enabled ? 'غیرفعال کردن' : 'فعال کردن')),
                          const PopupMenuItem(value: 'delete', child: Text('حذف')),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(onPressed: () => _editDevice(), icon: const Icon(Icons.add), label: const Text('افزودن پوز')),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _savingPos ? null : _savePosSettings,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(_savingPos ? 'در حال ذخیره...' : 'ذخیره تنظیمات پوز'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
