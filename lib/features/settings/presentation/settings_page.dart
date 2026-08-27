import 'dart:io';

import 'package:car_launcher/features/launcher/data/launcher_service.dart';
import 'package:car_launcher/shared/widgets/car_responsive.dart';
import 'package:car_launcher/core/theme/app_theme.dart';
import 'package:car_launcher/core/theme/carplay_theme.dart';
import 'package:car_launcher/core/theme/launcher_appearance.dart';
import 'package:car_launcher/features/account/presentation/providers/account_providers.dart';
import 'package:car_launcher/features/account/presentation/widgets/login_required.dart';
import 'package:car_launcher/features/dashboard/presentation/providers/carplay_settings_providers.dart';
import 'package:car_launcher/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:car_launcher/features/dashboard/presentation/widgets/vehicle_tracking_card.dart';
import 'package:car_launcher/features/layout/domain/layout_model.dart';
import 'package:car_launcher/features/layout/presentation/providers/layout_providers.dart';
import 'package:car_launcher/features/settings/presentation/providers/brightness_provider.dart';
import 'package:car_launcher/features/settings/presentation/widgets/weather_settings_dialog.dart';
import 'package:car_launcher/features/theme/presentation/providers/launcher_appearance_provider.dart';
import 'package:car_launcher/features/theme/presentation/providers/theme_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

