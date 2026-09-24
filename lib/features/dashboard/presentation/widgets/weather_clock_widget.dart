import 'package:car_launcher/features/dashboard/presentation/providers/weather_providers.dart';
import 'package:car_launcher/shared/data/weather_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:car_launcher/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:car_launcher/core/theme/launcher_palette.dart';

/// Weather & clock widget — bottom-right panel (4 columns).
/// Shows city name, temperature, weather condition, time, and date.
class WeatherClockWidget extends ConsumerWidget {
  const WeatherClockWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weatherAsync = ref.watch(weatherProvider);
    final clock = ref.watch(clockProvider);
    final now = DateTime.now();

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background
          Container(color: context.palette.glass),
          // ── Decorative blur circle ──
          Positioned(
            bottom: -40,
            right: -40,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                color: context.palette.accent.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
            ),
          ),
          // ── Content ──
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                // Left: weather
                Expanded(
                  child: weatherAsync.when(
                    data: (weather) => _buildWeather(context, weather),
                    loading: () => _buildWeatherLoading(context),
                    error: (_, _) => _buildWeatherError(context),
                  ),
                ),
                // Divider
                Container(
                  width: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  color: context.palette.foreground.withValues(alpha: 0.1),
                ),
                // Right: clock
                _buildClock(context, clock, now),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeather(BuildContext context, WeatherData? weather) {
    if (weather == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Weather',
            style: TextStyle(
              color: context.palette.textSecondary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.6,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '--°',
            style: TextStyle(
              color: context.palette.textPrimary,
              fontSize: 80,
              fontWeight: FontWeight.w700,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Set API key in Settings',
            style: TextStyle(color: context.palette.textTertiary, fontSize: 12),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // City name
        Text(
          weather.cityName,
          style: TextStyle(
            color: context.palette.textSecondary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.6,
          ),
        ),
        const SizedBox(height: 4),
        // Temperature + icon row
        Row(
          children: [
            Text(
              '${weather.temperature.round()}°',
              style: TextStyle(
                color: context.palette.textPrimary,
                fontSize: 80,
                fontWeight: FontWeight.w700,
                height: 1.0,
              ),
            ),
            const SizedBox(width: 16),
            Column(
              children: [
                Icon(
                  _weatherIcon(weather.iconCode),
                  color: context.palette.accent,
                  size: 48,
                ),
                const SizedBox(height: 4),
                Text(
                  weather.description.isNotEmpty
                      ? _capitalize(weather.description)
                      : 'Clear',
                  style: TextStyle(
                    color: context.palette.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWeatherLoading(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Loading…',
          style: TextStyle(
            color: context.palette.textSecondary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.6,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(
              context.palette.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWeatherError(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Weather',
          style: TextStyle(
            color: context.palette.textSecondary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.6,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.error_outline, color: context.palette.danger, size: 20),
            const SizedBox(width: 8),
            Text(
              'Unavailable',
              style: TextStyle(
                color: context.palette.textSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildClock(BuildContext context, String clock, DateTime now) {
    final dateStr = DateFormat('EEE, MMM d').format(now).toUpperCase();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Time
        Text(
          clock,
          style: TextStyle(
            color: context.palette.accent,
            fontSize: 80,
            fontWeight: FontWeight.w700,
            height: 1.0,
          ),
        ),
        const SizedBox(height: 8),
        // Date
        Text(
          dateStr,
          style: TextStyle(
            color: context.palette.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        // Page dots
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            return Container(
              width: 8,
              height: 8,
              margin: EdgeInsets.only(left: i > 0 ? 8 : 0),
              decoration: BoxDecoration(
                color: i == 0
                    ? context.palette.accent
                    : context.palette.foreground.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
            );
          }),
        ),
      ],
    );
  }

  IconData _weatherIcon(String iconCode) {
    if (iconCode.contains('01')) return Icons.wb_sunny;
    if (iconCode.contains('02')) return Icons.wb_cloudy;
    if (iconCode.contains('03') || iconCode.contains('04')) return Icons.cloud;
    if (iconCode.contains('09') || iconCode.contains('10')) {
      return Icons.water_drop;
    }
    if (iconCode.contains('11')) return Icons.flash_on;
    if (iconCode.contains('13')) return Icons.ac_unit;
    if (iconCode.contains('50')) return Icons.dehaze;
    return Icons.cloud;
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}
