/// Media Center — full-screen glassmorphic media player page.
library;

import 'package:car_launcher/shared/widgets/car_responsive.dart';
import 'package:car_launcher/core/theme/carplay_theme.dart';
import 'package:car_launcher/features/media/domain/media_session_model.dart';
import 'package:car_launcher/features/media/data/media_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Full-screen Media Center page.
class MediaCenterPage extends ConsumerStatefulWidget {
  const MediaCenterPage({super.key});

  @override
  ConsumerState<MediaCenterPage> createState() => _MediaCenterPageState();
}

class _MediaCenterPageState extends ConsumerState<MediaCenterPage> {
  bool _shuffleEnabled = false;
  bool _repeatEnabled = false;
  double _volume = 0.65;

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(mediaControllerProvider);
    final controller = ref.read(mediaControllerProvider.notifier);
    final isPlaying = session.isPlaying;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildBackgroundGlow(),
          _buildMainContent(
            session: session,
            controller: controller,
            isPlaying: isPlaying,
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundGlow() {
    return Center(
      child: Container(
        width: 800,
        height: 800,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              CarPlayTheme.neonCyan.withValues(alpha: 0.05),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainContent({
    required MediaSessionModel session,
    required MediaController controller,
    required bool isPlaying,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: CarPlayTheme.gutter),
      child: Row(
        children: [
          // Right: Controls & Info
          Expanded(
            flex: 7,
            child: _ControlsSection(
              session: session,
              controller: controller,
              isPlaying: isPlaying,
              shuffleEnabled: _shuffleEnabled,
              repeatEnabled: _repeatEnabled,
              volume: _volume,
              onShuffleToggle: () {
                setState(() => _shuffleEnabled = !_shuffleEnabled);
              },
              onRepeatToggle: () {
                setState(() => _repeatEnabled = !_repeatEnabled);
              },
              onVolumeChanged: (value) {
                setState(() => _volume = value);
              },
            ),
          ),
          // Spacing
          const SizedBox(width: CarPlayTheme.gutter),
          // Left: Album Art
          Expanded(
            flex: 5,
            child: _AlbumArtSection(session: session, isPlaying: isPlaying),
          ),
        ],
      ),
    );
  }
}
// ─── Album Art Section ──────────────────────────────────────────────────────

class _AlbumArtSection extends StatelessWidget {
  const _AlbumArtSection({required this.session, required this.isPlaying});

  final MediaSessionModel session;
  final bool isPlaying;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AspectRatio(
        aspectRatio: 1,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 500),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: CarPlayTheme.glassSurface,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 40,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Album art image or placeholder
                _buildAlbumArtImage(),
                // Gradient overlay at bottom
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  height: 120,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          CarPlayTheme.deepObsidian.withValues(alpha: 0.6),
                        ],
                      ),
                    ),
                  ),
                ),
                // Dolby Atmos / Playing indicator overlay
                Positioned(
                  bottom: 24,
                  right: 24,
                  child: _buildPlaybackIndicator(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAlbumArtImage() {
    if (session.albumArtUrl.isNotEmpty) {
      return Image.network(
        session.albumArtUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _buildPlaceholder(),
      );
    }
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      color: CarPlayTheme.surfaceContainerLow,
      child: Center(
        child: Icon(
          Icons.music_note,
          size: 80,
          color: Colors.white.withValues(alpha: 0.15),
        ),
      ),
    );
  }

  Widget _buildPlaybackIndicator() {
    if (!isPlaying) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: CarPlayTheme.neonCyan.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: CarPlayTheme.neonCyan.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: CarPlayTheme.neonCyan.withValues(alpha: 0.15),
            blurRadius: 12,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _AnimatedBars(),
          const SizedBox(width: 8),
          Text(
            'Dolby Atmos',
            style: TextStyle(
              color: CarPlayTheme.neonCyan,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Animated Equalizer Bars ────────────────────────────────────────────────

class _AnimatedBars extends StatefulWidget {
  @override
  State<_AnimatedBars> createState() => _AnimatedBarsState();
}

class _AnimatedBarsState extends State<_AnimatedBars>
    with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      3,
      (i) => AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 400 + i * 150),
      ),
    );
    _animations = _controllers.map((c) {
      return Tween<double>(
        begin: 0.3,
        end: 1.0,
      ).animate(CurvedAnimation(parent: c, curve: Curves.easeInOut));
    }).toList();

    for (var i = 0; i < _controllers.length; i++) {
      Future.delayed(Duration(milliseconds: i * 75), () {
        if (mounted) {
          _controllers[i].repeat(reverse: true);
        }
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 16,
      height: 12,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(3, (i) {
          return AnimatedBuilder(
            animation: _animations[i],
            builder: (context, _) {
              return Container(
                width: 3,
                height: 12 * _animations[i].value,
                decoration: BoxDecoration(
                  color: CarPlayTheme.neonCyan,
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            },
          );
        }),
      ),
    );
  }
}

// ─── Controls Section ───────────────────────────────────────────────────────

class _ControlsSection extends StatelessWidget {
  const _ControlsSection({
    required this.session,
    required this.controller,
    required this.isPlaying,
    required this.shuffleEnabled,
    required this.repeatEnabled,
    required this.volume,
    required this.onShuffleToggle,
    required this.onRepeatToggle,
    required this.onVolumeChanged,
  });

  final MediaSessionModel session;
  final MediaController controller;
  final bool isPlaying;
  final bool shuffleEnabled;
  final bool repeatEnabled;
  final double volume;
  final VoidCallback onShuffleToggle;
  final VoidCallback onRepeatToggle;
  final ValueChanged<double> onVolumeChanged;

  @override
  Widget build(BuildContext context) {
    final compact = CarResponsive.isCompact(context);
    final short = CarResponsive.isShort(context);
    return Padding(
      padding: EdgeInsets.only(left: compact ? 12 : 32, top: short ? 8 : 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Top label
          Text(
            'Currently Streaming',
            style: TextStyle(
              color: CarPlayTheme.neonCyan,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 2.0,
            ),
          ),
          SizedBox(height: short ? 4 : 12),
          // Track title
          Text(
            session.title.isNotEmpty ? session.title : 'No Track',
            style: TextStyle(
              color: CarPlayTheme.safetyWhite,
              fontSize: compact ? 42 : 64,
              fontWeight: FontWeight.bold,
              height: 1.05,
              letterSpacing: -0.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          // Artist & album
          Text(
            session.artist.isNotEmpty
                ? '${session.artist}${session.album.isNotEmpty ? ' • ${session.album}' : ''}'
                : 'Unknown Artist',
            style: TextStyle(
              color: CarPlayTheme.onSurfaceVariant,
              fontSize: 20,
              fontWeight: FontWeight.w400,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: short ? 16 : 40),
          // Progress bar
          _ProgressBarSection(session: session, controller: controller),
          SizedBox(height: short ? 16 : 40),
          // Playback controls
          _PlaybackControlRow(
            isPlaying: isPlaying,
            shuffleEnabled: shuffleEnabled,
            repeatEnabled: repeatEnabled,
            onShuffleToggle: onShuffleToggle,
            onRepeatToggle: onRepeatToggle,
            onPlayPause: controller.playPause,
            onPrevious: controller.previous,
            onNext: controller.next,
          ),
          SizedBox(height: short ? 16 : 40),
          // Volume & actions
          if (!short)
            _VolumeAndActionsRow(
              volume: volume,
              onVolumeChanged: onVolumeChanged,
            ),
          // Spacer to keep controls centered-ish
          const Spacer(flex: 2),
        ],
      ),
    );
  }
}

// ─── Progress Bar ───────────────────────────────────────────────────────────

class _ProgressBarSection extends StatelessWidget {
  const _ProgressBarSection({required this.session, required this.controller});

  final MediaSessionModel session;
  final MediaController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Progress track
        SizedBox(
          height: 12,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return GestureDetector(
                onTapDown: (details) {
                  if (session.durationMs > 0) {
                    final fraction =
                        details.localPosition.dx / constraints.maxWidth;
                    final posMs = (fraction * session.durationMs).round();
                    controller.seekTo(posMs);
                  }
                },
                onHorizontalDragUpdate: (details) {
                  if (session.durationMs > 0) {
                    final fraction =
                        (details.localPosition.dx / constraints.maxWidth).clamp(
                          0.0,
                          1.0,
                        );
                    final posMs = (fraction * session.durationMs).round();
                    controller.seekTo(posMs);
                  }
                },
                child: Container(
                  width: constraints.maxWidth,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Stack(
                    children: [
                      FractionallySizedBox(
                        widthFactor: session.progress,
                        child: Container(
                          decoration: BoxDecoration(
                            color: CarPlayTheme.neonCyan,
                            borderRadius: BorderRadius.circular(999),
                            boxShadow: [
                              BoxShadow(
                                color: CarPlayTheme.neonCyan.withValues(
                                  alpha: 0.5,
                                ),
                                blurRadius: 15,
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Thumb indicator
                      Positioned(
                        left: session.progress * (constraints.maxWidth - 24),
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: CarPlayTheme.neonCyan,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: CarPlayTheme.neonCyan.withValues(
                                    alpha: 0.6,
                                  ),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        // Time labels
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              session.positionFormatted,
              style: TextStyle(
                color: CarPlayTheme.onSurfaceVariant,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              session.durationFormatted,
              style: TextStyle(
                color: CarPlayTheme.onSurfaceVariant,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Playback Controls Row ──────────────────────────────────────────────────

class _PlaybackControlRow extends StatelessWidget {
  const _PlaybackControlRow({
    required this.isPlaying,
    required this.shuffleEnabled,
    required this.repeatEnabled,
    required this.onShuffleToggle,
    required this.onRepeatToggle,
    required this.onPlayPause,
    required this.onPrevious,
    required this.onNext,
  });

  final bool isPlaying;
  final bool shuffleEnabled;
  final bool repeatEnabled;
  final VoidCallback onShuffleToggle;
  final VoidCallback onRepeatToggle;
  final VoidCallback onPlayPause;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        // Shuffle
        _SideButton(
          icon: Icons.shuffle,
          onPressed: onShuffleToggle,
          isActive: shuffleEnabled,
        ),
        // Previous
        _RoundButton(
          icon: Icons.skip_previous,
          size: 64,
          iconSize: 48,
          onPressed: onPrevious,
        ),
        // Play/Pause (Hero button)
        _PlayPauseButton(isPlaying: isPlaying, onPressed: onPlayPause),
        // Next
        _RoundButton(
          icon: Icons.skip_next,
          size: 64,
          iconSize: 48,
          onPressed: onNext,
        ),
        // Repeat
        _SideButton(
          icon: Icons.repeat_one,
          onPressed: onRepeatToggle,
          isActive: repeatEnabled,
        ),
      ],
    );
  }
}

class _SideButton extends StatelessWidget {
  const _SideButton({
    required this.icon,
    required this.onPressed,
    this.isActive = false,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(
        icon,
        color: isActive ? CarPlayTheme.neonCyan : CarPlayTheme.onSurfaceVariant,
        size: 36,
      ),
      splashRadius: 28,
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
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
      child: Material(
        color: Colors.white.withValues(alpha: 0.05),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Icon(icon, color: CarPlayTheme.safetyWhite, size: iconSize),
        ),
      ),
    );
  }
}

class _PlayPauseButton extends StatelessWidget {
  const _PlayPauseButton({required this.isPlaying, required this.onPressed});

  final bool isPlaying;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      height: 96,
      child: Material(
        color: CarPlayTheme.neonCyan,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Icon(
            isPlaying ? Icons.pause : Icons.play_arrow,
            color: CarPlayTheme.deepObsidian,
            size: 56,
            fill: 1.0,
          ),
        ),
      ),
    );
  }
}

// ─── Volume & Actions Row ───────────────────────────────────────────────────

class _VolumeAndActionsRow extends StatelessWidget {
  const _VolumeAndActionsRow({
    required this.volume,
    required this.onVolumeChanged,
  });

  final double volume;
  final ValueChanged<double> onVolumeChanged;

  @override
  Widget build(BuildContext context) {
    final compact = CarResponsive.isCompact(context);
    return Container(
      padding: EdgeInsets.all(compact ? 12 : 24),
      decoration: BoxDecoration(
        color: CarPlayTheme.glassSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          // Volume icon
          Icon(Icons.volume_up, color: CarPlayTheme.onSurfaceVariant, size: 28),
          const SizedBox(width: 16),
          // Volume slider
          Expanded(
            child: _VolumeSlider(value: volume, onChanged: onVolumeChanged),
          ),
          // Divider
          if (!compact)
            Container(
              width: 1,
              height: 40,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              color: Colors.white.withValues(alpha: 0.1),
            ),
          // Save / Favorite
          if (!compact)
            _ActionButton(
              icon: Icons.favorite,
              label: 'Save',
              onPressed: () {
                // TODO: implement favorite
              },
            ),
          if (!compact) const SizedBox(width: 24),
          // Add to Queue
          if (!compact)
            _ActionButton(
              icon: Icons.playlist_add,
              label: 'Add to Queue',
              onPressed: () {
                // TODO: implement add to queue
              },
            ),
        ],
      ),
    );
  }
}

class _VolumeSlider extends StatelessWidget {
  const _VolumeSlider({required this.value, required this.onChanged});

  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (details) {
        final renderBox = context.findRenderObject()! as RenderBox;
        final fraction = details.localPosition.dx / renderBox.size.width;
        onChanged(fraction.clamp(0.0, 1.0));
      },
      onHorizontalDragUpdate: (details) {
        final renderBox = context.findRenderObject()! as RenderBox;
        final fraction = (details.localPosition.dx / renderBox.size.width)
            .clamp(0.0, 1.0);
        onChanged(fraction);
      },
      child: SizedBox(
        height: 24,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              clipBehavior: Clip.none,
              children: [
                // Track background
                Positioned(
                  top: 6,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                // Filled track
                Positioned(
                  top: 6,
                  left: 0,
                  child: Container(
                    height: 12,
                    width: value * constraints.maxWidth,
                    decoration: BoxDecoration(
                      color: CarPlayTheme.neonCyan,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                // Thumb
                Positioned(
                  top: 0,
                  left: value * (constraints.maxWidth - 24),
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: CarPlayTheme.neonCyan,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: CarPlayTheme.neonCyan.withValues(alpha: 0.6),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: CarPlayTheme.onSurfaceVariant, size: 28),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: CarPlayTheme.onSurfaceVariant,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
