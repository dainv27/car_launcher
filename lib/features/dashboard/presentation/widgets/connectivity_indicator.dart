import 'package:car_launcher/core/theme/carplay_theme.dart';
import 'package:flutter/material.dart';

class ConnectionIcon {
  static IconData bluetoothIcon(Map<String, dynamic> status) {
    final bluetoothConnected = status['bluetoothConnected'] == true;
    final bluetoothEnabled = status['bluetoothEnabled'] == true;
    return bluetoothConnected
        ? Icons.bluetooth_connected
        : bluetoothEnabled
        ? Icons.bluetooth
        : Icons.bluetooth_disabled;
  }

  static IconData networkIcon(Map<String, dynamic> status, {int? level, bool? wifi}) {
    final effectiveLevel = level ?? networkLevel(status);
    final useWifi = wifi ?? status['wifi'] == true;
    if (useWifi) {
      if (effectiveLevel <= 0) return Icons.signal_wifi_0_bar;
      if (effectiveLevel == 1) return Icons.network_wifi_1_bar;
      if (effectiveLevel == 2) return Icons.network_wifi_2_bar;
      if (effectiveLevel == 3) return Icons.network_wifi_3_bar;
      return Icons.wifi;
    }
    if (status['cellular'] == true) return Icons.signal_cellular_4_bar;
    return Icons.signal_wifi_off;
  }

  static String networkLabel(Map<String, dynamic> status, int level) {
    final percent = level < 0 ? null : level * 25;
    if (status['wifi'] == true) {
      return percent == null ? 'Wi-Fi' : 'Wi-Fi $percent%';
    }
    if (status['cellular'] == true) {
      return percent == null ? 'Cellular' : 'Cellular $percent%';
    }
    return 'No network';
  }

  static int networkLevel(Map<String, dynamic> status) {
    if (status['wifi'] == true) return status['wifiLevel'] as int? ?? -1;
    if (status['cellular'] == true) {
      return status['cellularLevel'] as int? ?? -1;
    }
    return -1;
  }
}

class ConnectivityIndicator extends StatelessWidget {
  const ConnectivityIndicator({super.key, required this.status, this.showLabels = false, this.size = 16});

  final Map<String, dynamic> status;
  final bool showLabels;
  final double size;

  @override
  Widget build(BuildContext context) {
    final networkLevel = ConnectionIcon.networkLevel(status);
    final bluetoothConnected = status['bluetoothConnected'] == true;
    final online = status['validated'] == true;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _MobileNetworkStatus(connectivity: status),
        const SizedBox(width: 10),
        Icon(
          ConnectionIcon.networkIcon(status, level: networkLevel),
          size: size,
          color: online ? CarPlayTheme.neonCyan : CarPlayTheme.onSurfaceVariant,
        ),
        if (showLabels) ...[
          const SizedBox(width: 5),
          Text(
            ConnectionIcon.networkLabel(status, networkLevel),
            style: TextStyle(
              color: online ? CarPlayTheme.neonCyan : CarPlayTheme.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
        const SizedBox(width: 10),
        Icon(
          ConnectionIcon.bluetoothIcon(status),
          size: size,
          color: bluetoothConnected ? CarPlayTheme.neonCyan : CarPlayTheme.onSurfaceVariant,
        ),
      ],
    );
  }
}

class _MobileNetworkStatus extends StatelessWidget {
  const _MobileNetworkStatus({required this.connectivity});

  final Map<String, dynamic> connectivity;

  @override
  Widget build(BuildContext context) {
    final cellular = connectivity['cellular'] == true;
    final level = connectivity['cellularLevel'] as int? ?? -1;
    final networkType = (connectivity['cellularNetworkType'] as String?)?.trim() ?? '';
    final operator = (connectivity['cellularOperator'] as String?)?.trim() ?? '';
    final statusText = cellular ? _activeLabel(networkType, operator, level) : 'Mobile unavailable';
    final color = cellular ? CarPlayTheme.neonCyan : CarPlayTheme.onSurfaceVariant;

    return Tooltip(
      message: statusText,
      child: Semantics(
        label: statusText,
        child: Icon(_signalIcon(cellular, level), key: const Key('bottom-bar-mobile-network'), color: color, size: 16),
      ),
    );
  }

  static String _activeLabel(String networkType, String operator, int level) {
    final parts = [
      'Mobile',
      if (networkType.isNotEmpty && networkType != 'Unknown') networkType,
      if (operator.isNotEmpty) operator,
      if (level >= 0) '$level/4',
    ];
    return parts.join(' ');
  }

  static IconData _signalIcon(bool cellular, int level) {
    if (!cellular) return Icons.signal_cellular_off_outlined;
    if (level >= 4) return Icons.signal_cellular_4_bar;
    if (level >= 1) return Icons.signal_cellular_alt;
    return Icons.signal_cellular_connected_no_internet_0_bar;
  }
}
