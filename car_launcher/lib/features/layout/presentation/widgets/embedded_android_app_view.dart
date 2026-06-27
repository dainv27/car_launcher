import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

/// Displays an Android application on its own native VirtualDisplay.
///
/// Full functionality requires a platform-signed privileged installation.
///
/// The native side (VirtualDisplayAppView + VirtualDisplayReadinessGate) gates
/// VirtualDisplay creation behind system readiness (boot completed, user
/// unlocked, display available, activity resumed, window focused, layout done,
/// surface valid). The widget creates the PlatformViewLink immediately so the
/// SurfaceView is created; the native side defers VD creation until ready.
class EmbeddedAndroidAppView extends StatelessWidget {
  const EmbeddedAndroidAppView({
    super.key,
    required this.packageName,
    required this.paneId,
    this.zOrderOnTop = false,
  });

  final String packageName;
  final int paneId;
  final bool zOrderOnTop;

  static final Set<Factory<OneSequenceGestureRecognizer>> _gestureRecognizers =
      {Factory<EagerGestureRecognizer>(EagerGestureRecognizer.new)};

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(
          child: Text(
            'Embedded app requires Android',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    return PlatformViewLink(
      viewType: 'virtual_display_app',
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
          viewType: 'virtual_display_app',
          layoutDirection: TextDirection.ltr,
          creationParams: <String, dynamic>{
            'packageName': packageName,
            'paneId': paneId,
            'zOrderOnTop': zOrderOnTop,
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
    );
  }
}
