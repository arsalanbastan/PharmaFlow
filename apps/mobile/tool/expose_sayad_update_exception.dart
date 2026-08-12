import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:pharmaflow/core/database/database_service.dart';
import 'package:pharmaflow/core/sync/sync_operation.dart';
import 'package:pharmaflow/core/sync/sync_status.dart';
import 'package:pharmaflow/data/repositories/local/local_cheque_repository.dart';
import 'package:pharmaflow/data/repositories/local/sync_queue_repository.dart';

Future<void> main() async {
  debugPrint('ENTER: expose_sayad_update_exception.dart -> main');
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('AWAIT: DatabaseService.instance.initialize()');
  await DatabaseService.instance.initialize();
  debugPrint('DONE: DatabaseService.instance.initialize()');

  final chequeRepository = LocalChequeRepository(DatabaseService.instance);
  final queueRepository = SyncQueueRepository(DatabaseService.instance);
  debugPrint('AWAIT: chequeRepository.getAll(...)');
  final allCheques = await chequeRepository.getAll(
    includeArchived: true,
    includeCancelled: true,
  );
  debugPrint('DONE: chequeRepository.getAll(...)');

  final unregistered = allCheques
      .where((cheque) => !cheque.isRegisteredInSayad)
      .toList(growable: false);

  if (allCheques.isEmpty) {
    stdout.writeln('No cheques found in local database.');
    debugPrint('EXIT: expose_sayad_update_exception.dart -> main');
    return;
  }

  final target = unregistered.isNotEmpty
      ? unregistered.first
      : allCheques.first;

  stdout.writeln('target cheque id=${target.id}');
  stdout.writeln(
    'before update isRegisteredInSayad=${target.isRegisteredInSayad}',
  );

  debugPrint('AWAIT: chequeRepository.findById(target.id)');
  final latest = await chequeRepository.findById(target.id);
  debugPrint('DONE: chequeRepository.findById(target.id)');
  if (latest == null) {
    stdout.writeln(
      'latest cheque not found via LocalChequeRepository.findById(${target.id})',
    );
    debugPrint('EXIT: expose_sayad_update_exception.dart -> main');
    return;
  }

  stdout.writeln(
    'latest from findById isRegisteredInSayad=${latest.isRegisteredInSayad}',
  );

  try {
    debugPrint('AWAIT: chequeRepository.update(...)');
    await chequeRepository.update(
      latest.copyWith(isRegisteredInSayad: true, updatedAt: DateTime.now()),
    );
    debugPrint('DONE: chequeRepository.update(...)');

    debugPrint('AWAIT: chequeRepository.findById(target.id)');
    final reloaded = await chequeRepository.findById(target.id);
    debugPrint('DONE: chequeRepository.findById(target.id)');
    stdout.writeln(
      'after update findById isRegisteredInSayad=${reloaded?.isRegisteredInSayad}',
    );

    debugPrint('AWAIT: queueRepository.getPending()');
    final pending = await queueRepository.getPending();
    debugPrint('DONE: queueRepository.getPending()');
    final queueItems = pending
        .where(
          (item) =>
              item.entityId == target.id &&
              item.operation == SyncOperation.update,
        )
        .toList(growable: false);

    if (queueItems.isEmpty) {
      stdout.writeln(
        'queue update item not present for cheque id=${target.id}',
      );
    } else {
      for (final item in queueItems) {
        stdout.writeln(
          'queue item id=${item.id} entityType=${item.entityType} entityId=${item.entityId} operation=${item.operation.dbValue} status=${item.status.dbValue} retryCount=${item.retryCount}',
        );
      }
    }
    debugPrint('EXIT: expose_sayad_update_exception.dart -> main');
  } catch (error, stackTrace) {
    stdout.writeln('EXCEPTION_TYPE=${error.runtimeType}');
    stdout.writeln('EXCEPTION_MESSAGE=$error');
    stdout.writeln('STACK_TRACE_START');
    stdout.writeln(stackTrace.toString());
    stdout.writeln('STACK_TRACE_END');
    debugPrint(error.toString());
    debugPrintStack(stackTrace: stackTrace);
    rethrow;
  }
}
