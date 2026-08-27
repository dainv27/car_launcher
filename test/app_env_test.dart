import 'package:car_launcher/core/config/app_env.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppEnv', () {
    test('name defaults to development when APP_ENV is not defined', () {
      // Unit tests run without `--dart-define=APP_ENV=...`, so the
      // compile-time default applies.
      expect(AppEnv.name, 'development');
    });

    test('isDevelopment is true for any non-production build', () {
      expect(AppEnv.isDevelopment, isTrue);
    });
  });
}
