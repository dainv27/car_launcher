import 'package:car_launcher/shared/data/location_service.dart';
import 'package:car_launcher/shared/widgets/car_responsive.dart';
import 'package:car_launcher/core/theme/carplay_theme.dart';
import 'package:car_launcher/features/dashboard/all_dashboard/dashboard_layout_metrics.dart';
import 'package:car_launcher/features/dashboard/presentation/providers/carplay_settings_providers.dart';
import 'package:car_launcher/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:car_launcher/features/dashboard/presentation/providers/weather_providers.dart';
import 'package:car_launcher/features/dashboard/presentation/widgets/glass_panel.dart';
import 'package:car_launcher/features/dashboard/presentation/widgets/navigation_map_widget.dart';
import 'package:car_launcher/features/media/presentation/providers/media_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class MapWithMedia extends ConsumerWidget {
  const MapWithMedia({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final compact = CarResponsive.isCompact(context);
    final metrics = DashboardLayoutMetrics.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () =>
          ref.read(overlayVisibleProvider.notifier).onUserInteraction(),
      onPanDown: (_) =>
          ref.read(overlayVisibleProvider.notifier).onUserInteraction(),
      child: ColoredBox(
        color: Colors.transparent,
        child: Padding(
          key: const Key('dashboard-content-grid'),
          padding: EdgeInsets.symmetric(horizontal: metrics.outerPadding),
          child: Row(
            children: [
              Expanded(
                flex: compact ? 7 : 8,
                child: GlassPanel(
                  key: const Key('dashboard-map-card'),
                  padding: EdgeInsets.zero,
                  child: const NavigationMapWidget(),
                ),
              ),
              SizedBox(width: metrics.gap),
              Expanded(
                flex: compact ? 5 : 4,
                child: Column(
                  children: [
                    Expanded(
                      child: GlassPanel(
                        key: const Key('dashboard-media-card'),
                        child: _DashboardMediaCard(
                          onOpen: () => context.go('/media'),
                        ),
                      ),
                    ),
                    SizedBox(height: metrics.gap),
                    const Expanded(
                      child: GlassPanel(
                        key: Key('dashboard-weather-card'),
                        padding: EdgeInsets.zero,
                        child: _DashboardWeatherCard(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardMediaCard extends ConsumerWidget {
  const _DashboardMediaCard({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(mediaSessionProvider);
    final controller = ref.read(mediaControllerProvider.notifier);
    final compact = CarResponsive.isCompact(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final short = constraints.maxHeight < 190;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!short)
                  Row(
                    children: [
                      const Icon(
                        Icons.graphic_eq,
                        color: CarPlayTheme.neonCyan,
                      ),
                      if (!compact) ...[
                        const SizedBox(width: 8),
                        const Text(
                          'Spatial Audio Active',
                          style: TextStyle(color: CarPlayTheme.neonCyan),
                        ),
                      ],
                    ],
                  ),
                if (!short) const Spacer(),
                Text(
                  session.title.isEmpty ? 'No media playing' : session.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: short ? 20 : 24,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  session.artist.isEmpty ? 'Open Media Center' : session.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: CarPlayTheme.onSurfaceVariant),
                ),
                SizedBox(height: short ? 8 : 20),
                LinearProgressIndicator(
                  value: session.progress,
                  minHeight: short ? 4 : 8,
                  borderRadius: BorderRadius.circular(999),
                  color: CarPlayTheme.neonCyan,
                  backgroundColor: Colors.white12,
                ),
                SizedBox(height: short ? 4 : 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      onPressed: controller.previous,
                      icon: const Icon(
                        Icons.skip_previous,
                        color: Colors.white,
                      ),
                    ),
                    IconButton.filled(
                      onPressed: controller.playPause,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white,
                      ),
                      icon: Icon(
                        session.isPlaying ? Icons.pause : Icons.play_arrow,
                        color: CarPlayTheme.deepObsidian,
                      ),
                    ),
                    IconButton(
                      onPressed: controller.next,
                      icon: const Icon(Icons.skip_next, color: Colors.white),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DashboardWeatherCard extends ConsumerWidget {
  const _DashboardWeatherCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AsyncValue<LocationInfo?>>(currentLocationProvider, (
      previous,
      next,
    ) {
      final location = next.valueOrNull;
      if (location != null && location != previous?.valueOrNull) {
        ref
            .read(weatherProvider.notifier)
            .refreshForCoords(location.latitude, location.longitude);
      }
    });
    final clock = ref.watch(clockProvider);
    final location = ref.watch(currentLocationProvider).valueOrNull;
    final weather = ref.watch(weatherProvider).valueOrNull;
    final now = DateTime.now();
    const muted = CarPlayTheme.onSurfaceVariant;
    final placeName = location?.displayName.isNotEmpty == true
        ? location!.displayName
        : weather?.cityName.isNotEmpty == true
        ? weather!.cityName
        : 'Current location';
    final temperature = weather == null
        ? '--°'
        : '${weather.temperature.round()}°';
    final description = weather?.description.isNotEmpty == true
        ? weather!.description
        : 'Weather data unavailable';

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 390;
        return Stack(
          children: [
            Positioned(
              right: -42,
              bottom: -64,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: CarPlayTheme.neonCyan.withValues(alpha: 0.08),
                      blurRadius: 70,
                      spreadRadius: 22,
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 16 : 24,
                vertical: compact ? 14 : 20,
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: compact ? 5 : 6,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              size: 16,
                              color: CarPlayTheme.neonCyan,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                placeName.toUpperCase(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: muted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.6,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: compact ? 6 : 10),
                        Row(
                          children: [
                            Icon(
                              _weatherIcon(weather?.iconCode),
                              color: CarPlayTheme.neonCyan,
                              size: compact ? 30 : 42,
                            ),
                            SizedBox(width: compact ? 6 : 12),
                            Expanded(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  temperature,
                                  key: const Key(
                                    'dashboard-weather-temperature',
                                  ),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: compact ? 36 : 50,
                                    height: 1,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: -2,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: muted, fontSize: 14),
                        ),
                        if (weather != null && !compact) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _WeatherMetric(
                                icon: Icons.water_drop_outlined,
                                value: '${weather.humidity}%',
                              ),
                              const SizedBox(width: 16),
                              _WeatherMetric(
                                icon: Icons.air,
                                value:
                                    '${weather.windSpeed.toStringAsFixed(1)} m/s',
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    width: 1,
                    height: compact ? 88 : 112,
                    color: Colors.white12,
                  ),
                  SizedBox(width: compact ? 12 : 24),
                  Expanded(
                    flex: 4,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          compact ? 'TIME' : 'LOCAL TIME',
                          style: TextStyle(
                            color: CarPlayTheme.neonCyan,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.8,
                          ),
                        ),
                        const SizedBox(height: 6),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            clock,
                            key: const Key('dashboard-clock-time'),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: compact ? 32 : 46,
                              height: 1,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -1,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _formattedDate(now),
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            color: muted,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  static IconData _weatherIcon(String? code) {
    if (code == null || code.isEmpty) return Icons.cloud_outlined;
    if (code.startsWith('01')) return Icons.wb_sunny_outlined;
    if (code.startsWith('09') || code.startsWith('10')) {
      return Icons.water_drop_outlined;
    }
    if (code.startsWith('11')) return Icons.thunderstorm_outlined;
    if (code.startsWith('13')) return Icons.ac_unit;
    if (code.startsWith('50')) return Icons.foggy;
    return Icons.cloud_outlined;
  }

  static String _formattedDate(DateTime date) {
    const weekdays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    const months = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];
    return '${weekdays[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}';
  }
}

class _WeatherMetric extends StatelessWidget {
  const _WeatherMetric({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: CarPlayTheme.neonCyan),
        const SizedBox(width: 5),
        Text(
          value,
          style: const TextStyle(
            color: CarPlayTheme.onSurfaceVariant,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
