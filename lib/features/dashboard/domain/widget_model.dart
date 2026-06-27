/// Widget type enum
enum WidgetType {
  clock,
  media,
  navigation,
  appShortcut,
}

/// Widget model representing a dashboard widget
class WidgetModel {
  const WidgetModel({
    required this.id,
    required this.type,
    this.x = 0,
    this.y = 0,
    this.width = 1,
    this.height = 1,
    this.data = const {},
  });

  final String id;
  final WidgetType type;
  final int x;
  final int y;
  final int width;
  final int height;
  final Map<String, String> data;

  WidgetModel copyWith({
    String? id,
    WidgetType? type,
    int? x,
    int? y,
    int? width,
    int? height,
    Map<String, String>? data,
  }) {
    return WidgetModel(
      id: id ?? this.id,
      type: type ?? this.type,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      data: data ?? this.data,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'x': x,
        'y': y,
        'width': width,
        'height': height,
        'data': data,
      };

  factory WidgetModel.fromJson(Map<String, dynamic> json) {
    return WidgetModel(
      id: json['id'] as String,
      type: WidgetType.values.firstWhere(
        (e) => e.name == (json['type'] as String? ?? 'clock'),
        orElse: () => WidgetType.clock,
      ),
      x: json['x'] as int? ?? 0,
      y: json['y'] as int? ?? 0,
      width: json['width'] as int? ?? 1,
      height: json['height'] as int? ?? 1,
      data: Map<String, String>.from(json['data'] as Map? ?? {}),
    );
  }
}

/// Widget registry — available widget types
class WidgetRegistry {
  static const int gridColumns = 4;
  static const int gridRows = 3;
  static const double cellSize = 120.0;

  static const Map<WidgetType, String> names = {
    WidgetType.clock: 'Clock',
    WidgetType.media: 'Media',
    WidgetType.navigation: 'Navigation',
    WidgetType.appShortcut: 'App Shortcut',
  };

  static const Map<WidgetType, int> defaultWidths = {
    WidgetType.clock: 2,
    WidgetType.media: 3,
    WidgetType.navigation: 2,
    WidgetType.appShortcut: 1,
  };

  static const Map<WidgetType, int> defaultHeights = {
    WidgetType.clock: 1,
    WidgetType.media: 1,
    WidgetType.navigation: 1,
    WidgetType.appShortcut: 1,
  };

  static const Map<WidgetType, int> maxWidths = {
    WidgetType.clock: 4,
    WidgetType.media: 4,
    WidgetType.navigation: 4,
    WidgetType.appShortcut: 2,
  };

  static const Map<WidgetType, int> maxHeights = {
    WidgetType.clock: 2,
    WidgetType.media: 2,
    WidgetType.navigation: 2,
    WidgetType.appShortcut: 2,
  };
}
