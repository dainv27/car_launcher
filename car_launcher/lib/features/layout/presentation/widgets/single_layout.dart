import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:car_launcher/features/layout/domain/layout_model.dart';
import 'package:car_launcher/features/layout/presentation/widgets/embedded_app_pane.dart';
import 'package:car_launcher/features/layout/presentation/widgets/pane_widgets.dart';

/// Single pane layout for one full-screen embedded app.
class SingleLayout extends ConsumerWidget {
  const SingleLayout({super.key, required this.model});

  final LayoutModel model;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = model.appForPane(0);

    return PaneContainer(
      child: EmbeddedAppPane(
        paneIndex: 0,
        app: app,
        onAssign: () => showPaneAppPicker(
          context: context,
          ref: ref,
          paneIndex: 0,
          currentApp: app,
        ),
        onChange: () => showPaneAppPicker(
          context: context,
          ref: ref,
          paneIndex: 0,
          currentApp: app,
        ),
      ),
    );
  }
}
