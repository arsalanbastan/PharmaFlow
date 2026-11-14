import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppTextSize extends StatefulWidget {
  const AppTextSize({required this.child, this.defaultFactor = 1, super.key});

  final Widget child;
  final double defaultFactor;

  @override
  State<AppTextSize> createState() => _AppTextSizeState();
}

class _AppTextSizeState extends State<AppTextSize> {
  static const _key = 'appearance.textSizePercentage';
  static const _sizes = [65, 75, 85, 90, 100, 110, 120, 130, 140];
  late final Future<SharedPreferences> _preferences =
      SharedPreferences.getInstance();
  int _percentage = 100;
  bool _ready = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    try {
      final preferences = await _preferences;
      final saved = preferences.getInt(_key);
      if (mounted && _sizes.contains(saved)) {
        setState(() => _percentage = saved!);
      }
    } catch (_) {
      // Use the platform default if local storage is unavailable.
    } finally {
      if (mounted) setState(() => _ready = true);
    }
  }

  Future<void> _save(int percentage) async {
    final previous = _percentage;
    setState(() {
      _percentage = percentage;
      _saving = true;
    });
    try {
      final preferences = await _preferences;
      if (!await preferences.setInt(_key, percentage)) {
        throw StateError('Text size could not be saved.');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _percentage = previous);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('ذخیره اندازه متن انجام نشد.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final factor = widget.defaultFactor * _percentage / 100;
    return _TextSizeScope(
      percentage: _percentage,
      onChanged: _ready && !_saving ? _save : null,
      child: MediaQuery(
        data: media.copyWith(
          textScaler: factor == 1
              ? media.textScaler
              : _ScaledText(media.textScaler, factor),
        ),
        child: widget.child,
      ),
    );
  }
}

class _ScaledText extends TextScaler {
  const _ScaledText(this.system, this.factor);

  final TextScaler system;
  final double factor;

  @override
  double scale(double fontSize) => system.scale(fontSize) * factor;

  @override
  double get textScaleFactor => scale(16) / 16;

  @override
  bool operator ==(Object other) =>
      other is _ScaledText && other.system == system && other.factor == factor;

  @override
  int get hashCode => Object.hash(system, factor);
}

class _TextSizeScope extends InheritedWidget {
  const _TextSizeScope({
    required this.percentage,
    required this.onChanged,
    required super.child,
  });

  final int percentage;
  final ValueChanged<int>? onChanged;

  @override
  bool updateShouldNotify(_TextSizeScope oldWidget) =>
      oldWidget.percentage != percentage || oldWidget.onChanged != onChanged;
}

class TextSizeSettingsTile extends StatelessWidget {
  const TextSizeSettingsTile({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_TextSizeScope>();
    if (scope == null) return const SizedBox.shrink();
    return ListTile(
      leading: const Icon(Icons.format_size),
      title: const Text('اندازه متن'),
      subtitle: DropdownButton<int>(
        isExpanded: true,
        value: scope.percentage,
        onChanged: scope.onChanged == null
            ? null
            : (value) {
                if (value != null) scope.onChanged!(value);
              },
        items: [
          for (final percentage in _AppTextSizeState._sizes)
            DropdownMenuItem(
              value: percentage,
              child: Text(
                percentage == 100 ? 'پیش‌فرض (۱۰۰٪)' : '$percentage٪',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }
}
