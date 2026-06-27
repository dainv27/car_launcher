import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TBox documentation', () {
    const requiredFiles = <String>[
      'docs/tbox/README.md',
      'docs/tbox/01_OVERVIEW.md',
      'docs/tbox/02_SDK_AND_BUILD.md',
      'docs/tbox/03_NATIVE_API.md',
      'docs/tbox/04_EMBEDDED_APPS.md',
      'docs/tbox/05_SIDEBAR_AND_OVERLAYS.md',
      'docs/tbox/06_ROM_PERMISSIONS.md',
      'docs/tbox/07_OPERATIONS_AND_DEBUGGING.md',
      'docs/tbox/CARCAR_LAUNCHER_ANALYSIS.md',
    ];

    test('contains the complete documentation set', () {
      for (final path in requiredFiles) {
        expect(File(path).existsSync(), isTrue, reason: '$path is missing');
      }
    });

    test('indexes native APIs, platform views, permissions, and tools', () {
      final api = File('docs/tbox/03_NATIVE_API.md').readAsStringSync();
      final embedding = File(
        'docs/tbox/04_EMBEDDED_APPS.md',
      ).readAsStringSync();
      final permissions = File(
        'docs/tbox/06_ROM_PERMISSIONS.md',
      ).readAsStringSync();
      final operations = File(
        'docs/tbox/07_OPERATIONS_AND_DEBUGGING.md',
      ).readAsStringSync();

      for (final method in <String>[
        'com.carlauncher/native',
        'launchMapsWithYoutubeOnTop',
        'virtual_display_app',
        'embedded_app_pane',
      ]) {
        expect(api, contains(method));
      }
      expect(embedding, contains('VirtualDisplay'));
      expect(embedding, contains('ActivityView'));
      expect(permissions, contains('ADD_TRUSTED_DISPLAY'));
      expect(permissions, contains('INJECT_EVENTS'));
      expect(operations, contains('tools/tbox/diagnose.sh'));
      expect(operations, contains('tools/tbox/configure_multiwindow.sh'));
    });
  });
}
