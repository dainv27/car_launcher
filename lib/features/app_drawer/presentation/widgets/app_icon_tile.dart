import 'dart:convert';
import 'dart:typed_data';

import 'package:car_launcher/core/logging/app_logger.dart';
import 'package:car_launcher/core/logging/logging.dart';
import 'package:car_launcher/core/theme/carplay_theme.dart';
import 'package:car_launcher/features/app_drawer/presentation/providers/app_drawer_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Nova Drive glass-card app icon tile.
class AppIconTile extends ConsumerStatefulWidget {
  const AppIconTile({
    super.key,
    required this.appName,
    required this.packageName,
    required this.onTap,
    this.iconBase64,
    this.iconSize,
    this.labelFontSize,
    this.onLongPress,
    this.isFavorite = false,
    this.compact = false,
  });

  final String appName;
  final String packageName;
  final String? iconBase64;
  final double? iconSize;
  final double? labelFontSize;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isFavorite;
  final bool compact;

  @override
  ConsumerState<AppIconTile> createState() => _AppIconTileState();
}

class _AppIconTileState extends ConsumerState<AppIconTile> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final resolvedIconSize = widget.iconSize ?? (widget.compact ? 48.0 : 80.0);
    final resolvedLabelSize = widget.labelFontSize ?? (widget.compact ? 12.0 : 16.0);
    final cachedBytes = _decodeIcon(widget.iconBase64);
    final iconColors = _colorsForPackage(widget.packageName);

    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: resolvedIconSize,
              height: resolvedIconSize,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Align(
                    alignment: Alignment.center,
                    child: cachedBytes != null
                        ? _AppIconImage(
                            bytes: cachedBytes,
                            appName: widget.appName,
                            packageName: widget.packageName,
                            size: resolvedIconSize,
                            colors: iconColors,
                          )
                        : _AsyncAppIcon(
                            ref: ref,
                            packageName: widget.packageName,
                            appName: widget.appName,
                            size: resolvedIconSize,
                            colors: iconColors,
                          ),
                  ),
                  if (widget.isFavorite)
                    Positioned(
                      right: -4,
                      bottom: -4,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.85),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.black, width: 1.5),
                        ),
                        child: const Icon(Icons.star_rounded, color: CarPlayTheme.favoriteAccent, size: 14),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                widget.appName,
                style: TextStyle(
                  fontFamily: 'Inter',
                  color: CarPlayTheme.onSurface,
                  fontSize: resolvedLabelSize,
                  fontWeight: FontWeight.w600,
                  height: 20 / 16,
                  letterSpacing: 0.05 * resolvedLabelSize,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Uint8List? _decodeIcon(String? base64) {
    if (base64 == null || base64.isEmpty) return null;
    try {
      return base64Decode(base64);
    } catch (e) {
      AppLogger.instance.d('Icon decode failed', tag: 'APP_DRAWER', error: e);
      return null;
    }
  }

  /// Deterministic gradient colors from package name hash.
  static List<Color> _colorsForPackage(String packageName) {
    final hash = packageName.codeUnits.fold<int>(0, (a, b) => a + b);
    final hue = (hash * 37) % 360;
    return [
      HSLColor.fromAHSL(1, hue.toDouble(), 0.55, 0.48).toColor(),
      HSLColor.fromAHSL(1, (hue + 24) % 360, 0.50, 0.38).toColor(),
    ];
  }
}

class _AsyncAppIcon extends StatelessWidget {
  const _AsyncAppIcon({
    required this.ref,
    required this.packageName,
    required this.appName,
    required this.size,
    required this.colors,
  });

  final WidgetRef ref;
  final String packageName;
  final String appName;
  final double size;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    final iconAsync = ref.watch(appIconProvider(packageName));

    return iconAsync.when(
      data: (bytes) =>
          _AppIconImage(bytes: bytes, appName: appName, packageName: packageName, size: size, colors: colors),
      loading: () => _AppIconPlaceholder(size: size, colors: colors),
      error: (_, _) => _AppIconFallback(appName: appName, size: size, colors: colors),
    );
  }
}

class _AppIconImage extends StatelessWidget {
  const _AppIconImage({
    required this.bytes,
    required this.appName,
    required this.packageName,
    required this.size,
    required this.colors,
  });

  final Uint8List? bytes;
  final String appName;
  final String packageName;
  final double size;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    if (bytes == null || bytes!.isEmpty) {
      return _AppIconFallback(appName: appName, size: size, colors: colors);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.memory(
        bytes!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, _, _) => _AppIconFallback(appName: appName, size: size, colors: colors),
      ),
    );
  }
}

class _AppIconPlaceholder extends StatelessWidget {
  const _AppIconPlaceholder({required this.size, required this.colors});

  final double size;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(
        child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54)),
      ),
    );
  }
}

class _AppIconFallback extends StatelessWidget {
  const _AppIconFallback({required this.appName, required this.size, required this.colors});

  final String appName;
  final double size;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    final letter = _initial(appName);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: colors.first.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: TextStyle(color: Colors.white, fontSize: size * 0.42, fontWeight: FontWeight.w600),
      ),
    );
  }

  static String _initial(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed.substring(0, 1).toUpperCase();
  }
}
