import 'package:car_launcher/features/layout/presentation/widgets/embedded_android_app_view.dart';
import 'package:flutter/material.dart';

import 'glass_panel.dart';

/// Google Map
class NavigationMapWidget extends StatelessWidget {
  const NavigationMapWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: EdgeInsets.zero,
      child: const ClipRRect(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        child: EmbeddedAndroidAppView(
          packageName: 'com.google.android.apps.maps',
          paneId: 1,
          zOrderOnTop: true,
        ),
      ),
    );
  }
}
