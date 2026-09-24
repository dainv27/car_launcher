
import 'package:android_id/android_id.dart';
import 'package:car_launcher/core/logging/app_logger.dart';
import 'package:flutter/services.dart';

class DeviceInfo {
  DeviceInfo({
    this.id = '',
    this.androidId = '',
    this.serial = '',
    this.imei = '',
    this.manufacturer = '',
    this.model = '',
    this.sdkInt = '',
    this.androidVersion = '',
    this.hardware = '',
    this.board = '',
    this.bootloader = '',
    this.device = '',
    this.display = '',
    this.host = '',
    this.product = '',
    this.type = '',
    this.isPhysicalDevice = true,
  });

  final String id;
  final String androidId;
  final String serial;
  final String imei;
  final String manufacturer;
  final String model;
  final String sdkInt;
  final String androidVersion;
  final String hardware;
  final String board;
  final String bootloader;
  final String device;
  final String display;
  final String host;
  final String product;
  final String type;
  final bool isPhysicalDevice;

  Map<String, dynamic> toMap() => {
        'id': id,
        'androidId': androidId,
        'serial': serial,
        if (imei.isNotEmpty) 'imei': imei,
        'manufacturer': manufacturer,
        'model': model,
        'sdkInt': sdkInt,
        'androidVersion': androidVersion,
        'hardware': hardware,
        'board': board,
        'bootloader': bootloader,
        'device': device,
        'display': display,
        'host': host,
        'product': product,
        'type': type,
        'isPhysicalDevice': isPhysicalDevice,
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

  /// Fetches device information entirely on the Flutter side using the
  /// `device_info_plus` platform channel and `android_id`.
  ///
  /// Replaces the former native-bridge `getDeviceInfo` MethodChannel call.
  ///
  /// The `device_info_plus` channel is read directly (rather than through
  /// `DeviceInfoPlugin`) so that a partial `android.os.Build` payload — which is
  /// all some head units expose — is tolerated with per-field defaults instead
  /// of throwing on the first missing key.
  ///
  /// Note on the serial: `device_info_plus` v13 dropped `serialNumber` and
  /// `androidId`. We use the `android_id` package for the Android ID, and fall
  /// back to `Build.FINGERPRINT` (a stable, build-unique string exposed by
  /// `device_info_plus` as `fingerprint`) for the serial — no native code and no
  /// runtime permission required.
  static const MethodChannel _deviceInfoChannel =
      MethodChannel('dev.fluttercommunity.plus/device_info');

  Future<DeviceInfo> fetchDeviceInfo() async {
    final raw = await _deviceInfoChannel.invokeMapMethod<String, dynamic>(
      'getDeviceInfo',
    );
    final android = raw ?? const <String, dynamic>{};
    final version = _asStringKeyedMap(android['version']);

    // `device_info_plus` removed `androidId` in v4.0.0 (it always returned null).
    // The recommended replacement is the dedicated `android_id` package.
    final androidId = await const AndroidId().getId();

    // IMEI: restricted on Android 29+ for non-system apps. Left empty here;
    // populate via a platform channel if the app has READ_PHONE_STATE and the
    // device exposes the IMEI. The registration payload will omit it when empty.
    return DeviceInfo(
      id: _string(android['id']),
      androidId: androidId ?? '',
      serial: _string(android['fingerprint']),
      imei: '',
      manufacturer: _string(android['manufacturer']),
      model: _string(android['model']),
      sdkInt: _string(version['sdkInt']),
      androidVersion: _string(version['release']),
      hardware: _string(android['hardware']),
      board: _string(android['board']),
      bootloader: _string(android['bootloader']),
      device: _string(android['device']),
      display: _string(android['display']),
      host: _string(android['host']),
      product: _string(android['product']),
      type: _string(android['type']),
      isPhysicalDevice: android['isPhysicalDevice'] as bool? ?? true,
    );
  }

  static Map<String, dynamic> _asStringKeyedMap(Object? value) {
    if (value is Map) {
      return value.map((key, dynamic v) => MapEntry(key.toString(), v));
    }
    return const <String, dynamic>{};
  }

  static String _string(Object? value) {
    if (value == null) return '';
    return value.toString();
  }
}
