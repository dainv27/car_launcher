import 'package:car_launcher/features/app_drawer/presentation/app_drawer_page.dart';
import 'package:car_launcher/features/dashboard/all_dashboard/map.dart';
import 'package:car_launcher/features/dashboard/all_dashboard/map_with_media.dart';
import 'package:car_launcher/features/dashboard/all_dashboard/map_with_youtube.dart';
import 'package:car_launcher/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:car_launcher/features/dashboard/presentation/widgets/bottom_status_bar.dart';
import 'package:car_launcher/features/dashboard/presentation/widgets/top_app_bar.dart';
import 'package:car_launcher/features/media/presentation/media_center_page.dart';
import 'package:car_launcher/features/settings/presentation/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  late final PageController _pageController;
  bool _programmaticChanging = false;

  final List<Widget> bodies = const [
    MediaCenterPage(),
    MapPage(),
    MapWithYoutube(),
    MapWithMedia(),
    AppDrawerPage(),
    SettingsPage(),
  ];

  final List<String> topBarTitles = ['Media Center', '', '', '', 'Apps', 'Settings'];

  @override
  void initState() {
    super.initState();

    final initialIndex = ref.read(dashboardIndexProvider);
    _pageController = PageController(initialPage: initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _animateToPage(int index) async {
    if (!_pageController.hasClients) return;

    _programmaticChanging = true;

    await _pageController.animateToPage(index, duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);

    _programmaticChanging = false;
  }

  @override
  Widget build(BuildContext context) {
    final index = ref.watch(dashboardIndexProvider);

    ref.listen<int>(dashboardIndexProvider, (previous, next) {
      if (previous == next) return;
      _animateToPage(next);
    });

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
