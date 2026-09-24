import 'package:car_launcher/features/app_drawer/presentation/app_drawer_page.dart';
import 'package:car_launcher/features/dashboard/all_dashboard/map.dart';
import 'package:car_launcher/features/dashboard/all_dashboard/map_with_media.dart';
import 'package:car_launcher/features/dashboard/all_dashboard/map_with_youtube.dart';
import 'package:car_launcher/features/dashboard/presentation/providers/carplay_settings_providers.dart';
import 'package:car_launcher/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:car_launcher/features/dashboard/presentation/widgets/bottom_status_bar.dart';
import 'package:car_launcher/features/dashboard/presentation/widgets/top_app_bar.dart';
import 'package:car_launcher/features/layout/domain/layout_model.dart';
import 'package:car_launcher/features/layout/presentation/layout_engine.dart';
import 'package:car_launcher/features/layout/presentation/providers/layout_providers.dart';
import 'package:car_launcher/features/media/presentation/media_center_page.dart';
import 'package:car_launcher/features/settings/presentation/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The "home" slot of the dashboard PageView is driven by
/// [carPlaySettingsProvider]'s `homeViewMode` instead of being fixed, so
/// choosing a layout style in Settings → Dashboard actually changes what
/// shows here.
Widget _homeContentFor(HomeViewMode mode, LayoutModel layout) {
  switch (mode) {
    case HomeViewMode.dashboard01:
      return const MapPage();
    case HomeViewMode.dashboard02:
      return const MapWithMedia();
    case HomeViewMode.dashboard03:
      return const MapWithYoutube();
    case HomeViewMode.multiApp:
      return LayoutEngine(model: layout);
  }
}

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  late final PageController _pageController;
  bool _programmaticChanging = false;

  @override
  void initState() {
    super.initState();

    final initialIndex = ref.read(dashboardIndexProvider);
    _pageController = PageController(
      initialPage: initialIndex.clamp(0, _pageCount - 1),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  static const int _pageCount = 4;

  Future<void> _animateToPage(int index) async {
    if (!_pageController.hasClients) return;

    _programmaticChanging = true;

    await _pageController.animateToPage(
      index.clamp(0, _pageCount - 1),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );

    _programmaticChanging = false;
  }

  @override
  Widget build(BuildContext context) {
    final index = ref.watch(dashboardIndexProvider).clamp(0, _pageCount - 1);
    final homeViewMode = ref.watch(carPlaySettingsProvider).homeViewMode;
    final layout = ref.watch(layoutProvider);

    ref.listen<int>(dashboardIndexProvider, (previous, next) {
      if (previous == next) return;
      _animateToPage(next);
    });

    final bodies = <Widget>[
      const MediaCenterPage(),
      _homeContentFor(homeViewMode, layout),
      const AppDrawerPage(),
      const SettingsPage(),
    ];
    final topBarTitles = [
      'Media Center',
      homeViewMode == HomeViewMode.multiApp ? 'Multi App' : '',
      'Apps',
      'Settings',
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          TopAppBar(title: topBarTitles[index]),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const BouncingScrollPhysics(parent: PageScrollPhysics()),
              onPageChanged: (pageIndex) {
                if (_programmaticChanging) return;

                ref.read(dashboardIndexProvider.notifier).setIndex(pageIndex);
              },
              children: bodies,
            ),
          ),
          const SizedBox(height: 40, child: BottomStatusBar()),
        ],
      ),
    );
  }
}
