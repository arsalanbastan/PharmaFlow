import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

bool _hasSyncQueue(String path) {
  Database? db;
  try {
    db = sqlite3.open(path);
    final rows = db.select(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'sync_queue' LIMIT 1;",
    );
    return rows.isNotEmpty;
  } catch (_) {
    return false;
  } finally {
    db?.dispose();
  }
}

void main() {
  final userProfile = Platform.environment['USERPROFILE'];
  if (userProfile == null || userProfile.isEmpty) {
    print('USERPROFILE not available');
    return;
  }

  final roots = [
    Directory('$userProfile\\AppData\\Roaming'),
    Directory('$userProfile\\AppData\\Local'),
    Directory('$userProfile\\Desktop'),
    Directory('$userProfile\\Documents'),
  ];

  final visited = <String>{};
  var checked = 0;

  for (final root in roots) {
    if (!root.existsSync()) continue;

    final stack = <Directory>[root];
    while (stack.isNotEmpty) {
      final dir = stack.removeLast();
      List<FileSystemEntity> children;
      try {
        children = dir.listSync(followLinks: false);
      } catch (_) {
        continue;
      }

      for (final entity in children) {
        if (entity is Directory) {
          stack.add(entity);
          continue;
        }

        if (entity is! File) continue;
        final path = entity.path;
        if (!path.toLowerCase().endsWith('.db')) continue;
        if (!visited.add(path)) continue;

        checked++;
        if (_hasSyncQueue(path)) {
          print('FOUND_SYNC_QUEUE_DB=$path');
        }
      }
    }
  }

  print('DB_FILES_CHECKED=$checked');
}
