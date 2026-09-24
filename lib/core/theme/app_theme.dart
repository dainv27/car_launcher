import 'package:flutter/material.dart';
import 'package:car_launcher/core/theme/launcher_appearance.dart';
import 'package:car_launcher/core/theme/launcher_palette.dart';

/// Theme configuration for Car Launcher.
///
/// A minimal automotive design: graphite (night) or paper (day) neutrals,
/// one accent colour from [LauncherThemeStyle], large touch targets and
/// high-contrast type sized for reading at a glance while driving.
class AppTheme {
  const AppTheme._();

  /// Night theme, tinted with the appearance's accent.
  static ThemeData launcherTheme(LauncherAppearance appearance) => _build(
    LauncherPalette.dark(appearance.themeStyle.accentFor(Brightness.dark)),
  );

  /// Day theme, tinted with the appearance's accent.
  static ThemeData launcherLightTheme(LauncherAppearance appearance) => _build(
    LauncherPalette.light(appearance.themeStyle.accentFor(Brightness.light)),
  );

  /// Day theme with the default accent.
  static ThemeData get dayTheme =>
      launcherLightTheme(const LauncherAppearance());

  /// Night theme with the default accent.
  static ThemeData get nightTheme => launcherTheme(const LauncherAppearance());

  static const radiusSmall = 12.0;
  static const radiusMedium = 16.0;
  static const radiusLarge = 24.0;

