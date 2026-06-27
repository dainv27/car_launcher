import 'dart:math' as math;

import 'package:car_launcher/core/logging/app_logger.dart';
import 'package:car_launcher/core/native/native_bridge.dart';
import 'package:car_launcher/core/utils/string_utils.dart';

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
}

class DeviceInfoService {
  DeviceInfoService._();

  /// Global singleton.
  static final DeviceInfoService instance = DeviceInfoService._();

  Future<Map<String, dynamic>?> getInfo() async {
    final rawInfo = await NativeBridge.call<Map<dynamic, dynamic>>('getDeviceInfo');
    if (rawInfo == null || rawInfo.isEmpty) {
      AppLogger.instance.w('Device registration skipped — no device info available', tag: 'DEVICE');
      return null;
    }

    final deviceInfo = rawInfo.map((k, v) => MapEntry(k.toString(), v));
    return deviceInfo;
  }

  String deviceId(Map<String, dynamic> deviceInfo) {
    final preferred =
    [
      StringUtils.toStringValue(deviceInfo['androidId']),
      StringUtils.toStringValue(deviceInfo['serial']),
      [
        StringUtils.toStringValue(deviceInfo['manufacturer']),
        StringUtils.toStringValue(deviceInfo['model']),
        StringUtils.toStringValue(deviceInfo['sdkInt']),
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
