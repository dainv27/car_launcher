import 'package:flutter/material.dart';
import 'package:car_launcher/core/theme/carplay_theme.dart';
import 'package:car_launcher/features/app_drawer/presentation/widgets/app_icon_tile.dart';
import 'package:car_launcher/features/app_drawer/presentation/widgets/apps_grid_layout.dart';

/// Horizontal pager of app grids — swipe left/right between pages.
class AppsHorizontalPager extends StatefulWidget {
  const AppsHorizontalPager({
    super.key,
    required this.apps,
    required this.favorites,
    required this.onLaunch,
    required this.onToggleFavorite,
    this.onPageChanged,
  });

  final List<Map<String, String>> apps;
  final List<Map<String, String>> favorites;
  final void Function(String packageName) onLaunch;
  final void Function(Map<String, String> app, bool isFavorite) onToggleFavorite;
  final ValueChanged<int>? onPageChanged;

  @override
  State<AppsHorizontalPager> createState() => _AppsHorizontalPagerState();
}

class _AppsHorizontalPagerState extends State<AppsHorizontalPager> {
  PageController? _pageController;
  int _currentPage = 0;
  String? _layoutKey;

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  void _ensureController(int pageCount) {
    if (_pageController != null) return;
    _pageController = PageController(
      initialPage: _currentPage.clamp(0, pageCount - 1),
    );
  }

  void _syncPageForLayout(int pageCount) {
    if (_currentPage >= pageCount) {
      final nextPage = (pageCount - 1).clamp(0, pageCount);
      _currentPage = nextPage;
      if (_pageController?.hasClients ?? false) {
        _pageController!.jumpToPage(nextPage);
      }
    }
  }

  int _pageCount(int appCount, int itemsPerPage) {
    if (appCount == 0) return 1;
    return (appCount / itemsPerPage).ceil();
  }

  List<Map<String, String>> _appsForPage(
    List<Map<String, String>> apps,
    int pageIndex,
    int itemsPerPage,
  ) {
    final start = pageIndex * itemsPerPage;
    if (start >= apps.length) return const [];
    final end = (start + itemsPerPage).clamp(0, apps.length);
    return apps.sublist(start, end);
  }

  bool _isFavorite(String packageName) {
    return widget.favorites.any((f) => f['packageName'] == packageName);
  }

  @override
  Widget build(BuildContext context) {
    final orientation = MediaQuery.orientationOf(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = AppsGridLayout.resolve(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          orientation: orientation,
        );

        if (_layoutKey != layout.layoutKey) {
          _pageController?.dispose();
          _pageController = null;
          _layoutKey = layout.layoutKey;
        }

        final pageCount = _pageCount(widget.apps.length, layout.itemsPerPage);
        _syncPageForLayout(pageCount);
        _ensureController(pageCount);

        return Column(
          children: [
            Expanded(
              child: PageView.builder(
                key: ValueKey(layout.layoutKey),
                controller: _pageController,
                itemCount: pageCount,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                  widget.onPageChanged?.call(index);
                },
                itemBuilder: (context, pageIndex) {
                  final pageApps = _appsForPage(
                    widget.apps,
                    pageIndex,
                    layout.itemsPerPage,
                  );

                  return Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: layout.horizontalPadding,
                    ),
                    child: GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: layout.columns,
                        mainAxisSpacing: layout.mainAxisSpacing,
                        crossAxisSpacing: layout.crossAxisSpacing,
                        childAspectRatio: layout.childAspectRatio,
                      ),
                      itemCount: pageApps.length,
                      itemBuilder: (context, index) {
                        final app = pageApps[index];
                        final packageName = app['packageName'] ?? '';
                        final appName = app['appName'] ?? '';
                        final isFavorite = _isFavorite(packageName);

                        return AppIconTile(
                          appName: appName,
                          packageName: packageName,
                          iconBase64: app['iconBase64'],
                          iconSize: layout.iconSize,
                          labelFontSize: layout.labelFontSize,
                          isFavorite: isFavorite,
                          onTap: () => widget.onLaunch(packageName),
                          onLongPress: () =>
                              widget.onToggleFavorite(app, isFavorite),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
            if (pageCount > 1)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _PageDots(count: pageCount, current: _currentPage),
              ),
          ],
        );
      },
    );
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots({required this.count, required this.current});

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    final maxDots = 9;
    final showCount = count <= maxDots ? count : maxDots;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(showCount, (index) {
        final active = index == current.clamp(0, showCount - 1);
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 8 : 6,
          height: active ? 8 : 6,
          decoration: BoxDecoration(
            color: active
                ? Colors.white
                : CarPlayTheme.tertiaryText.withValues(alpha: 0.6),
            shape: BoxShape.circle,
          ),
        );
      }),
    );
  }
}
