import 'dart:math' as math;

import 'package:car_launcher/core/logging/app_logger.dart';
import 'package:car_launcher/core/native/native_bridge.dart';

class DeviceInfo {
  DeviceInfo({
    this.id = '',
    this.androidId = '',
    this.serial = '',
    this.manufacturer = '',
    this.model = '',
    this.sdkInt = '',
  });

  final String id;
  final String androidId;
  final String serial;
  final String manufacturer;
  final String model;
  final String sdkInt;

  Map<String, dynamic> toMap() => {
        'id': id,
        'androidId': androidId,
        'serial': serial,
        'manufacturer': manufacturer,
        'model': model,
        'sdkInt': sdkInt,
      };
}

class DeviceInfoService {
  DeviceInfoService._();

  /// Global singleton.
  static final DeviceInfoService instance = DeviceInfoService._();

  Future<DeviceInfo?> getInfo() async {
    final rawInfo = await NativeBridge.call<Map<dynamic, dynamic>>('getDeviceInfo');
    if (rawInfo == null || rawInfo.isEmpty) {
      AppLogger.instance.w('Device registration skipped — no device info available', tag: 'DEVICE');
      return null;
    }

    return DeviceInfo(
      id: rawInfo['id']?.toString() ?? '',
      androidId: rawInfo['androidId']?.toString() ?? '',
      serial: rawInfo['serial']?.toString() ?? '',
      manufacturer: rawInfo['manufacturer']?.toString() ?? '',
      model: rawInfo['model']?.toString() ?? '',
      sdkInt: rawInfo['sdkInt']?.toString() ?? '',
    );
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
}
