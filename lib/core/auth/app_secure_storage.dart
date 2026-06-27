import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Shared Keychain / secure storage singleton.
abstract final class AppSecureStorage {
  static const FlutterSecureStorage instance = FlutterSecureStorage(
    iOptions: IOSOptions(),
    mOptions: MacOsOptions(),
  );
}
