
import 'package:android_id/android_id.dart';
import 'package:car_launcher/core/logging/app_logger.dart';
import 'package:device_info_plus/device_info_plus.dart';

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

    // IMEI: restricted on Android 29+ for non-system apps. Left empty here;
    // populate via a platform channel if the app has READ_PHONE_STATE and the
    // device exposes the IMEI. The registration payload will omit it when empty.
    return DeviceInfo(
      id: android.id,
      androidId: androidId ?? '',
      serial: android.fingerprint,
      imei: '',
      manufacturer: android.manufacturer,
      model: android.model,
      sdkInt: android.version.sdkInt.toString(),
      androidVersion: android.version.release,
      hardware: android.hardware,
      board: android.board,
      bootloader: android.bootloader,
      device: android.device,
      display: android.display,
      host: android.host,
      product: android.product,
      type: android.type,
      isPhysicalDevice: android.isPhysicalDevice,
    );
  }
}
