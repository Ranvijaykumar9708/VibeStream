import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart'
    hide PlayerState, ProgressBar;

import '../../../data/data_sources/youtube_remote_source.dart';
import '../../../domain/entities/song.dart';
import '../../../services/download/download_service.dart';
import '../../common_widgets/song_artwork.dart';
import '../../common_widgets/glass_container.dart';
import '../../providers/music_providers.dart';

enum _PlaybackMode { video, audio }

class YouTubePlayerScreen extends ConsumerStatefulWidget {
  const YouTubePlayerScreen({super.key, required this.song});

  final Song song;

  @override
  ConsumerState<YouTubePlayerScreen> createState() =>
      _YouTubePlayerScreenState();
}

class _YouTubePlayerScreenState extends ConsumerState<YouTubePlayerScreen> {
  late final YoutubePlayerController _youtubeController;

  _PlaybackMode _playbackMode = _PlaybackMode.video;
  AppVideoQuality _selectedQuality = AppVideoQuality.medium;
  List<AppVideoQuality> _availableQualities = const [AppVideoQuality.medium];
  bool _isDownloadingAudio = false;
  bool _isDownloadingVideo = false;
  bool _isClosing = false;
  bool _showPlayer = true;

  String? get _videoId =>
      YouTubeRemoteSource.extractVideoId(widget.song.audioUrl) ??
      YouTubeRemoteSource.extractVideoId(widget.song.id);

  String get _watchUrl => _videoId == null
      ? 'https://www.youtube.com/'
      : YouTubeRemoteSource.buildWatchUrl(_videoId!);

