import 'package:car_launcher/features/dashboard/all_dashboard/dashboard_layout_metrics.dart';
import 'package:car_launcher/features/dashboard/presentation/providers/carplay_settings_providers.dart';
import 'package:car_launcher/features/dashboard/presentation/widgets/navigation_map_widget.dart';
import 'package:car_launcher/features/dashboard/presentation/widgets/youtube_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MapWithYoutube extends ConsumerWidget {
  const MapWithYoutube({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              final panelWidth = constraints.maxWidth - metrics.gap;
              final youtubeWidth = panelWidth * metrics.youtubeWidthFactor;
              return Row(
                children: [
                  Expanded(
                    key: const Key('dashboard-map-card'),
                    child: const NavigationMapWidget(),
                  ),
                  SizedBox(width: metrics.gap),
                  SizedBox(width: youtubeWidth, child: const YoutubeWidget()),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
