import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:car_launcher/features/media/domain/media_session_model.dart';
import 'package:car_launcher/core/native/native_bridge.dart';

/// Media controller — manages media session state from native MediaSession
class MediaController extends StateNotifier<MediaSessionModel> {
  MediaController() : super(MediaSessionModel.empty) {
    _init();
  }

  static const _mediaEventChannel = EventChannel(
    'com.carlauncher/media_events',
  );
  StreamSubscription<dynamic>? _subscription;

  void _init() {
    _subscription = _mediaEventChannel.receiveBroadcastStream().listen(
      (dynamic event) {
        if (event is Map) {
          try {
            final model = MediaSessionModel.fromJson(
              Map<String, dynamic>.from(event),
            );
            state = model;
          } catch (_) {
            // Ignore malformed events
          }
        }
      },
      onError: (_) {
        // Keep last known state on error
      },
    );
  }

  void updateSession(MediaSessionModel session) {
    state = session;
  }

  static const _nativeChannel = MethodChannel('com.carlauncher/native');

  Future<void> _sendCommand(
    String action, [
    Map<String, Object?>? extras,
  ]) async {
    try {
      await _nativeChannel.invokeMethod<bool>('mediaCommand', {
        'action': action,
        ...?extras,
      });
    } on PlatformException {
      // Keep the last MediaSession event; never fabricate local playback state.
    } on MissingPluginException {
      // Media controls are unavailable outside Android.
    }
  }

  Future<void> play() => _sendCommand('play');
  Future<void> pause() => _sendCommand('pause');
  Future<void> stop() => _sendCommand('stop');
  Future<void> next() => _sendCommand('next');
  Future<void> previous() => _sendCommand('previous');
  Future<void> seekTo(int positionMs) =>
      _sendCommand('seekTo', {'positionMs': positionMs});

  Future<void> playPause() => state.isPlaying ? pause() : play();

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

/// Media controller provider
final mediaControllerProvider =
    StateNotifierProvider<MediaController, MediaSessionModel>((ref) {
      return MediaController();
    });

/// Whether Android has granted Notification Access required by MediaSession.
final mediaAccessProvider = StreamProvider<bool>((ref) async* {
  while (true) {
    try {
      yield await NativeBridge.call<bool>('hasNotificationListenerAccess') ??
          false;
    } on NativeException {
      yield false;
    }
    await Future<void>.delayed(const Duration(seconds: 3));
  }
});
