import 'package:car_launcher/core/native/native_bridge.dart';
import 'package:car_launcher/core/theme/carplay_theme.dart';
import 'package:car_launcher/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:car_launcher/features/media/data/media_controller.dart';
import 'package:car_launcher/shared/data/location_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Responsive top bar containing all primary in-app destinations.
class TopAppBar extends ConsumerWidget {
  const TopAppBar({super.key, this.title = ''});

  final String title;

  static const double height = 50;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = title.isEmpty
        ? ref.watch(currentLocationProvider)
        : const AsyncValue<LocationInfo?>.data(null);
    final hasMediaAccess =
        title.isEmpty && ref.watch(mediaAccessProvider).valueOrNull == true;
    final connectivity = ref.watch(connectivityStatusProvider);
    final clock = ref.watch(clockProvider);
    final tracking = ref.watch(vehicleTrackingProvider);

    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 1200;
          return Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: CarPlayTheme.gutter,
            ),
            child: Row(
              children: [
                Expanded(child: _buildLeftSection(location)),
                const SizedBox(width: CarPlayTheme.widgetGap),
                _buildRightSection(
                  context,
                  ref,
                  hasMediaAccess,
                  connectivity,
                  compact,
                  clock,
                  tracking,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLeftSection(AsyncValue<LocationInfo?> location) {
    final placeName = location.valueOrNull?.displayName;
    return Row(
      children: [
        Image.asset(
          'assets/images/k3_logo.png',
          key: const Key('top-bar-k3-logo'),
          width: 40,
          height: 30,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          semanticLabel: 'K3',
        ),
        const SizedBox(width: 16),
        Container(
          width: 1,
          height: 24,
          color: CarPlayTheme.neonCyan.withValues(alpha: 0.32),
        ),
        const SizedBox(width: 16),
        if (title.isEmpty) ...[
          const Icon(
            Icons.navigation,
            color: CarPlayTheme.neonMagenta,
            size: 14,
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Text(
            title.isNotEmpty
                ? title
                : placeName == null || placeName.isEmpty
                ? 'Locating current position'
                : placeName,
            key: Key(
              title.isNotEmpty ? 'top-bar-title' : 'top-bar-location-name',
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: CarPlayTheme.neonCyan,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.0,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRightSection(
    BuildContext context,
    WidgetRef ref,
    bool hasMediaAccess,
    ConnectivityStatus connectivity,
    bool compact,
    String clock,
    VehicleTrackingState tracking,
  ) {
    if (compact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ClockDisplay(clock: clock),
          _gap,
          _TrackingStatusDot(tracking: tracking),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ClockDisplay(clock: clock),
        _gap,
        _NavigationMenu(),
        _gap,
        IconButton(
          tooltip: hasMediaAccess
              ? 'Media access enabled'
              : 'Enable media access',
          onPressed: () =>
              NativeBridge.call<bool>('openNotificationAccessSettings'),
          icon: Icon(
            hasMediaAccess ? Icons.library_music : Icons.music_off_outlined,
            color: CarPlayTheme.onSurfaceVariant,
            size: 20,
          ),
          padding: EdgeInsets.zero,
          constraints: _buttonConstraints,
        ),
        _gap,
        IconButton(
          tooltip: 'Voice assistant',
          onPressed: () => NativeBridge.call<bool>('launchVoiceAssistant'),
          icon: const Icon(
            Icons.mic_outlined,
            color: CarPlayTheme.onSurfaceVariant,
            size: 20,
          ),
          padding: EdgeInsets.zero,
          constraints: _buttonConstraints,
        ),
        _gap,
        _TrackingStatusDot(tracking: tracking),
      ],
    );
  }

  static const _buttonConstraints = BoxConstraints(minWidth: 30, minHeight: 30);
  static const _gap = SizedBox(width: CarPlayTheme.widgetGap);
}

class _TrackingStatusDot extends StatefulWidget {
  const _TrackingStatusDot({required this.tracking});

  final VehicleTrackingState tracking;

  @override
  State<_TrackingStatusDot> createState() => _TrackingStatusDotState();
}

class _TrackingStatusDotState extends State<_TrackingStatusDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    final style = _TrackingDotStyle.from(widget.tracking);
    _controller = AnimationController(vsync: this, duration: style.duration);
    _pulse = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _syncAnimation(style);
  }

  @override
  void didUpdateWidget(covariant _TrackingStatusDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAnimation(_TrackingDotStyle.from(widget.tracking));
  }

  void _syncAnimation(_TrackingDotStyle style) {
    if (_controller.duration != style.duration) {
      _controller.duration = style.duration;
    }
    if (style.animated) {
      if (!_controller.isAnimating) {
        _controller.repeat(reverse: true);
      }
    } else {
      _controller
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = _TrackingDotStyle.from(widget.tracking);

    return Tooltip(
      message: style.label,
      child: AnimatedBuilder(
        key: const Key('top-bar-tracking-dot'),
        animation: _pulse,
        builder: (context, child) {
          final value = style.animated ? _pulse.value : 0.0;
          final opacity = style.baseOpacity + (style.opacityRange * value);
          final scale = 0.92 + (0.16 * value);
          final glow = style.glowRadius + (style.glowRange * value);

          return Transform.scale(
            scale: scale,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: style.color.withValues(alpha: opacity),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
                  width: 0.6,
                ),
                boxShadow: style.glow
                    ? [
                        BoxShadow(
                          color: style.color.withValues(alpha: 0.46 * opacity),
                          blurRadius: glow,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TrackingDotStyle {
  const _TrackingDotStyle({
    required this.color,
    required this.label,
    required this.duration,
    required this.animated,
    this.glow = true,
    this.baseOpacity = 0.62,
    this.opacityRange = 0.38,
    this.glowRadius = 6,
    this.glowRange = 8,
  });

  final Color color;
  final String label;
  final Duration duration;
  final bool animated;
  final bool glow;
  final double baseOpacity;
  final double opacityRange;
  final double glowRadius;
  final double glowRange;

  factory _TrackingDotStyle.from(VehicleTrackingState tracking) {
    if (!tracking.enabled) {
      return _TrackingDotStyle(
        color: CarPlayTheme.onSurfaceVariant,
        label: 'Vehicle tracking paused',
        duration: const Duration(milliseconds: 1800),
        animated: false,
        glow: false,
        baseOpacity: 0.52,
        opacityRange: 0,
      );
    }

    if (tracking.lastSyncError != null) {
      return const _TrackingDotStyle(
        color: Color(0xFFFF5C7A),
        label: 'Vehicle tracking active, sync needs attention',
        duration: Duration(milliseconds: 1200),
        animated: true,
        baseOpacity: 0.58,
        opacityRange: 0.34,
        glowRadius: 5,
        glowRange: 7,
      );
    }

    if (tracking.isSyncing) {
      return const _TrackingDotStyle(
        color: CarPlayTheme.neonCyan,
        label: 'Vehicle tracking syncing',
        duration: Duration(milliseconds: 900),
        animated: true,
        baseOpacity: 0.54,
        opacityRange: 0.42,
        glowRadius: 6,
        glowRange: 10,
      );
    }

    if (tracking.pendingSyncCount > 0) {
      return _TrackingDotStyle(
        color: const Color(0xFFFFC857),
        label:
            'Vehicle tracking active, ${tracking.pendingSyncCount} pending sync',
        duration: const Duration(milliseconds: 1500),
        animated: true,
        baseOpacity: 0.58,
        opacityRange: 0.36,
        glowRadius: 5,
        glowRange: 7,
      );
    }

    return const _TrackingDotStyle(
      color: Color(0xFF35E89B),
      label: 'Vehicle tracking active',
      duration: Duration(milliseconds: 2300),
      animated: true,
      baseOpacity: 0.68,
      opacityRange: 0.22,
      glowRadius: 5,
      glowRange: 5,
    );
  }
}

class _ClockDisplay extends StatelessWidget {
  const _ClockDisplay({required this.clock});

  final String clock;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const Key('top-bar-clock'),
      width: 94,
      height: 44,
      child: Row(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            width: 2,
            height: 32,
            decoration: BoxDecoration(
              color: CarPlayTheme.neonMagenta.withValues(alpha: 0.56),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          const SizedBox(width: 11),
          Flexible(
            child: Text(
              clock,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 25,
                height: 1,
                fontWeight: FontWeight.w500,
                letterSpacing: -0.6,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavigationMenu extends StatelessWidget {
  const _NavigationMenu();

  static const _destinations = <_NavDestination>[
    _NavDestination('Media', '/media', Icons.play_circle_outline),
    _NavDestination('Navigation', '/navigation', Icons.navigation),
    _NavDestination('Apps', '/apps', Icons.apps),
    _NavDestination('Settings', '/settings', Icons.settings_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final router = GoRouter.of(context);
    final currentPath = GoRouterState.of(context).uri.path;
    final selected = _destinations.firstWhere(
      (d) => d.route == currentPath ||
          (d.route != '/' && currentPath.startsWith(d.route)),
      orElse: () => _destinations.first,
    );

    return DecoratedBox(
      key: const Key('top-bar-navigation-menu'),
      decoration: BoxDecoration(
        color: CarPlayTheme.surfaceContainer.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: CarPlayTheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: _destinations.map((dest) {
            final isSelected = dest.route == selected.route;
            return _NavButton(
              destination: dest,
              selected: isSelected,
              onTap: () {
                if (dest.route != currentPath) {
                  router.push(dest.route);
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _NavDestination {
  const _NavDestination(this.label, this.route, this.icon);

  final String label;
  final String route;
  final IconData icon;
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final _NavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: destination.label,
      child: InkWell(
        key: Key('top-bar-nav-${destination.label.toLowerCase()}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected
                ? CarPlayTheme.neonCyan.withValues(alpha: 0.16)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                destination.icon,
                size: 16,
                color: selected
                    ? CarPlayTheme.neonCyan
                    : CarPlayTheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                destination.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected
                      ? CarPlayTheme.neonCyan
                      : CarPlayTheme.onSurfaceVariant,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
