import 'package:car_launcher/features/vehicle/domain/vehicle_brand.dart';
import 'package:flutter/material.dart';

/// Small colored circle showing a brand's initial. Used instead of a
/// manufacturer logo (which would require bundling trademarked artwork).
class VehicleBrandBadge extends StatelessWidget {
  const VehicleBrandBadge({super.key, required this.brand, this.size = 32});

  final String brand;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = VehicleBrands.colorFor(brand);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color.withAlpha(51), shape: BoxShape.circle),
      child: Text(
        VehicleBrands.initialFor(brand),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.42,
        ),
      ),
    );
  }
}
