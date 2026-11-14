import 'package:display_settings_ui/text_size_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('text size changes immediately and survives reopening', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    double? size;

    Widget app() => MaterialApp(
      builder: (context, child) => AppTextSize(child: child!),
      home: Scaffold(
        body: Builder(
          builder: (context) {
            size = MediaQuery.textScalerOf(context).scale(20);
            return const TextSizeSettingsTile();
          },
        ),
      ),
    );

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(size, 20);

    await tester.tap(find.byType(DropdownButton<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('85٪').last);
    await tester.pumpAndSettle();
    expect(size, 17);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(size, 17);
  });
}