// ═════════════════════════════════════════════════════════════════════════════
// Settings page — two-panel layout matching Settings.html design
// ═════════════════════════════════════════════════════════════════════════════

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key, this.initialCategory = 0});

  final int initialCategory;

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  late int _selectedCategory;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory.clamp(0, 8);
  }

  @override
  Widget build(BuildContext context) {
    // Auto-select Account section when login just succeeded
    ref.listen(loginSuccessFlagProvider, (previous, next) {
      if (next == true) {
        ref.read(loginSuccessFlagProvider.notifier).state = false;
        setState(() => _selectedCategory = 5); // Account section
      }
    });
    final compact = CarResponsive.isCompact(context);
    final ultraCompact = MediaQuery.sizeOf(context).width < 1100;
    final short = CarResponsive.isShort(context);
    final useCompactCategories = ultraCompact || short;
    final gap = CarResponsive.gap(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: compact ? 16 : 0),
              child: useCompactCategories
                  ? Column(
                      children: [
                        _CompactCategoryBar(
                          selectedIndex: _selectedCategory,
                          onSelect: (i) =>
                              setState(() => _selectedCategory = i),
                        ),
                        SizedBox(height: gap),
                        Expanded(child: _buildKeyedDetailArea(context)),
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: compact ? 240 : 350,
                          child: _CategorySidebar(
                            selectedIndex: _selectedCategory,
                            onSelect: (i) =>
                                setState(() => _selectedCategory = i),
                          ),
                        ),
                        SizedBox(width: gap),
                        Expanded(child: _buildKeyedDetailArea(context)),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyedDetailArea(BuildContext context) {
    return KeyedSubtree(
      key: const Key('settings-detail-area'),
      child: _buildDetailArea(context),
    );
  }

  // ── Detail Area ──────────────────────────────────────────────────────────

  Widget _buildDetailArea(BuildContext context) {
    switch (_selectedCategory) {
      case 0:
        return _AppearanceSection();
      case 1:
        return _DashboardSection();
      case 2:
        return _NavigationSection();
      case 3:
        return _MediaSection();
      case 4:
        return _ConnectivitySection();
      case 5:
        return const _AccountSection();
      case 6:
        return _SystemInfoSection();
      case 7:
        return const _VehicleSection();
      case 8:
        return const _TrackingSection();
      default:
        return _AppearanceSection();
    }
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Category Sidebar
// ═════════════════════════════════════════════════════════════════════════════

class _CategorySidebar extends StatelessWidget {
  const _CategorySidebar({required this.selectedIndex, required this.onSelect});

  final int selectedIndex;
  final ValueChanged<int> onSelect;

  static const _categories = [
    _CategoryItem(Icons.palette, 'Appearance'),
    _CategoryItem(Icons.dashboard_outlined, 'Dashboard'),
    _CategoryItem(Icons.explore_outlined, 'Navigation'),
    _CategoryItem(Icons.speaker_outlined, 'Media & Sound'),
    _CategoryItem(Icons.wifi_outlined, 'Connectivity'),
    _CategoryItem(Icons.person_outlined, 'Account'),
    _CategoryItem(Icons.info_outlined, 'System Info'),
    _CategoryItem(Icons.directions_car_outlined, 'Vehicle'),
    _CategoryItem(Icons.route_outlined, 'Tracking'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < _categories.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: SizedBox(
              height: 48,
              child: _CategoryButton(
                item: _categories[i],
                isSelected: i == selectedIndex,
                onTap: () => onSelect(i),
                height: 48,
              ),
            ),
          ),
      ],
    );
  }
}

class _CompactCategoryBar extends StatelessWidget {
  const _CompactCategoryBar({
    required this.selectedIndex,
    required this.onSelect,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const Key('settings-category-rail'),
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _CategorySidebar._categories.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = _CategorySidebar._categories[index];
          final selected = index == selectedIndex;
          return InkWell(
            onTap: () => onSelect(index),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: selected
                    ? CarPlayTheme.neonCyan.withValues(alpha: 0.14)
                    : CarPlayTheme.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected
                      ? CarPlayTheme.neonCyan
                      : Colors.white.withValues(alpha: 0.1),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    item.icon,
                    color: selected
                        ? CarPlayTheme.neonCyan
                        : CarPlayTheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    item.label,
                    style: TextStyle(
                      color: selected
                          ? CarPlayTheme.safetyWhite
                          : CarPlayTheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CategoryItem {
  const _CategoryItem(this.icon, this.label);

  final IconData icon;
  final String label;
}

class _CategoryButton extends StatelessWidget {
  const _CategoryButton({
    required this.item,
    required this.isSelected,
    required this.onTap,
    required this.height,
  });

  final _CategoryItem item;
  final bool isSelected;
  final VoidCallback onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        height: height,
        decoration: BoxDecoration(
          color: isSelected
              ? CarPlayTheme.surfaceBright
              : CarPlayTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withAlpha(26)),
        ),
        child: Stack(
          children: [
            if (isSelected)
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: 4,
                  height: 40,
                  decoration: BoxDecoration(
                    color: CarPlayTheme.surfaceVariant,
                    boxShadow: [
                      BoxShadow(
                        color: CarPlayTheme.neonCyan.withAlpha(180),
                        blurRadius: 15,
                      ),
                    ],
                  ),
                ),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  const SizedBox(width: 24),
                  Icon(
                    item.icon,
                    size: 32,
                    color: isSelected
                        ? CarPlayTheme.neonCyan
                        : CarPlayTheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 16),
                  Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? CarPlayTheme.safetyWhite
                          : CarPlayTheme.onSurfaceVariant,
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

// ═════════════════════════════════════════════════════════════════════════════
// Glass Panel (reusable card surface)
// ═════════════════════════════════════════════════════════════════════════════

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({super.key, required this.child})
    : padding = const EdgeInsets.all(24);

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: CarPlayTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withAlpha(26)),
      ),
      padding: padding,
      child: child,
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Section Header
// ═════════════════════════════════════════════════════════════════════════════

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w600,
              color: CarPlayTheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: TextStyle(
              fontSize: 16,
              color: CarPlayTheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Neon Toggle Switch
// ═════════════════════════════════════════════════════════════════════════════

class _NeonToggle extends StatelessWidget {
  const _NeonToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 56,
        height: 30,
        decoration: BoxDecoration(
          color: value
              ? CarPlayTheme.neonCyan
              : CarPlayTheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(15),
          boxShadow: value
              ? [
                  BoxShadow(
                    color: CarPlayTheme.neonCyan.withAlpha(77),
                    blurRadius: 15,
                    spreadRadius: 0,
                  ),
                ]
              : null,
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 24,
            height: 24,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Neon Slider
// ═════════════════════════════════════════════════════════════════════════════

class _NeonSlider extends StatefulWidget {
  const _NeonSlider({
    required this.label,
    required this.icon,
    required this.initialValue,
    required this.onChanged,
  });

  final String label;
  final IconData icon;
  final double initialValue;
  final ValueChanged<double> onChanged;

  @override
  State<_NeonSlider> createState() => _NeonSliderState();
}

class _NeonSliderState extends State<_NeonSlider> {
  late double _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initialValue;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(widget.icon, size: 18, color: CarPlayTheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Text(
              widget.label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: CarPlayTheme.onSurface,
              ),
            ),
            const Spacer(),
            Text(
              '${_value.round()}%',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: CarPlayTheme.neonCyan,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 32,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              return GestureDetector(
                onTapDown: (d) => _updateValue(d.localPosition.dx, width),
                onPanUpdate: (d) => _updateValue(d.localPosition.dx, width),
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    // Track
                    Container(
                      height: 10,
                      width: width,
                      decoration: BoxDecoration(
                        color: CarPlayTheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                    // Fill
                    Container(
                      height: 10,
                      width: width * _value / 100,
                      decoration: BoxDecoration(
                        color: CarPlayTheme.neonCyan,
                        borderRadius: BorderRadius.circular(5),
                        boxShadow: [
                          BoxShadow(
                            color: CarPlayTheme.neonCyan.withAlpha(77),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                    ),
                    // Thumb
                    Positioned(
                      left: (width - 20) * _value / 100,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _updateValue(double dx, double width) {
    final v = (dx / width * 100).clamp(0.0, 100.0);
    setState(() => _value = v);
    widget.onChanged(v);
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Appearance Section
// ═════════════════════════════════════════════════════════════════════════════

class _AppearanceSection extends ConsumerStatefulWidget {
  @override
  ConsumerState<_AppearanceSection> createState() => _AppearanceSectionState();
}

class _AppearanceSectionState extends ConsumerState<_AppearanceSection> {
  double _transparency = 40;
  bool _dynamicAccents = false;
  bool _fluidAnimations = true;

  Future<void> _pickWallpaper() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 92,
      );
      if (picked == null) return;

      final supportDir = await getApplicationSupportDirectory();
      final wallpaperDir = Directory('${supportDir.path}/wallpapers');
      if (!await wallpaperDir.exists()) {
        await wallpaperDir.create(recursive: true);
      }
      final pathParts = picked.path.split('.');
      final extension = pathParts.length > 1 ? pathParts.last : 'jpg';
      final targetPath =
          '${wallpaperDir.path}/launcher_wallpaper_${DateTime.now().millisecondsSinceEpoch}.$extension';
      await File(picked.path).copy(targetPath);
      await ref
          .read(launcherAppearanceProvider.notifier)
          .setCustomWallpaperPath(targetPath);
      messenger.showSnackBar(
        const SnackBar(content: Text('Wallpaper updated')),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Unable to select wallpaper: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightnessSettings = ref.watch(brightnessProvider);
    final brightnessNotifier = ref.read(brightnessProvider.notifier);
    final currentBrightnessPercent = (brightnessSettings.brightness * 100)
        .clamp(0.0, 100.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 1100;
        final themeCard = _GlassPanel(
          key: const Key('settings-theme-card'),
          child: _buildThemeCard(compact: compact),
        );
        final quickCard = _GlassPanel(
          key: const Key('settings-quick-card'),
          child: _buildQuickSettingsCard(),
        );
        final brightnessSlider = Opacity(
          opacity: brightnessSettings.autoBrightness ? 0.45 : 1.0,
          child: brightnessSettings.autoBrightness
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.light_mode_outlined,
                          size: 18,
                          color: CarPlayTheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Screen Brightness',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: CarPlayTheme.onSurface,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: CarPlayTheme.neonCyan.withAlpha(26),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'Auto',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: CarPlayTheme.neonCyan,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Disable Auto Brightness to manually adjust.',
                      style: TextStyle(
                        fontSize: 12,
                        color: CarPlayTheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                )
              : _NeonSlider(
                  label: 'Screen Brightness',
                  icon: Icons.light_mode_outlined,
                  initialValue: currentBrightnessPercent,
                  onChanged: (v) => brightnessNotifier.setBrightness(v / 100),
                ),
        );
        final transparencySlider = _NeonSlider(
          label: 'UI Transparency',
          icon: Icons.opacity_outlined,
          initialValue: _transparency,
          onChanged: (v) => setState(() => _transparency = v),
        );
        final animations = _GlassPanel(
          child: _IconToggleRow(
            icon: Icons.motion_photos_on_outlined,
            title: 'Fluid Animations',
            subtitle: 'High frame-rate transitions',
            value: _fluidAnimations,
            onChanged: (v) => setState(() => _fluidAnimations = v),
          ),
        );
        return SingleChildScrollView(
          padding: const EdgeInsets.only(right: 8, bottom: CarPlayTheme.margin),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section header
              const _SectionHeader(
                title: 'Appearance',
                description: 'Personalize your digital cockpit experience.',
              ),
              const SizedBox(height: CarPlayTheme.widgetGap),

              if (compact) ...[
                themeCard,
                const SizedBox(height: CarPlayTheme.widgetGap),
                quickCard,
              ] else
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 8, child: themeCard),
                      const SizedBox(width: CarPlayTheme.widgetGap),
                      Expanded(flex: 4, child: quickCard),
                    ],
                  ),
                ),
              const SizedBox(height: CarPlayTheme.widgetGap),

              // ── Sliders Section ──
              _GlassPanel(
                child: compact
                    ? Column(
                        children: [
                          brightnessSlider,
                          const SizedBox(height: CarPlayTheme.widgetGap),
                          transparencySlider,
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: brightnessSlider),
                          const SizedBox(width: CarPlayTheme.gutter),
                          Expanded(child: transparencySlider),
                        ],
                      ),
              ),
              const SizedBox(height: CarPlayTheme.widgetGap),

              animations,
            ],
          ),
        );
      },
    );
  }

  Widget _buildThemeCard({required bool compact}) {
    final appearance = ref.watch(launcherAppearanceProvider);
    final notifier = ref.read(launcherAppearanceProvider.notifier);
    final themeMode = ref.watch(themeModeProvider);
    final themeModeNotifier = ref.read(themeModeProvider.notifier);
    final hasCustomWallpaper =
        appearance.customWallpaperPath?.isNotEmpty == true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flex(
          direction: compact ? Axis.vertical : Axis.horizontal,
          crossAxisAlignment: compact
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Interface Theme',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: CarPlayTheme.onSurface,
              ),
            ),
            if (compact) const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: CarPlayTheme.deepObsidian,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withAlpha(26)),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final theme in LauncherThemeStyle.values)
                    _PillButton(
                      label: theme.label,
                      isSelected: appearance.themeStyle == theme,
                      onTap: () => notifier.setThemeStyle(theme),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Flex(
          direction: compact ? Axis.vertical : Axis.horizontal,
          crossAxisAlignment: compact
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Light / Dark Mode',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: CarPlayTheme.onSurface,
              ),
            ),
            if (compact) const SizedBox(height: 12),
            Container(
              key: const Key('settings-theme-mode-picker'),
              decoration: BoxDecoration(
                color: CarPlayTheme.deepObsidian,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withAlpha(26)),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final mode in AppThemeMode.values)
                    _PillButton(
                      label: mode.label,
                      isSelected: themeMode == mode,
                      onTap: () => themeModeNotifier.setMode(mode),
                    ),
                ],
              ),
            ),
          ],
        ),
        if (themeMode == AppThemeMode.auto) ...[
          const SizedBox(height: 8),
          Text(
            'Auto follows the system Dark setting, or day/night hours when that setting isn\'t meaningful on this device.',
            style: TextStyle(
              fontSize: 12,
              color: CarPlayTheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 20),
        Row(
          children: [
            for (final background in LauncherBackgroundStyle.values)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: background != LauncherBackgroundStyle.values.last
                        ? 12
                        : 0,
                  ),
                  child: _WallpaperThumbnail(
                    isSelected: appearance.backgroundStyle == background,
                    style: background,
                    onTap: () => notifier.setBackgroundStyle(background),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                key: const Key('settings-pick-wallpaper'),
                onPressed: _pickWallpaper,
                icon: const Icon(Icons.image_outlined, size: 18),
                label: Text(
                  hasCustomWallpaper ? 'Change Wallpaper' : 'Choose Wallpaper',
                ),
              ),
            ),
            if (hasCustomWallpaper) ...[
              const SizedBox(width: 12),
              OutlinedButton.icon(
                key: const Key('settings-clear-wallpaper'),
                onPressed: notifier.clearCustomWallpaper,
                icon: const Icon(Icons.restart_alt, size: 18),
                label: const Text('Default'),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildQuickSettingsCard() {
    final brightnessSettings = ref.watch(brightnessProvider);
    final brightnessNotifier = ref.read(brightnessProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Settings',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: CarPlayTheme.onSurface,
          ),
        ),
        const SizedBox(height: 20),
        _ToggleRow(
          title: 'Auto Brightness',
          subtitle: 'Adjusts to cabin light',
          value: brightnessSettings.autoBrightness,
          onChanged: brightnessNotifier.setAutoBrightness,
        ),
        const SizedBox(height: 20),
        _ToggleRow(
          title: 'Dynamic Accents',
          subtitle: 'Match album art color',
          value: _dynamicAccents,
          onChanged: (v) => setState(() => _dynamicAccents = v),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Pill Button (theme selector)
// ═════════════════════════════════════════════════════════════════════════════

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = CarPlayTheme.accent(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? accent : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected
                ? CarPlayTheme.deepObsidian
                : CarPlayTheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Wallpaper Thumbnail
// ═════════════════════════════════════════════════════════════════════════════

class _WallpaperThumbnail extends StatelessWidget {
  const _WallpaperThumbnail({
    required this.isSelected,
    required this.style,
    required this.onTap,
  });

  final bool isSelected;
  final LauncherBackgroundStyle style;
  final VoidCallback onTap;

  // Placeholder gradient colors for wallpaper previews
  static const _gradients = [
    [Color(0xFF1A1A1A), Color(0xFF4A4A4A)], // Glass grey
    [Color(0xFF1A0A2E), Color(0xFF8B5CF6)], // Electric violet
    [Color(0xFF0A0B0C), Color(0xFF00E5FF)], // Dark cyan
  ];

  @override
  Widget build(BuildContext context) {
    final accent = CarPlayTheme.accent(context);
    return GestureDetector(
      onTap: onTap,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? accent : Colors.white.withAlpha(13),
              width: isSelected ? 2 : 1,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: _gradients[style.index],
            ),
          ),
          child: isSelected
              ? Center(
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: accent.withAlpha(51),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.check_circle, color: accent, size: 24),
                  ),
                )
              : null,
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Toggle Row
// ═════════════════════════════════════════════════════════════════════════════

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: CarPlayTheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 13,
                  color: CarPlayTheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _NeonToggle(value: value, onChanged: onChanged),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════

// ═════════════════════════════════════════════════════════════════════════════
// Icon Toggle Row (with circular icon background)
// ═════════════════════════════════════════════════════════════════════════════

class _IconToggleRow extends StatelessWidget {
  const _IconToggleRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: CarPlayTheme.neonCyan.withAlpha(26),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 22, color: CarPlayTheme.neonCyan),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: CarPlayTheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: CarPlayTheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _NeonToggle(value: value, onChanged: onChanged),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Dashboard Section
// ═════════════════════════════════════════════════════════════════════════════

class _DashboardSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final carPlaySettings = ref.watch(carPlaySettingsProvider);
    final selectedMode = carPlaySettings.homeViewMode;
    final isMultiApp = selectedMode == HomeViewMode.multiApp;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(right: 8, bottom: CarPlayTheme.margin),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            title: 'Dashboard',
            description: 'Choose your home screen layout.',
          ),
          const SizedBox(height: CarPlayTheme.widgetGap),

          // ── Dashboard type grid ──
          _GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Layout Style',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: CarPlayTheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                // 2×2 grid of dashboard preview tiles
                for (final row in [
                  [HomeViewMode.dashboard01, HomeViewMode.dashboard02],
                  [HomeViewMode.dashboard03, HomeViewMode.multiApp],
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        for (final mode in row) ...[
                          Expanded(
                            child: _DashboardPreviewTile(
                              mode: mode,
                              isSelected: selectedMode == mode,
                              onTap: () => ref
                                  .read(carPlaySettingsProvider.notifier)
                                  .setHomeViewMode(mode),
                            ),
                          ),
                          if (mode != row.last) const SizedBox(width: 12),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // ── Multi-app specific controls ──
          if (isMultiApp) ...[
            const SizedBox(height: CarPlayTheme.widgetGap),
            _GlassPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pane Apps',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: CarPlayTheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Assign apps to each pane',
                    style: TextStyle(
                      fontSize: 13,
                      color: CarPlayTheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _MultiAppPaneSettings(),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Mini preview thumbnail for a dashboard layout type.
class _DashboardPreviewTile extends StatelessWidget {
  const _DashboardPreviewTile({
    required this.mode,
    required this.isSelected,
    required this.onTap,
  });

  final HomeViewMode mode;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? CarPlayTheme.neonCyan
                : Colors.white.withAlpha(26),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            // Preview thumbnail
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(9),
              ),
              child: AspectRatio(
                aspectRatio: 16 / 10,
                child: Container(
                  color: const Color(0xFF1A1A2E),
                  child: _buildPreview(),
                ),
              ),
            ),
            // Label
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? CarPlayTheme.neonCyan.withAlpha(20)
                    : CarPlayTheme.surfaceContainerHigh,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(9),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    mode.displayName,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? CarPlayTheme.neonCyan
                          : CarPlayTheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    mode.description,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      color: CarPlayTheme.onSurfaceVariant,
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

  Widget _buildPreview() {
    switch (mode) {
      case HomeViewMode.dashboard01:
        return _PreviewDashboard01();
      case HomeViewMode.dashboard02:
        return _PreviewDashboard02();
      case HomeViewMode.dashboard03:
        return _PreviewDashboard03();
      case HomeViewMode.multiApp:
        return _PreviewMultiApp();
    }
  }
}

// ── Mini preview painters ─────────────────────────────────────────────────

class _PreviewDashboard01 extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Map fills the whole area
        Positioned.fill(child: Container(color: const Color(0xFF0D1B2A))),
        // YouTube overlay (right side)
        Positioned(
          right: 4,
          top: 12,
          bottom: 4,
          width: 50,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF16213E),
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: const Color(0xFF0F3460), width: 0.5),
            ),
            child: const Center(
              child: Icon(
                Icons.play_circle_outline,
                size: 14,
                color: Colors.white54,
              ),
            ),
          ),
        ),
        // Sidebar
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: 8,
          child: Container(color: Colors.black45),
        ),
      ],
    );
  }
}

class _PreviewDashboard02 extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Sidebar
        Container(width: 6, color: Colors.black45),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: Row(
              children: [
                // Map (larger)
                Expanded(
                  flex: 6,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D1B2A),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(width: 3),
                // Right column: media + weather
                Expanded(
                  flex: 4,
                  child: Column(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1A2E),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.music_note,
                              size: 10,
                              color: Colors.white38,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF16213E),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.cloud,
                              size: 10,
                              color: Colors.white38,
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
        ),
      ],
    );
  }
}

