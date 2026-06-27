import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('native launch backgrounds use the provided splash icon', () {
    const launchBackgrounds = [
      'android/app/src/main/res/drawable/launch_background.xml',
      'android/app/src/main/res/drawable-night/launch_background.xml',
      'android/app/src/main/res/drawable-v21/launch_background.xml',
    ];

    for (final path in launchBackgrounds) {
      final source = File(path).readAsStringSync();
      expect(source, contains('@drawable/splash'), reason: path);
      expect(source, isNot(contains('logo placeholder')), reason: path);
    }

    expect(
      File(
        'android/app/src/main/res/drawable-mdpi/splash.png',
      ).existsSync(),
      isTrue,
    );
  });

  test('Flutter and native startup use the same splash asset', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final splash = File(
      'lib/features/dashboard/presentation/splash_page.dart',
    ).readAsStringSync();

    expect(pubspec, contains('assets/images/splash.png'));
    expect(splash, contains("'assets/images/splash.png'"));
    expect(File('assets/images/splash.png').existsSync(), isTrue);
    expect(
      File(
        'android/app/src/main/res/drawable-mdpi/splash.png',
      ).existsSync(),
      isTrue,
    );
  });
}
