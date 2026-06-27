/// Navigation state model
library;

/// Navigation provider enum
enum NavigationProvider {
  googleMaps('com.google.android.apps.maps', 'Google Maps'),
  waze('com.waze', 'Waze'),
  here('com.here.app.maps', 'HERE WeGo'),
  tomtom('com.tomtom.gplay.navapp', 'TomTom GO'),
  sygic('com.sygic.aura', 'Sygic');

  const NavigationProvider(this.packageName, this.displayName);

  final String packageName;
  final String displayName;
}

/// Navigation state
enum NavState {
  idle,
  navigating,
  rerouting,
  loading,
}

/// Model representing current navigation state
class NavigationStateModel {
  const NavigationStateModel({
    this.state = NavState.idle,
    this.destination = '',
    this.eta = '',
    this.distance = '',
    this.nextTurn = '',
    this.currentProvider = NavigationProvider.googleMaps,
    this.isActive = false,
  });

  final NavState state;
  final String destination;
  final String eta;
  final String distance;
  final String nextTurn;
  final NavigationProvider currentProvider;
  final bool isActive;

  NavigationStateModel copyWith({
    NavState? state,
    String? destination,
    String? eta,
    String? distance,
    String? nextTurn,
    NavigationProvider? currentProvider,
    bool? isActive,
  }) {
    return NavigationStateModel(
      state: state ?? this.state,
      destination: destination ?? this.destination,
      eta: eta ?? this.eta,
      distance: distance ?? this.distance,
      nextTurn: nextTurn ?? this.nextTurn,
      currentProvider: currentProvider ?? this.currentProvider,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toJson() => {
        'state': state.name,
        'destination': destination,
        'eta': eta,
        'distance': distance,
        'nextTurn': nextTurn,
        'currentProvider': currentProvider.name,
        'isActive': isActive,
      };

  factory NavigationStateModel.fromJson(Map<String, dynamic> json) {
    return NavigationStateModel(
      state: NavState.values.firstWhere(
        (e) => e.name == (json['state'] as String? ?? 'idle'),
        orElse: () => NavState.idle,
      ),
      destination: json['destination'] as String? ?? '',
      eta: json['eta'] as String? ?? '',
      distance: json['distance'] as String? ?? '',
      nextTurn: json['nextTurn'] as String? ?? '',
      currentProvider: NavigationProvider.values.firstWhere(
        (e) => e.name == (json['currentProvider'] as String? ?? 'googleMaps'),
        orElse: () => NavigationProvider.googleMaps,
      ),
      isActive: json['isActive'] as bool? ?? false,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NavigationStateModel &&
          runtimeType == other.runtimeType &&
          state == other.state &&
          destination == other.destination &&
          eta == other.eta &&
          distance == other.distance &&
          nextTurn == other.nextTurn &&
          currentProvider == other.currentProvider &&
          isActive == other.isActive;

  @override
  int get hashCode => Object.hash(
        state,
        destination,
        eta,
        distance,
        nextTurn,
        currentProvider,
        isActive,
      );

  /// Default idle state
  static const idle = NavigationStateModel();
}
