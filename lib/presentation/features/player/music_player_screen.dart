import 'package:audio_service/audio_service.dart';
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../data/data_sources/youtube_remote_source.dart';
import '../../../domain/entities/song.dart';
import '../../../services/audio/audio_player_service.dart';
import '../../../services/storage/storage_service.dart';
import '../../common_widgets/glass_container.dart';
import '../../common_widgets/song_artwork.dart';
import '../../common_widgets/song_palette_builder.dart';
import '../../providers/music_providers.dart';

class MusicPlayerScreen extends ConsumerWidget {
  const MusicPlayerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioState = ref.watch(audioStateProvider);
    final favorites =
        ref.watch(favoritesProvider).asData?.value ?? const <String>{};
    final song = audioState.currentSong;

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: song == null
          ? const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF0B1020),
                    Color(0xFF090814),
                    Color(0xFF04060F),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: SafeArea(
                child: Center(
                  child: Text(
                    'Pick a song to start playing.',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ),
            )
          : SongPaletteBuilder(
              song: song,
              builder: (context, palette) {
                return DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        palette.primary.withValues(alpha: 0.42),
                        const Color(0xFF0A071E),
                        palette.secondary.withValues(alpha: 0.18),
                        const Color(0xFF04060F),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Positioned(
                        top: -120,
                        left: -40,
                        child: _AmbientGlow(color: palette.primary),
                      ),
                      Positioned(
                        bottom: -140,
                        right: -30,
                        child: _AmbientGlow(color: palette.secondary),
                      ),
                      SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            children: [
                              _PlayerHeader(
                                onClose: () => Navigator.pop(context),
                                onShare: () => _shareSong(song),
                              ),
                              const SizedBox(height: 16),
                              Expanded(
                                child: SingleChildScrollView(
                                  child: Column(
                                    children: [
                                      _ArtworkStage(song: song, palette: palette),
                                      const SizedBox(height: 28),
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  song.title,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 30,
                                                    fontWeight: FontWeight.w800,
                                                    letterSpacing: -0.8,
                                                  ),
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  '${song.artist} • ${song.album}',
                                                  style: TextStyle(
                                                    color: Colors.white
                                                        .withValues(alpha: 0.72),
                                                    fontSize: 15,
                                                  ),
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          _ReactiveIconButton(
                                            icon: favorites.contains(song.id)
                                                ? Icons.favorite_rounded
                                                : Icons.favorite_border_rounded,
                                            color: favorites.contains(song.id)
                                                ? const Color(0xFFFF6B6B)
                                                : Colors.white,
                                            onTap: () => StorageService
                                                .toggleFavorite(song.id),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          _PlayerBadge(
                                            label: song.isLocal
                                                ? 'Local Source'
                                                : 'Streaming Source',
                                            tint: palette.primary,
                                          ),
                                          _PlayerBadge(
                                            label:
                                                '${audioState.total.inMinutes}:${audioState.total.inSeconds.remainder(60).toString().padLeft(2, '0')} runtime',
                                            tint: palette.secondary,
                                          ),
                                          _PlayerBadge(
                                            label: audioState.isPlaying
                                                ? 'Now Active'
                                                : 'Paused',
                                            tint: Colors.white,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 24),
                                      GlassContainer(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(18),
                                        blur: 18.0,
                                        color: Colors.white.withValues(
                                          alpha: 0.06,
                                        ),
                                        border: Border.all(
                                          color: palette.primary
                                              .withValues(alpha: 0.18),
                                        ),
                                        child: Column(
                                          children: [
                                            ProgressBar(
                                              progress: audioState.position,
                                              buffered: audioState.buffered,
                                              total: audioState.total,
                                              onSeek: (duration) => ref
                                                  .read(
                                                    audioStateProvider.notifier,
                                                  )
                                                  .seek(duration),
                                              progressBarColor:
                                                  palette.primary,
                                              baseBarColor: Colors.white
                                                  .withValues(alpha: 0.14),
                                              bufferedBarColor: Colors.white
                                                  .withValues(alpha: 0.25),
                                              thumbColor: Colors.white,
                                              thumbGlowColor: palette.glow,
                                              barHeight: 5,
                                              thumbRadius: 7,
                                              timeLabelTextStyle: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 12,
                                              ),
                                            ),
                                            const SizedBox(height: 18),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                _ModeButton(
                                                  icon: Icons.shuffle_rounded,
                                                  isActive: audioState
                                                      .isShuffleModeEnabled,
                                                  activeColor: palette.primary,
                                                  onTap: () {
                                                    ref
                                                        .read(
                                                          audioStateProvider
                                                              .notifier,
                                                        )
                                                        .setShuffleMode(
                                                          audioState
                                                                  .isShuffleModeEnabled
                                                              ? AudioServiceShuffleMode
                                                                  .none
                                                              : AudioServiceShuffleMode
                                                                  .all,
                                                        );
                                                  },
                                                ),
                                                _TransportButton(
                                                  icon: Icons.skip_previous_rounded,
                                                  onTap: () => ref
                                                      .read(
                                                        audioStateProvider
                                                            .notifier,
                                                      )
                                                      .skipToPrevious(),
                                                ),
                                                _PlayButton(
                                                  isPlaying:
                                                      audioState.isPlaying,
                                                  color: palette.primary,
                                                  glow: palette.glow,
                                                  onTap: () {
                                                    final notifier = ref.read(
                                                      audioStateProvider
                                                          .notifier,
                                                    );
                                                    audioState.isPlaying
                                                        ? notifier.pause()
                                                        : notifier.play();
                                                  },
                                                ),
                                                _TransportButton(
                                                  icon: Icons.skip_next_rounded,
                                                  onTap: () => ref
                                                      .read(
                                                        audioStateProvider
                                                            .notifier,
                                                      )
                                                      .skipToNext(),
                                                ),
                                                _ModeButton(
                                                  icon: _repeatIcon(
                                                    audioState.repeatMode,
                                                  ),
                                                  isActive: audioState
                                                          .repeatMode !=
                                                      AudioServiceRepeatMode
                                                          .none,
                                                  activeColor:
                                                      palette.secondary,
                                                  onTap: () {
                                                    ref
                                                        .read(
                                                          audioStateProvider
                                                              .notifier,
                                                        )
                                                        .setRepeatMode(
                                                          _nextRepeatMode(
                                                            audioState
                                                                .repeatMode,
                                                          ),
                                                        );
                                                  },
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 18),
                                      GlassContainer(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(18),
                                        blur: 18.0,
                                        color: Colors.white.withValues(
                                          alpha: 0.05,
                                        ),
                                        border: Border.all(
                                          color: Colors.white.withValues(
                                            alpha: 0.08,
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Container(
                                                  width: 34,
                                                  height: 34,
                                                  decoration: BoxDecoration(
                                                    color: palette.secondary
                                                        .withValues(alpha: 0.16),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                  ),
                                                  child: Icon(
                                                    Icons.auto_awesome_rounded,
                                                    color: palette.secondary,
                                                    size: 18,
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                const Text(
                                                  'Session Notes',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 12),
                                            Text(
                                              song.isLocal
                                                  ? 'Playing from your device library with background audio controls enabled.'
                                                  : 'Streaming audio from YouTube with share support and persistent queue controls.',
                                              style: TextStyle(
                                                color: Colors.white.withValues(
                                                  alpha: 0.74,
                                                ),
                                                height: 1.45,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 32),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Future<void> _shareSong(Song song) async {
    final videoId =
        YouTubeRemoteSource.extractVideoId(song.audioUrl) ??
        YouTubeRemoteSource.extractVideoId(song.id);

    if (song.isLocal && song.audioUrl.startsWith('/')) {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(song.audioUrl)],
          text: '${song.title} by ${song.artist}',
        ),
      );
      return;
    }

    final link = videoId == null
        ? '${song.title} by ${song.artist}'
        : YouTubeRemoteSource.buildWatchUrl(videoId);
    await SharePlus.instance.share(
      ShareParams(text: '${song.title} by ${song.artist}\n$link'),
    );
  }

  static IconData _repeatIcon(AudioServiceRepeatMode repeatMode) {
    return repeatMode == AudioServiceRepeatMode.one
        ? Icons.repeat_one_rounded
        : Icons.repeat_rounded;
  }

  static AudioServiceRepeatMode _nextRepeatMode(
    AudioServiceRepeatMode repeatMode,
  ) {
    switch (repeatMode) {
      case AudioServiceRepeatMode.none:
        return AudioServiceRepeatMode.all;
      case AudioServiceRepeatMode.all:
      case AudioServiceRepeatMode.group:
        return AudioServiceRepeatMode.one;
      case AudioServiceRepeatMode.one:
        return AudioServiceRepeatMode.none;
    }
  }
}

class _AmbientGlow extends StatelessWidget {
  const _AmbientGlow({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: 260,
        height: 260,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: 0.42),
              color.withValues(alpha: 0.0),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayerHeader extends StatelessWidget {
  const _PlayerHeader({required this.onClose, required this.onShare});

  final VoidCallback onClose;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ReactiveIconButton(
          icon: Icons.keyboard_arrow_down_rounded,
          color: Colors.white,
          onTap: onClose,
        ),
        const Expanded(
          child: Column(
            children: [
              Text(
                'Now Playing',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              SizedBox(height: 2),
              Text(
                'Personal Queue',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        _ReactiveIconButton(
          icon: Icons.share_rounded,
          color: Colors.white,
          onTap: onShare,
        ),
      ],
    );
  }
}

class _ArtworkStage extends StatelessWidget {
  const _ArtworkStage({required this.song, required this.palette});

  final Song song;
  final SongPalette palette;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 320,
          height: 320,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                palette.primary.withValues(alpha: 0.32),
                palette.secondary.withValues(alpha: 0.08),
                Colors.transparent,
              ],
            ),
          ),
        ),
        GlassContainer(
          width: double.infinity,
          height: 380,
          blur: 32.0,
          padding: const EdgeInsets.all(18),
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(36),
          border: Border.all(color: palette.primary.withValues(alpha: 0.24)),
          child: Hero(
            tag: 'song-artwork-${song.id}',
            child: SongArtwork(
              song: song,
              size: 380,
              borderRadius: 30,
            ),
          ),
        ),
      ],
    );
  }
}

class _ReactiveIconButton extends StatelessWidget {
  const _ReactiveIconButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Icon(icon, color: color),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.icon,
    required this.isActive,
    required this.activeColor,
    required this.onTap,
  });

  final IconData icon;
  final bool isActive;
  final Color activeColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isActive
              ? activeColor.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isActive
                ? activeColor.withValues(alpha: 0.32)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Icon(
          icon,
          color: isActive ? activeColor : Colors.white70,
        ),
      ),
    );
  }
}

class _TransportButton extends StatelessWidget {
  const _TransportButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 42, color: Colors.white),
      onPressed: onTap,
    );
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({
    required this.isPlaying,
    required this.color,
    required this.glow,
    required this.onTap,
  });

  final bool isPlaying;
  final Color color;
  final Color glow;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 84,
      height: 84,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Colors.white, color.withValues(alpha: 0.9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(color: glow, blurRadius: 28, offset: const Offset(0, 10)),
        ],
      ),
      child: IconButton(
        icon: Icon(
          isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
          size: 42,
          color: Colors.black,
        ),
        onPressed: onTap,
      ),
    );
  }
}

class _PlayerBadge extends StatelessWidget {
  const _PlayerBadge({required this.label, required this.tint});

  final String label;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tint.withValues(alpha: 0.24)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: tint == Colors.white ? Colors.white : tint,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}
