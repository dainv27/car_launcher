/// Media info display — shows album art, title, and artist
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:car_launcher/features/media/domain/media_session_model.dart';
import 'package:car_launcher/features/media/presentation/providers/media_providers.dart';

/// Displays media info: album art, title, artist, and progress
class MediaInfoDisplay extends ConsumerWidget {
  const MediaInfoDisplay({super.key, this.compact = false, this.onTap});

  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(mediaSessionProvider);

    if (!session.hasMedia) {
      return _buildEmpty(context);
    }

    return GestureDetector(
      onTap: onTap,
      child: compact
          ? _buildCompact(context, session)
          : _buildFull(context, session),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: compact ? 40 : 64,
            height: compact ? 40 : 64,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.music_note,
              color: Colors.white38,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'No media playing',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: compact ? 13 : 15,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompact(BuildContext context, MediaSessionModel session) {
    return Row(
      children: [
        // Album art
        _AlbumArt(url: session.albumArtUrl, size: 40),
        const SizedBox(width: 10),

        // Title + artist
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                session.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (session.artist.isNotEmpty)
                Text(
                  session.artist,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFull(BuildContext context, MediaSessionModel session) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Album art
        _AlbumArt(url: session.albumArtUrl, size: 120),
        const SizedBox(height: 16),

        // Title
        Text(
          session.title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),

        // Artist
        if (session.artist.isNotEmpty)
          Text(
            session.artist,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 14,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),

        // Album name
        if (session.album.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            session.album,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 12,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],

        const SizedBox(height: 12),

        // Progress bar
        _ProgressBar(session: session),
      ],
    );
  }
}

class _AlbumArt extends StatelessWidget {
  const _AlbumArt({required this.url, required this.size});

  final String url;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        image: url.isNotEmpty
            ? DecorationImage(
                image: NetworkImage(url),
                fit: BoxFit.cover,
                onError: (_, _) {},
              )
            : null,
      ),
      child: url.isEmpty
          ? Icon(Icons.music_note, color: Colors.white38, size: size * 0.5)
          : null,
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.session});

  final MediaSessionModel session;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: session.progress,
            backgroundColor: Colors.white.withValues(alpha: 0.1),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF1DB954)),
            minHeight: 3,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              session.positionFormatted,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 10,
              ),
            ),
            Text(
              session.durationFormatted,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