class _PreviewDashboard03 extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Sidebar
        Container(width: 6, color: Colors.black45),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: Row(
              children: [
                // Map
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D1B2A),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(width: 3),
                // YouTube
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF16213E),
                      borderRadius: BorderRadius.circular(2),
                      border: Border.all(
                        color: const Color(0xFF0F3460),
                        width: 0.5,
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.play_circle_outline,
                        size: 12,
                        color: Colors.white54,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PreviewMultiApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Sidebar
        Container(width: 6, color: Colors.black45),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A2E),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: const Center(
                      child: Text(
                        'App 1',
                        style: TextStyle(fontSize: 8, color: Colors.white38),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 3),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF16213E),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: const Center(
                      child: Text(
                        'App 2',
                        style: TextStyle(fontSize: 8, color: Colors.white38),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Pane app assignment UI — only shown in multiApp mode.
class _MultiAppPaneSettings extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layout = ref.watch(layoutProvider);
    return Column(
      children: [
        for (var i = 0; i < 2; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _PaneAppTile(index: i, app: layout.appForPane(i)),
          ),
      ],
    );
  }
}

class _PaneAppTile extends StatelessWidget {
  const _PaneAppTile({required this.index, required this.app});

  final int index;
  final PaneApp? app;

  @override
  Widget build(BuildContext context) {
    final name = app?.appName ?? 'Tap to select';
    return GestureDetector(
      onTap: () {
        // Trigger app picker — reuse existing pane app picker
      },
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: CarPlayTheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: CarPlayTheme.neonCyan,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: app != null
                    ? CarPlayTheme.onSurface
                    : CarPlayTheme.onSurfaceVariant,
              ),
            ),
          ),
          Icon(
            Icons.chevron_right,
            color: CarPlayTheme.onSurfaceVariant,
            size: 20,
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Navigation Section
// ═════════════════════════════════════════════════════════════════════════════

class _NavigationSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final defaultNav = ref.watch(defaultNavProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.only(right: 8, bottom: CarPlayTheme.margin),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            title: 'Navigation',
            description: 'Default navigation app and routing preferences.',
          ),
          const SizedBox(height: CarPlayTheme.widgetGap),
          _GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Default Navigation App',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: CarPlayTheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _navAppName(defaultNav),
                  style: TextStyle(
                    fontSize: 14,
                    color: CarPlayTheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => _showNavAppPicker(context, ref),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.white.withAlpha(51)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Change Navigation App',
                      style: TextStyle(color: CarPlayTheme.neonCyan),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: CarPlayTheme.widgetGap),
          _GlassPanel(
            key: const Key('settings-vehicle-tracking-card'),
            child: const VehicleTrackingSettingsCard(),
          ),
          const SizedBox(height: CarPlayTheme.widgetGap),
          _GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Clock & Network',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: CarPlayTheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Dynamic clock, 24-hour format, VPN status',
                  style: TextStyle(
                    fontSize: 14,
                    color: CarPlayTheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => context.push('/settings/clock-network'),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.white.withAlpha(51)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Configure Clock & Network',
                      style: TextStyle(color: CarPlayTheme.neonCyan),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _navAppName(String packageName) {
    if (packageName.contains('google')) return 'Google Maps';
    if (packageName.contains('waze')) return 'Waze';
    if (packageName.contains('here')) return 'HERE WeGo';
    if (packageName.contains('sygic')) return 'Sygic';
    return 'Google Maps';
  }

  void _showNavAppPicker(BuildContext context, WidgetRef ref) async {
    final apps = await ref.read(launcherServiceProvider).getInstalledApps();
    final navApps = apps.where((a) {
      final name = '${a['appName']} ${a['packageName']}'.toLowerCase();
      return name.contains('map') ||
          name.contains('nav') ||
          name.contains('waze') ||
          name.contains('here') ||
          name.contains('sygic');
    }).toList();

    if (!context.mounted) return;
    _showAppPicker(
      context,
      ref,
      'Default Navigation App',
      navApps,
      (pkg) => ref.read(defaultNavProvider.notifier).state = pkg,
    );
  }

  void _showAppPicker(
    BuildContext context,
    WidgetRef ref,
    String title,
    List<Map<String, String>> apps,
    void Function(String) onSelect,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: CarPlayTheme.surfaceContainer,
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: SizedBox(
          width: 300,
          height: 400,
          child: apps.isEmpty
              ? const Center(
                  child: Text(
                    'No apps found',
                    style: TextStyle(color: Colors.white38),
                  ),
                )
              : ListView.builder(
                  itemCount: apps.length,
                  itemBuilder: (context, index) {
                    final app = apps[index];
                    return ListTile(
                      title: Text(
                        app['appName'] ?? '',
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        app['packageName'] ?? '',
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                        ),
                      ),
                      onTap: () {
                        onSelect(app['packageName'] ?? '');
                        GoRouter.of(context).pop();
                      },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => GoRouter.of(context).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Media Section
// ═════════════════════════════════════════════════════════════════════════════

class _MediaSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final defaultMedia = ref.watch(defaultMediaProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.only(right: 8, bottom: CarPlayTheme.margin),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            title: 'Media & Sound',
            description: 'Default media app and audio preferences.',
          ),
          const SizedBox(height: CarPlayTheme.widgetGap),
          _GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Default Media App',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: CarPlayTheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _mediaAppName(defaultMedia),
                  style: TextStyle(
                    fontSize: 14,
                    color: CarPlayTheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => _showMediaAppPicker(context, ref),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.white.withAlpha(51)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Change Media App',
                      style: TextStyle(color: CarPlayTheme.neonCyan),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: CarPlayTheme.widgetGap),
          _GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Weather',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: CarPlayTheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Configure weather API and location',
                  style: TextStyle(
                    fontSize: 14,
                    color: CarPlayTheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => showDialog(
                      context: context,
                      builder: (_) => WeatherSettingsDialog(),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.white.withAlpha(51)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Configure Weather',
                      style: TextStyle(color: CarPlayTheme.neonCyan),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _mediaAppName(String packageName) {
    if (packageName.contains('spotify')) return 'Spotify';
    if (packageName.contains('youtube.music')) return 'YouTube Music';
    if (packageName.contains('apple')) return 'Apple Music';
    return 'Spotify';
  }

  void _showMediaAppPicker(BuildContext context, WidgetRef ref) async {
    final apps = await ref.read(launcherServiceProvider).getInstalledApps();
    final mediaApps = apps.where((a) {
      final name = '${a['appName']} ${a['packageName']}'.toLowerCase();
      return name.contains('music') ||
          name.contains('spotify') ||
          name.contains('youtube') ||
          name.contains('podcast');
    }).toList();

    if (!context.mounted) return;
    _showAppPicker(
      context,
      ref,
      'Default Media App',
      mediaApps,
      (pkg) => ref.read(defaultMediaProvider.notifier).state = pkg,
    );
  }

  void _showAppPicker(
    BuildContext context,
    WidgetRef ref,
    String title,
    List<Map<String, String>> apps,
    void Function(String) onSelect,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: CarPlayTheme.surfaceContainer,
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: SizedBox(
          width: 300,
          height: 400,
          child: apps.isEmpty
              ? const Center(
                  child: Text(
                    'No apps found',
                    style: TextStyle(color: Colors.white38),
                  ),
                )
              : ListView.builder(
                  itemCount: apps.length,
                  itemBuilder: (context, index) {
                    final app = apps[index];
                    return ListTile(
                      title: Text(
                        app['appName'] ?? '',
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        app['packageName'] ?? '',
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                        ),
                      ),
                      onTap: () {
                        onSelect(app['packageName'] ?? '');
                        GoRouter.of(context).pop();
                      },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => GoRouter.of(context).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Connectivity Section
// ═════════════════════════════════════════════════════════════════════════════

class _ConnectivitySection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectivity = ref.watch(connectivityStatusProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.only(right: 8, bottom: CarPlayTheme.margin),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            title: 'Connectivity',
            description: 'Wi-Fi, Bluetooth, and network status.',
          ),
          const SizedBox(height: CarPlayTheme.widgetGap),
          _GlassPanel(
            child: Column(
              children: [
                _ConnectivityRow(
                  icon: Icons.wifi,
                  label: 'Wi-Fi',
                  value: connectivity.extra['wifi'] == true ? 'Connected' : 'Off',
                  isOn: connectivity.extra['wifi'] == true,
                ),
                const SizedBox(height: 16),
                _ConnectivityRow(
                  icon: Icons.bluetooth,
                  label: 'Bluetooth',
                  value: connectivity.extra['bluetoothConnected'] == true
                      ? 'Connected'
                      : connectivity.extra['bluetoothEnabled'] == true
                      ? 'On'
                      : 'Off',
                  isOn: connectivity.extra['bluetoothEnabled'] == true,
                ),
                const SizedBox(height: 16),
                _ConnectivityRow(
                  icon: Icons.vpn_key,
                  label: 'VPN',
                  value: connectivity.extra['vpn'] == true ? 'Active' : 'Off',
                  isOn: connectivity.extra['vpn'] == true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ConnectivityRow extends StatelessWidget {
  const _ConnectivityRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.isOn,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool isOn;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isOn
                ? CarPlayTheme.neonCyan.withAlpha(26)
                : CarPlayTheme.surfaceContainerHigh,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 20,
            color: isOn ? CarPlayTheme.neonCyan : CarPlayTheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: CarPlayTheme.onSurface,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  color: isOn
                      ? CarPlayTheme.neonCyan
                      : CarPlayTheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// System Info Section
// ═════════════════════════════════════════════════════════════════════════════

class _SystemInfoSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hiddenApps = ref.watch(hiddenAppsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.only(right: 8, bottom: CarPlayTheme.margin),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            title: 'System Info',
            description: 'App version, hidden apps, and system status.',
          ),
          const SizedBox(height: CarPlayTheme.widgetGap),
          _GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoRow(label: 'Version', value: '1.0.0'),
                const SizedBox(height: 12),
                _InfoRow(label: 'Build', value: '1'),
                const SizedBox(height: 12),
                _InfoRow(
                  label: 'Hidden Apps',
                  value: '${hiddenApps.length} apps',
                ),
              ],
            ),
          ),
          const SizedBox(height: CarPlayTheme.widgetGap),
          _GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hidden Apps',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: CarPlayTheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Manage hidden applications',
                  style: TextStyle(
                    fontSize: 14,
                    color: CarPlayTheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => _showHiddenApps(context, ref),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.white.withAlpha(51)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Manage Hidden Apps',
                      style: TextStyle(color: CarPlayTheme.neonCyan),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: CarPlayTheme.widgetGap),
          _GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'System Logs',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: CarPlayTheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'View application logs for debugging and maintenance.',
                  style: TextStyle(
                    fontSize: 14,
                    color: CarPlayTheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => context.push('/settings/logs'),
                    icon: const Icon(Icons.article_outlined, size: 18),
                    label: const Text('View Logs'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: CarPlayTheme.neonCyan,
                      side: BorderSide(color: Colors.white.withAlpha(51)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showHiddenApps(BuildContext context, WidgetRef ref) {
    final hiddenApps = ref.watch(hiddenAppsProvider);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: CarPlayTheme.surfaceContainer,
        title: const Text('Hidden Apps', style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: 300,
          height: 400,
          child: hiddenApps.isEmpty
              ? const Center(
                  child: Text(
                    'No hidden apps',
                    style: TextStyle(color: Colors.white38),
                  ),
                )
              : ListView.builder(
                  itemCount: hiddenApps.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(
                        hiddenApps[index],
                        style: const TextStyle(color: Colors.white),
                      ),
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.visibility,
                          color: Colors.white54,
                        ),
                        onPressed: () {
                          ref
                              .read(hiddenAppsProvider.notifier)
                              .removeHidden(hiddenApps[index]);
                        },
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => GoRouter.of(context).pop(),
            child: const Text('Done', style: TextStyle(color: Colors.white54)),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 15, color: CarPlayTheme.onSurfaceVariant),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: CarPlayTheme.onSurface,
          ),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Account Section (Keycloak)
// ═════════════════════════════════════════════════════════════════════════════

class _AccountSection extends ConsumerWidget {
  const _AccountSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(accountSessionProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.only(right: 8, bottom: CarPlayTheme.margin),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            title: 'Account',
            description: 'Sign in to sync your preferences.',
          ),
          const SizedBox(height: CarPlayTheme.widgetGap),

          session.when(
            loading: () => const _GlassPanel(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            error: (_, _) => _buildLoggedOut(context, ref, error: true),
            data: (user) {
              if (user != null) return _buildLoggedIn(context, ref, user);
              return _buildLoggedOut(context, ref);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLoggedIn(BuildContext context, WidgetRef ref, AccountUser user) {
    return Column(
      children: [
        _GlassPanel(
          child: Row(
            children: [
              // Avatar
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: CarPlayTheme.neonCyan.withAlpha(30),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    user.initials,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: CarPlayTheme.neonCyan,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.displayName,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: CarPlayTheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.email,
                      style: TextStyle(
                        fontSize: 13,
                        color: CarPlayTheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.mail_outline,
                          size: 14,
                          color: CarPlayTheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Signed in with ${user.authProvider.label}',
                          style: TextStyle(
                            fontSize: 12,
                            color: CarPlayTheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: CarPlayTheme.widgetGap),
        _GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Session',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: CarPlayTheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'You are signed in to Keycloak.',
                style: TextStyle(
                  fontSize: 13,
                  color: CarPlayTheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    try {
                      await ref.read(accountSessionProvider.notifier).logout();
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(accountErrorMessage(e))),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.logout, size: 18),
                  label: const Text('Sign Out'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: BorderSide(color: Colors.redAccent.withAlpha(80)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLoggedOut(
    BuildContext context,
    WidgetRef ref, {
    bool error = false,
  }) {
    return Column(
      children: [
        _GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: CarPlayTheme.neonCyan.withAlpha(26),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.person_outline,
                      size: 22,
                      color: CarPlayTheme.neonCyan,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Not signed in',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: CarPlayTheme.onSurface,
                          ),
                        ),
                        Text(
                          error
                              ? 'Session check failed — try signing in again.'
                              : 'Sign in to sync preferences across devices.',
                          style: TextStyle(
                            fontSize: 13,
                            color: error
                                ? Colors.amber.withAlpha(180)
                                : CarPlayTheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () => context.push('/login'),
                  icon: const Icon(Icons.login_rounded, size: 20),
                  label: const Text('Sign In'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1976D2),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Vehicle Section
// ═════════════════════════════════════════════════════════════════════════════

class _VehicleSection extends ConsumerWidget {
  const _VehicleSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoggedIn =
        ref.watch(accountSessionProvider.select((s) => s.valueOrNull != null));

    if (!isLoggedIn) {
      return SingleChildScrollView(
        padding: const EdgeInsets.only(right: 8, bottom: CarPlayTheme.margin),
        child: LoginRequiredWidget(featureLabel: 'Manage vehicles'),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.only(right: 8, bottom: CarPlayTheme.margin),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            title: 'Vehicle',
            description: 'Manage your vehicles and registration.',
          ),
          const SizedBox(height: CarPlayTheme.widgetGap),
          _GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Registered Vehicles',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: CarPlayTheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'View, add, and edit vehicle profiles',
                  style: TextStyle(
                    fontSize: 14,
                    color: CarPlayTheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => context.push('/vehicles'),
                    icon: const Icon(Icons.directions_car_outlined, size: 18),
                    label: const Text('Manage Vehicles'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: CarPlayTheme.neonCyan,
                      side: BorderSide(color: Colors.white.withAlpha(51)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Tracking Section
// ═════════════════════════════════════════════════════════════════════════════

class _TrackingSection extends ConsumerWidget {
  const _TrackingSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoggedIn =
        ref.watch(accountSessionProvider.select((s) => s.valueOrNull != null));

    if (!isLoggedIn) {
      return SingleChildScrollView(
        padding: const EdgeInsets.only(right: 8, bottom: CarPlayTheme.margin),
        child: LoginRequiredWidget(featureLabel: 'Tracking'),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.only(right: 8, bottom: CarPlayTheme.margin),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            title: 'Tracking',
            description: 'Vehicle GPS tracking and route history.',
          ),
          const SizedBox(height: CarPlayTheme.widgetGap),
          _GlassPanel(
            key: const Key('settings-tracking-card'),
            child: const VehicleTrackingSettingsCard(),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Shared providers (preserved from original)
// ═════════════════════════════════════════════════════════════════════════════

final defaultNavProvider = StateProvider<String>(
  (ref) => 'com.google.android.apps.maps',
);
final defaultMediaProvider = StateProvider<String>(
  (ref) => 'com.spotify.music',
);
final hiddenAppsProvider =
    StateNotifierProvider<HiddenAppsNotifier, List<String>>((ref) {
      return HiddenAppsNotifier();
    });

class HiddenAppsNotifier extends StateNotifier<List<String>> {
  HiddenAppsNotifier() : super([]);

  void addHidden(String packageName) {
    if (!state.contains(packageName)) {
      state = [...state, packageName];
    }
  }

  void removeHidden(String packageName) {
    state = state.where((p) => p != packageName).toList();
  }

  bool isHidden(String packageName) => state.contains(packageName);
}
