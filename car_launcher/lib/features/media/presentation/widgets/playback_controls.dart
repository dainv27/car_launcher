/// Playback controls — play/pause, next, previous buttons
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:car_launcher/features/media/presentation/providers/media_providers.dart';

/// Playback control buttons
class PlaybackControls extends ConsumerWidget {
  const PlaybackControls({
    super.key,
    this.compact = false,
    this.showShuffle = false,
    this.showRepeat = false,
  });

  final bool compact;
  final bool showShuffle;
  final bool showRepeat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPlaying = ref.watch(isPlayingProvider);
    final controller = ref.read(mediaControllerProvider.notifier);

    final iconSize = compact ? 24.0 : 32.0;
    final buttonSize = compact ? 40.0 : 56.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (showShuffle)
          _ControlButton(
            icon: Icons.shuffle,
            size: buttonSize,
            iconSize: iconSize * 0.7,
            onPressed: () {
              // Shuffle toggle — would need native support
            },
          ),

        // Previous
        _ControlButton(
          icon: Icons.skip_previous,
          size: buttonSize,
          iconSize: iconSize,
          onPressed: controller.previous,
        ),

        const SizedBox(width: 8),

        // Play/Pause
        _PlayPauseButton(
          isPlaying: isPlaying,
          size: buttonSize,
          iconSize: iconSize,
          onPressed: controller.playPause,
        ),

        const SizedBox(width: 8),

        // Next
        _ControlButton(
          icon: Icons.skip_next,
          size: buttonSize,
          iconSize: iconSize,
          onPressed: controller.next,
        ),

        if (showRepeat)
          _ControlButton(
            icon: Icons.repeat,
            size: buttonSize,
            iconSize: iconSize * 0.7,
            onPressed: () {
              // Repeat toggle — would need native support
            },
          ),
      ],
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.size,
    required this.iconSize,
    required this.onPressed,
  });

  final IconData icon;
  final double size;
  final double iconSize;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: IconButton(
        icon: Icon(icon, color: Colors.white70, size: iconSize),
        onPressed: onPressed,
        padding: EdgeInsets.zero,
      ),
    );
  }
}

class _PlayPauseButton extends StatelessWidget {
  const _PlayPauseButton({
    required this.isPlaying,
    required this.size,
    required this.iconSize,
    required this.onPressed,
  });

  final bool isPlaying;
  final double size;
  final double iconSize;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Material(
        color: Colors.white.withValues(alpha: 0.15),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Icon(
            isPlaying ? Icons.pause : Icons.play_arrow,
            color: Colors.white,
            size: iconSize,
          ),
        ),
      ),
    );
  }
}
