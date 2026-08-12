import 'dart:io';

void main() {
  final userProfile = Platform.environment['USERPROFILE'];
  if (userProfile == null || userProfile.isEmpty) {
    print('USERPROFILE not available');
    return;
  }

  final roots = [
    Directory(userProfile),
    Directory('$userProfile\\AppData\\Roaming'),
    Directory('$userProfile\\AppData\\Local'),
    Directory('$userProfile\\Documents'),
  ];

  final seen = <String>{};
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
        final name = entity.path.toLowerCase();
        if (!name.endsWith('.db')) continue;
        if (!name.contains('pharmaflow')) continue;
        if (seen.add(entity.path)) {
          print(entity.path);
        }
      }
    }
  }
}
