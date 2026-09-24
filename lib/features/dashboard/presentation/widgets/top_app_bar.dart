import 'package:car_launcher/core/native/native_bridge.dart';
import 'package:car_launcher/core/theme/carplay_theme.dart';
import 'package:car_launcher/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:car_launcher/features/media/data/media_controller.dart';
import 'package:car_launcher/shared/data/location_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:car_launcher/core/theme/launcher_palette.dart';

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
                Expanded(child: _buildLeftSection(context, location)),
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

  Widget _buildLeftSection(
    BuildContext context,
    AsyncValue<LocationInfo?> location,
  ) {
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
        Container(width: 1, height: 24, color: context.palette.border),
        const SizedBox(width: 16),
        if (title.isEmpty) ...[
          Icon(Icons.navigation, color: context.palette.accent, size: 14),
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
            style: TextStyle(
              color: context.palette.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
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
            color: context.palette.textSecondary,
            size: 20,
          ),
          padding: EdgeInsets.zero,
          constraints: _buttonConstraints,
        ),
        _gap,
        IconButton(
          tooltip: 'Voice assistant',
          onPressed: () => NativeBridge.call<bool>('launchVoiceAssistant'),
          icon: Icon(
            Icons.mic_outlined,
            color: context.palette.textSecondary,
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
  /// Only durations are read in [initState], before inherited widgets are
  /// available, so any palette works there.
  static final _fallbackPalette = LauncherPalette.dark(const Color(0x00000000));

  late final AnimationController _controller;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    final style = _TrackingDotStyle.from(widget.tracking, _fallbackPalette);
    _controller = AnimationController(vsync: this, duration: style.duration);
    _pulse = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _syncAnimation(style);
  }

  @override
  void didUpdateWidget(covariant _TrackingStatusDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAnimation(_TrackingDotStyle.from(widget.tracking, context.palette));
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
    final style = _TrackingDotStyle.from(widget.tracking, context.palette);

    // Isolated layer: when the dot does pulse (only while syncing), it must
    // not repaint the rest of the top bar.
    return RepaintBoundary(
      child: Tooltip(
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
                    color: context.palette.foreground.withValues(alpha: 0.12),
                    width: 0.6,
                  ),
                  boxShadow: style.glow
                      ? [
                          BoxShadow(
                            color: style.color.withValues(
                              alpha: 0.46 * opacity,
                            ),
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

  /// Only the short-lived syncing state pulses. A never-ending animation
  /// forces a frame on every vsync, and with the hybrid-composition Maps /
  /// YouTube panes each frame also costs main-thread composition — an
  /// always-pulsing dot kept the idle launcher at ~50% main-thread CPU and
  /// ~20 fps with 38% janky frames on the Bengal head unit.
  factory _TrackingDotStyle.from(
    VehicleTrackingState tracking,
    LauncherPalette palette,
  ) {
    if (!tracking.enabled) {
      return _TrackingDotStyle(
        color: palette.textSecondary,
        label: 'Vehicle tracking paused',
        duration: const Duration(milliseconds: 1800),
        animated: false,
        glow: false,
        baseOpacity: 0.52,
        opacityRange: 0,
      );
    }

    if (tracking.lastSyncError != null) {
      return _TrackingDotStyle(
        color: palette.danger,
        label: 'Vehicle tracking active, sync needs attention',
        duration: Duration(milliseconds: 1200),
        animated: false,
        baseOpacity: 0.58,
        opacityRange: 0.34,
        glowRadius: 5,
        glowRange: 7,
      );
    }

    if (tracking.isSyncing) {
      return _TrackingDotStyle(
        color: palette.accent,
        label: 'Vehicle tracking syncing',
        duration: const Duration(milliseconds: 900),
        animated: true,
        baseOpacity: 0.54,
        opacityRange: 0.42,
        glowRadius: 6,
        glowRange: 10,
      );
    }

    if (tracking.pendingSyncCount > 0) {
      return _TrackingDotStyle(
        color: palette.warning,
        label:
            'Vehicle tracking active, ${tracking.pendingSyncCount} pending sync',
        duration: const Duration(milliseconds: 1500),
        animated: false,
        baseOpacity: 0.58,
        opacityRange: 0.36,
        glowRadius: 5,
        glowRange: 7,
      );
    }

    return _TrackingDotStyle(
      color: palette.success,
      label: 'Vehicle tracking active',
      duration: Duration(milliseconds: 2300),
      animated: false,
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
              color: context.palette.accent,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          const SizedBox(width: 11),
          Flexible(
            child: Text(
              clock,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.palette.textPrimary,
                fontSize: 25,
                height: 1,
                fontWeight: FontWeight.w500,
                letterSpacing: -0.6,
                fontFeatures: const [FontFeature.tabularFigures()],
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
      (d) =>
          d.route == currentPath ||
          (d.route != '/' && currentPath.startsWith(d.route)),
      orElse: () => _destinations.first,
    );

    return DecoratedBox(
      key: const Key('top-bar-navigation-menu'),
      decoration: BoxDecoration(
        color: context.palette.glass,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.palette.border),
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
            color: selected ? context.palette.accentSoft : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                destination.icon,
                size: 16,
                color: selected
                    ? context.palette.accent
                    : context.palette.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                destination.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected
                      ? context.palette.accent
                      : context.palette.textSecondary,
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
