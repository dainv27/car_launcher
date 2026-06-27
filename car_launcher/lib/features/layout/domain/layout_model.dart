import 'package:flutter/material.dart';

/// Enum of all available layout types
enum LayoutType {
  dashboard_01,
}

/// Extension for LayoutType display names and icons
extension LayoutTypeExtension on LayoutType {
  String get displayName {
    switch (this) {
      case LayoutType.dashboard_01:
        return 'Single Pane';
    }
  }

  IconData get icon {
    switch (this) {
      case LayoutType.dashboard_01:
        return Icons.crop_square;
    }
  }

  /// Number of panes for this layout type
  int get paneCount {
    switch (this) {
      case LayoutType.dashboard_01:
        return 1;
    }
  }
}

/// Predefined ratio presets
enum LayoutRatio {
  fiftyFifty(0.5, '50/50'),
  sixtyForty(0.6, '60/40'),
  seventyThirty(0.7, '70/30');

  const LayoutRatio(this.value, this.label);

  final double value;
  final String label;

  /// Returns the primary pane fraction (0.0 - 1.0)
  double get primaryFraction => value;

  /// Returns the secondary pane fraction (0.0 - 1.0)
  double get secondaryFraction => 1.0 - value;
}

/// Represents an app assignment to a pane
class PaneApp {
  const PaneApp({
    required this.packageName,
    required this.appName,
    this.icon,
  });

  final String packageName;
  final String appName;
  final String? icon;

  PaneApp copyWith({
    String? packageName,
    String? appName,
    String? icon,
  }) {
    return PaneApp(
      packageName: packageName ?? this.packageName,
      appName: appName ?? this.appName,
      icon: icon ?? this.icon,
    );
  }

  Map<String, dynamic> toJson() => {
        'packageName': packageName,
        'appName': appName,
        if (icon != null) 'icon': icon,
      };

  factory PaneApp.fromJson(Map<String, dynamic> json) {
    return PaneApp(
      packageName: json['packageName'] as String,
      appName: json['appName'] as String,
      icon: json['icon'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaneApp &&
          runtimeType == other.runtimeType &&
          packageName == other.packageName;

  @override
  int get hashCode => packageName.hashCode;
}

/// Model representing the layout configuration
class LayoutModel {
  const LayoutModel({
    this.type = LayoutType.dashboard_01,
    this.ratio = LayoutRatio.fiftyFifty,
    this.paneApps = const [],
  });

  final LayoutType type;
  final LayoutRatio ratio;
  final List<PaneApp> paneApps;

  /// Get the app assigned to a specific pane index
  PaneApp? appForPane(int paneIndex) {
    if (paneIndex < 0 || paneIndex >= paneApps.length) return null;
    return paneApps[paneIndex];
  }

  LayoutModel copyWith({
    LayoutType? type,
    LayoutRatio? ratio,
    List<PaneApp>? paneApps,
  }) {
    return LayoutModel(
      type: type ?? this.type,
      ratio: ratio ?? this.ratio,
      paneApps: paneApps ?? this.paneApps,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'ratio': ratio.name,
        'paneApps': paneApps.map((a) => a.toJson()).toList(),
      };

  factory LayoutModel.fromJson(Map<String, dynamic> json) {
    return LayoutModel(
      type: LayoutType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => LayoutType.dashboard_01,
      ),
      ratio: LayoutRatio.values.firstWhere(
        (e) => e.name == json['ratio'],
        orElse: () => LayoutRatio.fiftyFifty,
      ),
      paneApps: (json['paneApps'] as List? ?? [])
          .map((e) => PaneApp.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LayoutModel &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          ratio == other.ratio &&
          _listEquals(paneApps, other.paneApps);

  @override
  int get hashCode => Object.hash(type, ratio, Object.hashAll(paneApps));

  static bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Layout helpers for pane launch logic.
extension LayoutModelX on LayoutModel {
  List<PaneApp> get assignedPaneApps =>
      paneApps.where((a) => a.packageName.isNotEmpty).toList();

  bool get hasTwoAssignedApps => assignedPaneApps.length >= 2;
}