  static ThemeData _build(LauncherPalette p) {
    final scheme = _colorScheme(p);
    // Merge onto the platform typography so component styles (buttons,
    // chips, inputs) inherit the platform font family, not just the textTheme.
    final typography = Typography.material2021(colorScheme: scheme);
    final textTheme = (p.isDark ? typography.white : typography.black).merge(
      _textTheme(p),
    );
    final controlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radiusMedium),
    );
    const controlSize = Size(64, 56);
    const controlPadding = EdgeInsets.symmetric(horizontal: 24);
    final labelStyle = textTheme.labelLarge;

    return ThemeData(
      useMaterial3: true,
      brightness: p.brightness,
      colorScheme: scheme,
      textTheme: textTheme,
      typography: typography,
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: p.surface,
      dividerColor: p.border,
      splashColor: p.accent.withValues(alpha: 0.12),
      highlightColor: p.accent.withValues(alpha: 0.08),
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      extensions: [p],
      iconTheme: IconThemeData(color: p.textPrimary, size: 24),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: p.textPrimary,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: p.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
          side: BorderSide(color: p.border),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        barrierColor: p.scrim.withValues(alpha: p.isDark ? 0.6 : 0.4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
          side: BorderSide(color: p.border),
        ),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        modalBarrierColor: p.scrim.withValues(alpha: 0.5),
        showDragHandle: true,
        dragHandleColor: p.textTertiary,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(radiusLarge),
          ),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: p.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        textStyle: textTheme.bodyLarge,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          side: BorderSide(color: p.border),
        ),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(p.surfaceRaised),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusMedium),
            ),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: p.isDark ? p.surfaceRaised : p.textPrimary,
        contentTextStyle: textTheme.bodyLarge?.copyWith(
          color: p.isDark ? p.textPrimary : p.surface,
        ),
        actionTextColor: p.accent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: p.isDark ? p.surfaceRaised : p.textPrimary,
          borderRadius: BorderRadius.circular(radiusSmall),
        ),
        textStyle: textTheme.bodySmall?.copyWith(
          color: p.isDark ? p.textPrimary : p.surface,
        ),
      ),
      dividerTheme: DividerThemeData(color: p.border, thickness: 1, space: 1),
      listTileTheme: ListTileThemeData(
        iconColor: p.textSecondary,
        textColor: p.textPrimary,
        selectedColor: p.accent,
        selectedTileColor: p.accentSoft,
        minVerticalPadding: 12,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
        ),
        titleTextStyle: textTheme.titleMedium,
        subtitleTextStyle: textTheme.bodyMedium,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.accent,
          foregroundColor: p.onAccent,
          disabledBackgroundColor: p.foreground.withValues(alpha: 0.08),
          disabledForegroundColor: p.textTertiary,
          minimumSize: controlSize,
          padding: controlPadding,
          shape: controlShape,
          textStyle: labelStyle,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: p.accent,
          foregroundColor: p.onAccent,
          disabledBackgroundColor: p.foreground.withValues(alpha: 0.08),
          disabledForegroundColor: p.textTertiary,
          shadowColor: p.accent.withValues(alpha: 0.4),
          minimumSize: controlSize,
          padding: controlPadding,
          shape: controlShape,
          textStyle: labelStyle,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.textPrimary,
          backgroundColor: p.foreground.withValues(alpha: 0.04),
          side: BorderSide(color: p.border),
          minimumSize: controlSize,
          padding: controlPadding,
          shape: controlShape,
          textStyle: labelStyle,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.accent,
          minimumSize: const Size(64, 48),
          shape: controlShape,
          textStyle: labelStyle,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: p.textPrimary,
          minimumSize: const Size.square(48),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: p.accent,
        foregroundColor: p.onAccent,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: p.surfaceSunken,
          foregroundColor: p.textSecondary,
          selectedBackgroundColor: p.accent,
          selectedForegroundColor: p.onAccent,
          side: BorderSide(color: p.border),
          minimumSize: const Size(48, 48),
          textStyle: labelStyle,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? p.accent
              : p.toggleTrackOff,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? p.accent
              : Colors.transparent,
        ),
        checkColor: WidgetStatePropertyAll(p.onAccent),
        side: BorderSide(color: p.textSecondary, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? p.accent
              : p.textSecondary,
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: p.accent,
        inactiveTrackColor: p.toggleTrackOff,
        thumbColor: p.accent,
        overlayColor: p.accent.withValues(alpha: 0.16),
        trackHeight: 6,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.accent,
        linearTrackColor: p.toggleTrackOff,
        circularTrackColor: Colors.transparent,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: p.surfaceRaised,
        selectedColor: p.accentSoft,
        disabledColor: p.surfaceSunken,
        side: BorderSide(color: p.border),
        labelStyle: textTheme.labelLarge?.copyWith(color: p.textPrimary),
        secondaryLabelStyle: textTheme.labelLarge?.copyWith(color: p.accent),
        checkmarkColor: p.accent,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: p.textPrimary,
        unselectedLabelColor: p.textSecondary,
        indicatorColor: p.accent,
        dividerColor: Colors.transparent,
        labelStyle: textTheme.titleSmall,
        unselectedLabelStyle: textTheme.titleSmall,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surfaceSunken,
        hintStyle: textTheme.bodyLarge?.copyWith(color: p.textTertiary),
        labelStyle: textTheme.bodyLarge?.copyWith(color: p.textSecondary),
        floatingLabelStyle: textTheme.bodyMedium?.copyWith(color: p.accent),
        prefixIconColor: p.textSecondary,
        suffixIconColor: p.textSecondary,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        border: _inputBorder(p.border),
        enabledBorder: _inputBorder(p.border),
        focusedBorder: _inputBorder(p.accent, width: 2),
        errorBorder: _inputBorder(p.danger),
        focusedErrorBorder: _inputBorder(p.danger, width: 2),
        disabledBorder: _inputBorder(p.border.withValues(alpha: 0.5)),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: textTheme.bodyLarge,
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(p.surfaceRaised),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: p.accent,
        selectionColor: p.accent.withValues(alpha: 0.3),
        selectionHandleColor: p.accent,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        },
      ),
    );
  }

  static ColorScheme _colorScheme(LauncherPalette p) {
    return ColorScheme.fromSeed(
      seedColor: p.accent,
      brightness: p.brightness,
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
    ).copyWith(
      primary: p.accent,
      onPrimary: p.onAccent,
      secondary: p.accent,
      onSecondary: p.onAccent,
      surface: p.surface,
      onSurface: p.textPrimary,
      onSurfaceVariant: p.textSecondary,
      surfaceContainerLowest: p.surfaceSunken,
      surfaceContainerLow: p.surface,
      surfaceContainer: p.surface,
      surfaceContainerHigh: p.surfaceRaised,
      surfaceContainerHighest: p.surfaceRaised,
      surfaceTint: Colors.transparent,
      outline: p.textTertiary,
      outlineVariant: p.border,
      error: p.danger,
      shadow: p.shadow,
      scrim: p.scrim,
    );
  }

  /// Type scale sized for a dashboard viewed at arm's length: bigger body
  /// text than phone defaults, tight tracking on large numerals (clock,
  /// speed, temperature) and relaxed line height for body copy.
  static TextTheme _textTheme(LauncherPalette p) {
    TextStyle style(
      double size,
      FontWeight weight, {
      Color? color,
      double height = 1.3,
      double spacing = 0,
    }) => TextStyle(
      fontSize: size,
      fontWeight: weight,
      height: height,
      letterSpacing: spacing,
      color: color ?? p.textPrimary,
    );

    return TextTheme(
      displayLarge: style(88, FontWeight.w300, height: 1.0, spacing: -2),
      displayMedium: style(64, FontWeight.w300, height: 1.05, spacing: -1.5),
      displaySmall: style(48, FontWeight.w400, height: 1.1, spacing: -1),
      headlineLarge: style(36, FontWeight.w600, height: 1.15, spacing: -0.5),
      headlineMedium: style(30, FontWeight.w600, height: 1.2, spacing: -0.25),
      headlineSmall: style(24, FontWeight.w600, height: 1.25),
      titleLarge: style(22, FontWeight.w600),
      titleMedium: style(18, FontWeight.w600),
      titleSmall: style(16, FontWeight.w600),
      bodyLarge: style(18, FontWeight.w400, height: 1.45),
      bodyMedium: style(
        16,
        FontWeight.w400,
        color: p.textSecondary,
        height: 1.45,
      ),
      bodySmall: style(
        14,
        FontWeight.w400,
        color: p.textSecondary,
        height: 1.4,
      ),
      labelLarge: style(16, FontWeight.w600, spacing: 0.1),
      labelMedium: style(
        14,
        FontWeight.w600,
        color: p.textSecondary,
        spacing: 0.2,
      ),
      labelSmall: style(
        12,
        FontWeight.w600,
        color: p.textTertiary,
        spacing: 0.6,
      ),
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(radiusMedium),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}

/// Theme mode enum
enum AppThemeMode {
  day,
  night,
  auto;

  String get label => switch (this) {
    AppThemeMode.day => 'Day',
    AppThemeMode.night => 'Night',
    AppThemeMode.auto => 'Auto',
  };
}