  @override
  void initState() {
    super.initState();
    _youtubeController = YoutubePlayerController(
      initialVideoId: _videoId ?? '',
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        enableCaption: false,
        controlsVisibleAtStart: true,
      ),
    );
    _loadAvailableQualities();
  }

  @override
  void dispose() {
    try {
      _youtubeController.pause();
      _youtubeController.mute();
    } catch (_) {}
    _youtubeController.dispose();
    super.dispose();
  }

  Future<void> _closeScreen() async {
    if (_isClosing || !mounted) return;

    setState(() {
      _isClosing = true;
      _showPlayer = false;
    });

    try {
      _youtubeController.pause();
      _youtubeController.mute();
    } catch (_) {}

    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _loadAvailableQualities() async {
    final videoId = _videoId;
    if (videoId == null) return;

    try {
      final qualities = await ref
          .read(youtubeRemoteSourceProvider)
          .getAvailableQualities(videoId);
      if (!mounted) return;
      setState(() {
        _availableQualities = qualities;
        if (!qualities.contains(_selectedQuality)) {
          _selectedQuality = qualities.first;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _availableQualities = const [AppVideoQuality.medium];
        _selectedQuality = AppVideoQuality.medium;
      });
    }
  }

  Future<void> _switchPlaybackMode(_PlaybackMode mode) async {
    if (_playbackMode == mode) return;

    if (mode == _PlaybackMode.audio) {
      _youtubeController.play();
      _youtubeController.unMute();
      if (!mounted) return;
      setState(() => _playbackMode = _PlaybackMode.audio);
      return;
    }

    _youtubeController.play();
    if (!mounted) return;
    setState(() => _playbackMode = _PlaybackMode.video);
  }

  Future<void> _downloadAudio() async {
    setState(() => _isDownloadingAudio = true);
    try {
      final result = await DownloadService.downloadAudio(widget.song);
      _showMessage(
        result.isSuccess
            ? 'Audio downloaded to ${result.filePath}'
            : result.message ?? 'Unable to download the audio stream.',
      );
    } finally {
      if (mounted) {
        setState(() => _isDownloadingAudio = false);
      }
    }
  }

  Future<void> _downloadVideo() async {
    setState(() => _isDownloadingVideo = true);
    try {
      final result = await DownloadService.downloadVideo(
        widget.song,
        _selectedQuality,
      );
      _showMessage(
        result.isSuccess
            ? 'Video downloaded to ${result.filePath}'
            : result.message ?? 'Unable to download the video stream.',
      );
    } finally {
      if (mounted) {
        setState(() => _isDownloadingVideo = false);
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final playbackQuality =
        _youtubeController.value.playbackQuality?.toUpperCase() ?? 'AUTO';

    return PopScope(
      canPop: !_isClosing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _closeScreen();
        }
      },
      child: Scaffold(
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0C071C), Color(0xFF160D35), Color(0xFF080D21), Color(0xFF050F18)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _closeScreen,
                      icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const Expanded(
                      child: Column(
                        children: [
                          Text(
                            'YouTube Playback',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Video + Audio Controls',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        playbackQuality,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: SegmentedButton<_PlaybackMode>(
                  segments: const [
                    ButtonSegment(
                      value: _PlaybackMode.video,
                      icon: Icon(Icons.ondemand_video_rounded),
                      label: Text('Video'),
                    ),
                    ButtonSegment(
                      value: _PlaybackMode.audio,
                      icon: Icon(Icons.headphones_rounded),
                      label: Text('Audio'),
                    ),
                  ],
                  selected: {_playbackMode},
                  onSelectionChanged: (selection) {
                    _switchPlaybackMode(selection.first);
                  },
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: !_showPlayer
                      ? const SizedBox(
                          key: ValueKey('closing-player'),
                          height: 220,
                        )
                      : _playbackMode == _PlaybackMode.video
                      ? _VideoPanel(
                          key: const ValueKey('video-panel'),
                          controller: _youtubeController,
                        )
                      : _AudioPanel(
                          key: const ValueKey('audio-panel'),
                          song: widget.song,
                          controller: _youtubeController,
                        ),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _InfoCard(
                  title: 'Quality & Download',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Select the preferred quality for download. Audio downloads save an audio file. Video downloads include audio and video (muxed) up to 720p quality.',
                        style: TextStyle(color: Colors.white70, height: 1.4),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _availableQualities.map((quality) {
                          return ChoiceChip(
                            label: Text(_qualityLabel(quality)),
                            selected: quality == _selectedQuality,
                            onSelected: (_) {
                              setState(() => _selectedQuality = quality);
                            },
                            selectedColor: const Color(0xFF00C2A8),
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.08,
                            ),
                            labelStyle: TextStyle(
                              color: quality == _selectedQuality
                                  ? Colors.black
                                  : Colors.white,
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _isDownloadingAudio
                                  ? null
                                  : _downloadAudio,
                              icon: _isDownloadingAudio
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.audio_file_rounded),
                              label: const Text('Download Audio'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _isDownloadingVideo
                                  ? null
                                  : _downloadVideo,
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFFFFB703),
                              ),
                              icon: _isDownloadingVideo
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.download_for_offline_rounded,
                                    ),
                              label: Text(
                                'Video Track ${_qualityLabel(_selectedQuality)}',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SongArtwork(song: widget.song, size: 72, borderRadius: 18),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.song.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            widget.song.artist,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 12),
                          SelectableText(
                            _watchUrl,
                            style: const TextStyle(
                              color: Color(0xFF8DE7D9),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: _InfoCard(
                  title: 'Mode Notes',
                  child: Text(
                    'Video mode keeps the full embedded player. Audio mode switches to a dependable listen view while continuing playback through the YouTube player, which avoids fragile stream extraction failures.',
                    style: TextStyle(color: Colors.white70, height: 1.4),
                  ),
                ),
              ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _qualityLabel(AppVideoQuality quality) {
    switch (quality) {
      case AppVideoQuality.low:
        return '360p';
      case AppVideoQuality.medium:
        return '720p';
      case AppVideoQuality.high:
        return '1080p';
      case AppVideoQuality.hd:
        return '1440p';
      case AppVideoQuality.fullHd:
        return '2160p';
    }
  }
}

class _VideoPanel extends StatelessWidget {
  const _VideoPanel({super.key, required this.controller});

  final YoutubePlayerController controller;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: YoutubePlayer(
          controller: controller,
          showVideoProgressIndicator: true,
          progressIndicatorColor: const Color(0xFF00C2A8),
          progressColors: const ProgressBarColors(
            playedColor: Color(0xFF00C2A8),
            handleColor: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _AudioPanel extends StatelessWidget {
  const _AudioPanel({
    super.key,
    required this.song,
    required this.controller,
  });

  final Song song;
  final YoutubePlayerController controller;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.all(20),
      blur: 24.0,
      child: Column(
        children: [
          SongArtwork(song: song, size: 180, borderRadius: 26),
          const SizedBox(height: 18),
          Text(
            song.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(song.artist, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 18),
          ValueListenableBuilder<YoutubePlayerValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              final total = value.metaData.duration == Duration.zero
                  ? song.duration
                  : value.metaData.duration;
              return ProgressBar(
                progress: value.position,
                total: total,
                buffered: Duration(
                  milliseconds: (total.inMilliseconds * value.buffered).round(),
                ),
                progressBarColor: const Color(0xFF00C2A8),
                baseBarColor: Colors.white.withValues(alpha: 0.12),
                bufferedBarColor: Colors.white.withValues(alpha: 0.22),
                thumbColor: Colors.white,
                onSeek: controller.seekTo,
              );
            },
          ),
          const SizedBox(height: 12),
          ValueListenableBuilder<YoutubePlayerValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              final isPlaying = value.isPlaying;
              return FilledButton.icon(
                onPressed: () {
                  if (isPlaying) {
                    controller.pause();
                  } else {
                    controller.play();
                  }
                },
                icon: Icon(
                  isPlaying
                      ? Icons.pause_circle_filled_rounded
                      : Icons.play_circle_fill_rounded,
                ),
                label: Text(isPlaying ? 'Pause Audio' : 'Play Audio'),
              );
            },
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: controller.unMute,
            icon: const Icon(Icons.volume_up_rounded),
            label: const Text('Ensure Audio Is On'),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      blur: 16.0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
