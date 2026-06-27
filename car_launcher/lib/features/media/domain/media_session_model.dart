/// Media session model — represents the current state of media playback
library;

/// Playback state enum
enum PlaybackState {
  playing,
  paused,
  stopped,
  none,
}

/// Model representing current media session state
class MediaSessionModel {
  const MediaSessionModel({
    this.title = '',
    this.artist = '',
    this.album = '',
    this.albumArtUrl = '',
    this.durationMs = 0,
    this.positionMs = 0,
    this.state = PlaybackState.none,
    this.packageName = '',
  });

  final String title;
  final String artist;
  final String album;
  final String albumArtUrl;
  final int durationMs;
  final int positionMs;
  final PlaybackState state;
  final String packageName;

  bool get isPlaying => state == PlaybackState.playing;
  bool get hasMedia => title.isNotEmpty || artist.isNotEmpty;

  /// Formatted position (e.g. "1:23")
  String get positionFormatted {
    final seconds = positionMs ~/ 1000;
    final min = seconds ~/ 60;
    final sec = seconds % 60;
    return '$min:${sec.toString().padLeft(2, '0')}';
  }

  /// Formatted duration (e.g. "3:45")
  String get durationFormatted {
    final seconds = durationMs ~/ 1000;
    final min = seconds ~/ 60;
    final sec = seconds % 60;
    return '$min:${sec.toString().padLeft(2, '0')}';
  }

  /// Progress as a fraction (0.0 - 1.0)
  double get progress {
    if (durationMs <= 0) return 0;
    return (positionMs / durationMs).clamp(0.0, 1.0);
  }

  MediaSessionModel copyWith({
    String? title,
    String? artist,
    String? album,
    String? albumArtUrl,
    int? durationMs,
    int? positionMs,
    PlaybackState? state,
    String? packageName,
  }) {
    return MediaSessionModel(
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      albumArtUrl: albumArtUrl ?? this.albumArtUrl,
      durationMs: durationMs ?? this.durationMs,
      positionMs: positionMs ?? this.positionMs,
      state: state ?? this.state,
      packageName: packageName ?? this.packageName,
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'artist': artist,
        'album': album,
        'albumArtUrl': albumArtUrl,
        'durationMs': durationMs,
        'positionMs': positionMs,
        'state': state.name,
        'packageName': packageName,
      };

  factory MediaSessionModel.fromJson(Map<String, dynamic> json) {
    return MediaSessionModel(
      title: json['title'] as String? ?? '',
      artist: json['artist'] as String? ?? '',
      album: json['album'] as String? ?? '',
      albumArtUrl: json['albumArtUrl'] as String? ?? '',
      durationMs: json['durationMs'] as int? ?? 0,
      positionMs: json['positionMs'] as int? ?? 0,
      state: PlaybackState.values.firstWhere(
        (e) => e.name == (json['state'] as String? ?? 'none'),
        orElse: () => PlaybackState.none,
      ),
      packageName: json['packageName'] as String? ?? '',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MediaSessionModel &&
          runtimeType == other.runtimeType &&
          title == other.title &&
          artist == other.artist &&
          album == other.album &&
          albumArtUrl == other.albumArtUrl &&
          durationMs == other.durationMs &&
          positionMs == other.positionMs &&
          state == other.state &&
          packageName == other.packageName;

  @override
  int get hashCode => Object.hash(
        title,
        artist,
        album,
        albumArtUrl,
        durationMs,
        positionMs,
        state,
        packageName,
      );

  /// Empty/default session
  static const empty = MediaSessionModel();
}
