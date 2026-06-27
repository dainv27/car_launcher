import 'package:car_launcher/core/logging/app_logger.dart';
import 'package:car_launcher/core/theme/carplay_theme.dart';
import 'package:car_launcher/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:car_launcher/features/dashboard/presentation/widgets/connectivity_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Fixed footer showing live Android system state.
///
/// Vehicle climate and TPMS are intentionally omitted until a vendor/OBD data
/// source is configured. Displaying invented vehicle data is unsafe.
class BottomStatusBar extends ConsumerWidget {
  const BottomStatusBar({super.key});

  static const double height = 48.0;
  static const int dashboardLength = 6;
  static const _gap = SizedBox(width: CarPlayTheme.widgetGap);
  static const _buttonConstraints = BoxConstraints(minWidth: 30);

  Widget _destinationButton({
    required Key key,
    required String tooltip,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      key: key,
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, color: CarPlayTheme.onSurfaceVariant),
      padding: EdgeInsets.zero,
      constraints: _buttonConstraints,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectivity = ref.watch(connectivityStatusProvider);
    final dashboardIndex = ref.watch(dashboardIndexProvider);
    final online = connectivity['validated'] == true;

    return Container(
      height: height,
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: CarPlayTheme.neonCyan.withValues(alpha: 0.14)),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: CarPlayTheme.gutter),
        child: Row(
          children: [
            Container(
              alignment: Alignment.centerLeft,
              width: 200,
              child: _StatusItem(
                child: Row(
                  children: [
                    _destinationButton(
                      key: const Key('top-bar-home'),
                      tooltip: 'Home',
                      icon: Icons.home_outlined,
                      onPressed: () =>
                          ref.read(dashboardIndexProvider.notifier).reset(),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: _HorizontalSwipeDetector(
                child: Container(
                  width: double.infinity,
                  height: double.infinity,
                  color: Colors.transparent,
                  child: Center(
                    child: _PageIndicator(
                      count: dashboardLength,
                      selectedIndex: dashboardIndex,
                    ),
                  ),
                ),
                onSwipeLeft: () {
                  ref
                      .read(dashboardIndexProvider.notifier)
                      .setIndex(
                        dashboardIndex < dashboardLength - 1
                            ? dashboardIndex + 1
                            : 4,
                      );
                  AppLogger.instance.i('Swipe left', tag: 'BOTTOM_BAR');
                },
                onSwipeRight: () {
                  ref
                      .read(dashboardIndexProvider.notifier)
                      .setIndex(dashboardIndex > 0 ? dashboardIndex - 1 : 0);
                  AppLogger.instance.i('Swipe right', tag: 'BOTTOM_BAR');
                },
              ),
            ),
            Container(
              alignment: Alignment.centerRight,
              width: 200,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ConnectivityIndicator(
                    status: connectivity,
                    showLabels: false,
                  ),
                  _gap,
                  _StatusItem(
                    child: Tooltip(
                      message: online ? 'Online' : 'Offline',
                      child: Semantics(
                        label: online ? 'Online' : 'Offline',
                        child: Icon(
                          online
                              ? Icons.cloud_done_outlined
                              : Icons.cloud_off_outlined,
                          key: const Key('bottom-bar-internet-status'),
                          color: online
                              ? CarPlayTheme.neonCyan
                              : CarPlayTheme.onSurfaceVariant,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusItem extends StatelessWidget {
  const _StatusItem({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return child;
  }
}

class _HorizontalSwipeDetector extends StatelessWidget {
  const _HorizontalSwipeDetector({
    required this.child,
    this.onSwipeLeft,
    this.onSwipeRight,
  });

  final Widget child;
  final VoidCallback? onSwipeLeft;
  final VoidCallback? onSwipeRight;

  @override
  Widget build(BuildContext context) {
    double startX = 0;
    double endX = 0;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,

      onHorizontalDragStart: (details) {
        startX = details.globalPosition.dx;
      },

      onHorizontalDragEnd: (details) {
        endX = details.globalPosition.dx;

        if (endX - startX < -50) {
          onSwipeLeft?.call();
        } else if (endX - startX > 50) {
          onSwipeRight?.call();
        }
      },

      child: child,
    );
  }
}

class _PageIndicator extends StatelessWidget {
  const _PageIndicator({required this.count, required this.selectedIndex});

  final int count;
  final int selectedIndex;
  static const double _dotSize = 8;
  static const double _activeDotWidth = 24;
  static const double _spacing = 8;
  static const Color _activeColor = Colors.white;
  static const Color _inactiveColor = Colors.white38;

  @override
  Widget build(BuildContext context) {
    if (count <= 1) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        count,
        (index) => AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: _spacing / 2),
          width: index == selectedIndex ? _activeDotWidth : _dotSize,
          height: _dotSize,
          decoration: BoxDecoration(
            color: index == selectedIndex ? _activeColor : _inactiveColor,
            borderRadius: BorderRadius.circular(_dotSize),
          ),
        ),
      ),
    );
  }
}
