import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:car_launcher/features/launcher/data/launcher_service.dart';
import 'package:car_launcher/features/layout/domain/layout_model.dart';
import 'package:car_launcher/features/layout/presentation/pane_launch_coordinator.dart';
import 'package:car_launcher/features/layout/presentation/providers/layout_providers.dart';
import 'package:car_launcher/features/layout/presentation/widgets/app_picker_dialog.dart';
import 'package:car_launcher/core/theme/launcher_palette.dart';

/// Container styling shared by all layout panes.
class PaneContainer extends StatelessWidget {
  const PaneContainer({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: context.palette.glass),
      child: child,
    );
  }
}

/// Interactive pane showing an assigned app or an empty placeholder.
class AppPane extends StatelessWidget {
  const AppPane({
    super.key,
    required this.paneIndex,
    required this.app,
    required this.onTap,
    this.onLongPress,
    this.assignedHint = 'Tap to launch · Long press to change',
    this.emptyHint = 'Tap to assign an app',
  });

  final int paneIndex;
  final PaneApp? app;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final String assignedHint;
  final String emptyHint;

  @override
  Widget build(BuildContext context) {
    final hasApp = app != null && app!.packageName.isNotEmpty;

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              hasApp ? Icons.android : Icons.add_circle_outline,
              size: 48,
              color: hasApp ? context.palette.success : context.palette.textTertiary,
            ),
            const SizedBox(height: 8),
            Text(
              hasApp ? app!.appName : 'Pane ${paneIndex + 1}\nTap to assign',
              style: TextStyle(
                color: hasApp ? context.palette.textPrimary : context.palette.textTertiary,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
            const SizedBox(height: 4),
            Text(
              hasApp ? assignedHint : emptyHint,
              style: TextStyle(color: context.palette.textTertiary, fontSize: 10),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Empty pane placeholder.
class EmptyPane extends StatelessWidget {
  const EmptyPane({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_circle_outline, size: 40, color: context.palette.textTertiary),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(color: context.palette.textTertiary, fontSize: 12)),
        ],
      ),
    );
  }
}

/// Shows the app picker and launches apps after a selection is made.
Future<void> showPaneAppPicker({
  required BuildContext context,
  required WidgetRef ref,
  required int paneIndex,
  PaneApp? currentApp,
}) async {
  final layoutNotifier = ref.read(layoutProvider.notifier);

  await showDialog<void>(
    context: context,
    builder: (_) => AppPickerDialog(
      paneIndex: paneIndex,
      currentApp: currentApp,
      onAppSelected: (selectedApp) async {
        await layoutNotifier.assignApp(paneIndex, selectedApp);
      },
      onRemove: (currentApp != null && currentApp.packageName.isNotEmpty)
          ? () {
              layoutNotifier.removeApp(paneIndex);
              PaneLaunchCoordinator.invalidate();
              Navigator.of(context).pop();
            }
          : null,
    ),
  );

  PaneLaunchCoordinator.invalidate();
  final model = ref.read(layoutProvider);
  await PaneLaunchCoordinator.launchForLayout(
    ref.read(launcherServiceProvider),
    model,
    force: true,
    useSplitScreenFallback: true,
  );
}
