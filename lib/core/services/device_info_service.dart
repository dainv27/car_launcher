import 'dart:math' as math;

import 'package:android_id/android_id.dart';
import 'package:car_launcher/core/logging/app_logger.dart';
import 'package:device_info_plus/device_info_plus.dart';

class DeviceInfo {
  DeviceInfo({
    this.id = '',
    this.androidId = '',
    this.serial = '',
    this.manufacturer = '',
    this.model = '',
    this.sdkInt = '',
    this.androidVersion = '',
  });

  final String id;
  final String androidId;
  final String serial;
  final String manufacturer;
  final String model;
  final String sdkInt;
  final String androidVersion;

  Map<String, dynamic> toMap() => {
        'id': id,
        'androidId': androidId,
        'serial': serial,
        'manufacturer': manufacturer,
        'model': model,
        'sdkInt': sdkInt,
        'androidVersion': androidVersion,
      };
}

class DeviceInfoService {
  DeviceInfoService._();

  /// Global singleton.
  static final DeviceInfoService instance = DeviceInfoService._();

  Future<DeviceInfo?> getInfo() async {
    try {
      return await fetchDeviceInfo();
    } catch (e) {
      AppLogger.instance.w('Device registration skipped — no device info available', tag: 'DEVICE', error: e);
      return null;
    }
  }

  String deviceId(DeviceInfo deviceInfo) {
    final preferred =
    [
      deviceInfo.androidId,
      deviceInfo.serial,
      [
        deviceInfo.manufacturer,
        deviceInfo.model,
        deviceInfo.sdkInt,
      ].where((value) => value.isNotEmpty).join('-'),
    ].firstWhere(
          (value) => value.isNotEmpty && value.toLowerCase() != 'unknown',
      orElse: () => '',
    );
    if (preferred.isEmpty) return '';
    final sanitized = preferred.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '-');
    return sanitized.substring(0, math.min(64, sanitized.length));
  }

  /// Fetches device information entirely on the Flutter side using
  /// `device_info_plus` and `android_id`.
  ///
  /// Replaces the former native-bridge `getDeviceInfo` MethodChannel call.
  ///
  /// Note on the serial: `device_info_plus` v13 dropped `serialNumber` and
  /// `androidId`. We use the `android_id` package for the Android ID, and fall
  /// back to `Build.FINGERPRINT` (a stable, build-unique string exposed by
  /// `device_info_plus` as `fingerprint`) for the serial — no native code and no
  /// runtime permission required.
  Future<DeviceInfo> fetchDeviceInfo() async {
    final plugin = DeviceInfoPlugin();
    final android = await plugin.androidInfo;

    // `device_info_plus` removed `androidId` in v4.0.0 (it always returned null).
    // The recommended replacement is the dedicated `android_id` package.
    final androidId = await const AndroidId().getId();

    return DeviceInfo(
      id: android.id,
      androidId: androidId ?? '',
      serial: android.fingerprint,
      manufacturer: android.manufacturer,
      model: android.model,
      sdkInt: android.version.sdkInt.toString(),
      androidVersion: android.version.release,
    );
  }
}
