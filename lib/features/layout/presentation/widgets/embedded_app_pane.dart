import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:car_launcher/features/launcher/data/launcher_service.dart';
import 'package:car_launcher/features/layout/domain/layout_model.dart';
import 'package:car_launcher/features/layout/presentation/pane_launch_coordinator.dart';
import 'package:car_launcher/features/layout/presentation/providers/embedding_providers.dart';
import 'package:car_launcher/features/layout/presentation/providers/layout_providers.dart';
import 'package:car_launcher/features/layout/presentation/widgets/pane_widgets.dart';

/// Embeds a target Android app inside a launcher pane, or falls back to
/// launching apps when the device ROM does not support ActivityView.
class EmbeddedAppPane extends ConsumerWidget {
  const EmbeddedAppPane({
    super.key,
    required this.paneIndex,
    required this.app,
    required this.onAssign,
    required this.onChange,
  });

  final int paneIndex;
  final PaneApp? app;
  final VoidCallback onAssign;
  final VoidCallback onChange;

  static const _viewType = 'embedded_app_pane';

  static final Set<Factory<OneSequenceGestureRecognizer>> _gestureRecognizers = {
    Factory<EagerGestureRecognizer>(EagerGestureRecognizer.new),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasApp = app != null && app!.packageName.isNotEmpty;

    if (!hasApp) {
      return AppPane(
        paneIndex: paneIndex,
        app: app,
        emptyHint: 'Tap to assign an app',
        assignedHint: 'Long press to change',
        onTap: onAssign,
        onLongPress: onChange,
      );
    }

    if (defaultTargetPlatform != TargetPlatform.android) {
      return _FallbackAppPane(
        paneIndex: paneIndex,
        app: app!,
        onAssign: onAssign,
        onChange: onChange,
        hint: 'Embedded apps only on Android',
      );
    }

    final embeddingAsync = ref.watch(embeddingInfoProvider);

    return embeddingAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: Colors.white54, strokeWidth: 2),
      ),
      error: (_, _) => _FallbackAppPane(
        paneIndex: paneIndex,
        app: app!,
        onAssign: onAssign,
        onChange: onChange,
        hint: 'Tap to open app',
      ),
      data: (info) {
        if (!info.supported) {
          return _FallbackAppPane(
            paneIndex: paneIndex,
            app: app!,
            onAssign: onAssign,
            onChange: onChange,
            hint: 'Tap to open · ${info.reason}',
          );
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            PlatformViewLink(
              viewType: _viewType,
              surfaceFactory: (context, controller) {
                return AndroidViewSurface(
                  controller: controller as AndroidViewController,
                  gestureRecognizers: _gestureRecognizers,
                  hitTestBehavior: PlatformViewHitTestBehavior.opaque,
                );
              },
              onCreatePlatformView: (params) {
                final controller = PlatformViewsService.initExpensiveAndroidView(
                  id: params.id,
                  viewType: _viewType,
                  layoutDirection: TextDirection.ltr,
                  creationParams: <String, dynamic>{
                    'paneId': paneIndex,
                    'packageName': app!.packageName,
                  },
                  creationParamsCodec: const StandardMessageCodec(),
                  onFocus: () => params.onFocusChanged(true),
                );
                controller.addOnPlatformViewCreatedListener(
                  params.onPlatformViewCreated,
                );
                controller.create();
                return controller;
              },
            ),
            Positioned(
              top: 6,
              right: 6,
              child: Material(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: onChange,
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(Icons.swap_horiz, color: Colors.white70, size: 18),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 8,
              bottom: 8,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text(
                    app!.appName,
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _FallbackAppPane extends ConsumerWidget {
  const _FallbackAppPane({
    required this.paneIndex,
    required this.app,
    required this.onAssign,
    required this.onChange,
    required this.hint,
  });

  final int paneIndex;
  final PaneApp app;
  final VoidCallback onAssign;
  final VoidCallback onChange;
  final String hint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppPane(
      paneIndex: paneIndex,
      app: app,
      assignedHint: hint,
      onTap: () async {
        final model = ref.read(layoutProvider);
        await PaneLaunchCoordinator.launchForLayout(
          ref.read(launcherServiceProvider),
          model,
          force: true,
          useSplitScreenFallback: true,
        );
      },
      onLongPress: onChange,
    );
  }
}
