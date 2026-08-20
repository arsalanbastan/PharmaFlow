import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:pharmaflow/core/database/database_service.dart';
import 'package:pharmaflow/core/database/migration_manager.dart';
import 'package:pharmaflow/main.dart';

void main() {
  setUp(() {
    final db = sqlite3.openInMemory();

    MigrationManager.migrate(db);
    DatabaseService.instance.injectDatabaseForTesting(db);
  });

  tearDown(() {
    DatabaseService.instance.close();
  });

  testWidgets('App builds smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: PharmaFlowApp()));

    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);

    expect(tester.takeException(), isNull);
  });
}
