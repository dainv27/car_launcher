import 'package:car_launcher/features/layout/presentation/widgets/embedded_android_app_view.dart';
import 'package:flutter/material.dart';

import 'glass_panel.dart';

/// YouTube embedded player
class YoutubeWidget extends StatelessWidget {
  const YoutubeWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      key: const Key('dashboard-youtube-card'),
      padding: EdgeInsets.zero,
      child: const ClipRRect(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        child: EmbeddedAndroidAppView(
          packageName: 'com.google.android.youtube',
          paneId: 2,
          zOrderOnTop: true,
        ),
      ),
    );
  }
}
