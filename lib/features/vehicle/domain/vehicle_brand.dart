import 'package:flutter/material.dart';

/// Common vehicle brands offered as quick-select suggestions in the vehicle
/// form. Deliberately name-only — no manufacturer logos are bundled, since
/// those are third-party trademarks. Presentation uses a generated
/// initial/color badge instead (see `VehicleBrandBadge`).
class VehicleBrands {
  const VehicleBrands._();

  static const List<String> all = [
    'Toyota',
    'Honda',
    'Ford',
    'Hyundai',
    'Kia',
    'Mazda',
    'Mitsubishi',
    'Nissan',
    'VinFast',
    'Mercedes-Benz',
    'BMW',
    'Audi',
    'Volkswagen',
    'Chevrolet',
    'Suzuki',
    'Peugeot',
    'Subaru',
    'Lexus',
  ];

  static const List<Color> _palette = [
    Color(0xFF00E5FF),
    Color(0xFF9B7BFF),
    Color(0xFFFF6B6B),
    Color(0xFFFFB020),
    Color(0xFF4CD964),
    Color(0xFF5AC8FA),
    Color(0xFFFF375F),
    Color(0xFFA8F7E8),
  ];

  /// Deterministic accent color for a brand name, so the same brand always
  /// gets the same badge color without needing a logo asset.
  static Color colorFor(String brand) {
    if (brand.isEmpty) return _palette.first;
    final index = brand.toLowerCase().codeUnits.fold<int>(0, (a, b) => a + b) %
        _palette.length;
    return _palette[index];
  }

  /// Badge initial for a brand name (first letter, uppercased).
  static String initialFor(String brand) {
    final trimmed = brand.trim();
    return trimmed.isEmpty ? '?' : trimmed[0].toUpperCase();
  }
}
