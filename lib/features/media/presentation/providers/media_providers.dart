/// Media-related Riverpod providers
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:car_launcher/features/media/data/media_controller.dart';

// Re-export the core controller provider
export 'package:car_launcher/features/media/data/media_controller.dart' show mediaControllerProvider;

/// Main media session state provider (alias for convenience)
final mediaSessionProvider = mediaControllerProvider;

/// Whether media is currently playing
final isPlayingProvider = Provider<bool>((ref) {
  return ref.watch(mediaControllerProvider).isPlaying;
});

/// Current track title
final trackTitleProvider = Provider<String>((ref) {
  return ref.watch(mediaControllerProvider).title;
});

/// Current track artist
final trackArtistProvider = Provider<String>((ref) {
  return ref.watch(mediaControllerProvider).artist;
});

/// Current album name
final trackAlbumProvider = Provider<String>((ref) {
  return ref.watch(mediaControllerProvider).album;
});

/// Whether any media is active
final hasMediaProvider = Provider<bool>((ref) {
  return ref.watch(mediaControllerProvider).hasMedia;
});

/// Playback progress (0.0 - 1.0)
final playbackProgressProvider = Provider<double>((ref) {
  return ref.watch(mediaControllerProvider).progress;
});

/// Current position formatted (e.g. "1:23")
final playbackPositionProvider = Provider<String>((ref) {
  return ref.watch(mediaControllerProvider).positionFormatted;
});

/// Total duration formatted (e.g. "3:45")
final playbackDurationProvider = Provider<String>((ref) {
  return ref.watch(mediaControllerProvider).durationFormatted;
});
