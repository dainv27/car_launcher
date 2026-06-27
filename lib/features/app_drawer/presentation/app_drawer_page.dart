import 'package:car_launcher/features/launcher/data/launcher_service.dart';
import 'package:car_launcher/core/theme/carplay_theme.dart';
import 'package:car_launcher/features/app_drawer/presentation/providers/app_drawer_providers.dart';
import 'package:car_launcher/features/app_drawer/presentation/widgets/app_icon_tile.dart';
import 'package:car_launcher/features/app_drawer/presentation/widgets/apps_grid_layout.dart';
import 'package:car_launcher/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Nova Drive App Drawer — full-screen grid with sidebar nav and top search bar.
class AppDrawerPage extends ConsumerStatefulWidget {
  const AppDrawerPage({super.key});

  @override
  ConsumerState<AppDrawerPage> createState() => _AppDrawerPageState();
}

class _AppDrawerPageState extends ConsumerState<AppDrawerPage> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  void _launchApp(String packageName) {
    ref.read(launcherServiceProvider).launchApp(packageName);
    _goBack();
  }

  void _toggleFavorite(Map<String, String> app, bool isFavorite) {
    final packageName = app['packageName'] ?? '';
    if (isFavorite) {
      ref.read(favoriteAppsProvider.notifier).removeFavorite(packageName);
    } else {
      ref.read(favoriteAppsProvider.notifier).addFavorite(app);
    }
  }

  @override
  Widget build(BuildContext context) {
    final apps = ref.watch(filteredAppsProvider);
    final isLoading = ref.watch(appsLoadingProvider);
    final favorites = ref.watch(favoriteAppsProvider);
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // Ambient background glows
          Positioned(
            bottom: -20,
            right: -20,
            child: IgnorePointer(
              child: Container(
                width: 600,
                height: 600,
                decoration: BoxDecoration(shape: BoxShape.circle, color: CarPlayTheme.neonCyan.withValues(alpha: 0.05)),
              ),
            ),
          ),
          Positioned(
            top: 160,
            left: MediaQuery.of(context).size.width / 2 - 200,
            child: IgnorePointer(
              child: Container(
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: CarPlayTheme.primaryContainer.withValues(alpha: 0.05),
                ),
              ),
            ),
          ),
          // Main content column
          Column(
            children: [
              // ── Top App Bar ──
              _SearchAppBar(
                searchController: _searchController,
                onSearchChanged: (value) {
                  ref.read(searchQueryProvider.notifier).state = value;
                },
                onSearchClear: () {
                  _searchController.clear();
                  ref.read(searchQueryProvider.notifier).state = '';
                },
              ),
              // ── App Grid ──
              Expanded(
                child: isLoading
                    ? const _AppsLoadingState()
                    : apps.isEmpty
                    ? _AppsEmptyState(onRefresh: () => ref.read(installedAppsProvider.notifier).refresh())
                    : _AppGrid(
                        apps: apps,
                        favorites: favorites,
                        keyboardInset: keyboardInset,
                        onLaunch: _launchApp,
                        onToggleFavorite: _toggleFavorite,
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Top App Bar
// ═══════════════════════════════════════════════════════════════

class _SearchAppBar extends StatelessWidget {
  const _SearchAppBar({required this.searchController, required this.onSearchChanged, required this.onSearchClear});

  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: CarPlayTheme.gutter),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: _SearchBar(controller: searchController, onChanged: onSearchChanged, onClear: onSearchClear),
        ),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.controller, required this.onChanged, required this.onClear});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: CarPlayTheme.glassSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: CarPlayTheme.safetyWhite.withValues(alpha: 0.1)),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(
          color: CarPlayTheme.onSurface,
          fontSize: 14,
          fontWeight: FontWeight.w400,
          height: 20 / 14,
        ),
        decoration: InputDecoration(
          hintText: 'Search applications...',
          hintStyle: TextStyle(color: CarPlayTheme.onSurfaceVariant.withValues(alpha: 0.4), fontSize: 12),
          prefixIcon: const Icon(Icons.search, color: CarPlayTheme.onSurfaceVariant),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              if (value.text.isEmpty) return const SizedBox.shrink();
              return IconButton(
                onPressed: onClear,
                icon: const Icon(Icons.close, color: CarPlayTheme.onSurfaceVariant),
              );
            },
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// App Grid
// ═══════════════════════════════════════════════════════════════

class _AppGrid extends StatelessWidget {
  const _AppGrid({
    required this.apps,
    required this.favorites,
    required this.keyboardInset,
    required this.onLaunch,
    required this.onToggleFavorite,
  });

  final List<Map<String, String>> apps;
  final List<Map<String, String>> favorites;
  final double keyboardInset;
  final void Function(String packageName) onLaunch;
  final void Function(Map<String, String> app, bool isFavorite) onToggleFavorite;

  bool _isFavorite(String packageName) {
    return favorites.any((f) => f['packageName'] == packageName);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = AppsGridLayout.resolve(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          orientation: MediaQuery.orientationOf(context),
        );

        return GridView.builder(
          key: const Key('app-drawer-app-grid'),
          padding: EdgeInsets.fromLTRB(layout.horizontalPadding, 16, layout.horizontalPadding, 48 + keyboardInset),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: layout.columns,
            mainAxisSpacing: layout.mainAxisSpacing,
            crossAxisSpacing: layout.crossAxisSpacing,
            childAspectRatio: layout.childAspectRatio,
          ),
          itemCount: apps.length,
          itemBuilder: (context, index) {
            final app = apps[index];
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
              onTap: () => onLaunch(packageName),
              onLongPress: () => onToggleFavorite(app, isFavorite),
            );
          },
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Loading State
// ═══════════════════════════════════════════════════════════════

class _AppsLoadingState extends StatelessWidget {
  const _AppsLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(strokeWidth: 3, color: CarPlayTheme.neonCyan),
          ),
          SizedBox(height: 16),
          Text('Loading apps…', style: TextStyle(color: CarPlayTheme.onSurfaceVariant, fontSize: 16)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Empty State
// ═══════════════════════════════════════════════════════════════

class _AppsEmptyState extends StatelessWidget {
  const _AppsEmptyState({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.apps_rounded, color: CarPlayTheme.onSurfaceVariant, size: 56),
          const SizedBox(height: 16),
          const Text(
            'No apps found',
            style: TextStyle(color: CarPlayTheme.onSurface, fontSize: 18, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          const Text(
            'Try a different search or refresh the list',
            style: TextStyle(color: CarPlayTheme.onSurfaceVariant, fontSize: 14),
          ),
          const SizedBox(height: 20),
          TextButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded, color: CarPlayTheme.neonCyan),
            label: const Text('Refresh', style: TextStyle(color: CarPlayTheme.neonCyan, fontSize: 16)),
          ),
        ],
      ),
    );
  }
}
