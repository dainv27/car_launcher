import 'package:car_launcher/features/dashboard/presentation/widgets/navigation_map_widget.dart';
import 'package:flutter/material.dart';

class MapPage extends StatelessWidget {
  const MapPage({super.key, this.showYoutube = true});

  final bool showYoutube;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.transparent,
      child: const NavigationMapWidget(),
    );
  }
}
