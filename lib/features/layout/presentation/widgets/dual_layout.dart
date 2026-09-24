import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:car_launcher/features/layout/domain/layout_model.dart';
import 'package:car_launcher/features/layout/presentation/widgets/embedded_app_pane.dart';
import 'package:car_launcher/features/layout/presentation/widgets/pane_widgets.dart';

/// Two side-by-side panes, each running an independently assigned app.
/// Pane widths follow [LayoutModel.ratio].
class DualLayout extends ConsumerWidget {
  const DualLayout({super.key, required this.model});

  final LayoutModel model;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Expanded(
          flex: (model.ratio.primaryFraction * 1000).round(),
          child: PaneContainer(child: _pane(context, ref, 0)),
        ),
        const SizedBox(width: 4),
        Expanded(
          flex: (model.ratio.secondaryFraction * 1000).round(),
          child: PaneContainer(child: _pane(context, ref, 1)),
        ),
      ],
    );
  }

  Widget _pane(BuildContext context, WidgetRef ref, int paneIndex) {
    final app = model.appForPane(paneIndex);
    return EmbeddedAppPane(
      paneIndex: paneIndex,
      app: app,
      onAssign: () => showPaneAppPicker(
        context: context,
        ref: ref,
        paneIndex: paneIndex,
        currentApp: app,
      ),
      onChange: () => showPaneAppPicker(
        context: context,
        ref: ref,
        paneIndex: paneIndex,
        currentApp: app,
      ),
    );
  }
}
