import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../domain/entities/song.dart';
import '../../data/data_sources/youtube_remote_source.dart';
import '../storage/storage_service.dart';

/// Provider for the AudioHandler
final audioHandlerProvider = Provider<AudioPlayerHandler>((ref) {
  throw UnimplementedError('Initialized in main.dart');
});

/// A state model for the UI
class AudioState {
  final bool isPlaying;
  final Duration position;
  final Duration buffered;
  final Duration total;
  final Song? currentSong;
  final bool isShuffleModeEnabled;
  final AudioServiceRepeatMode repeatMode;

  AudioState({
    this.isPlaying = false,
    this.position = Duration.zero,
    this.buffered = Duration.zero,
    this.total = Duration.zero,
    this.currentSong,
    this.isShuffleModeEnabled = false,
    this.repeatMode = AudioServiceRepeatMode.none,
  });

  AudioState copyWith({
    bool? isPlaying,
    Duration? position,
    Duration? buffered,
    Duration? total,
    Song? currentSong,
    bool? isShuffleModeEnabled,
    AudioServiceRepeatMode? repeatMode,
  }) {
    return AudioState(
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      buffered: buffered ?? this.buffered,
      total: total ?? this.total,
      currentSong: currentSong ?? this.currentSong,
      isShuffleModeEnabled: isShuffleModeEnabled ?? this.isShuffleModeEnabled,
      repeatMode: repeatMode ?? this.repeatMode,
    );
  }
}

final audioStateProvider = NotifierProvider<AudioStateNotifier, AudioState>(
  AudioStateNotifier.new,
);

class AudioStateNotifier extends Notifier<AudioState> {
  late AudioPlayerHandler _handler;

  @override
  AudioState build() {
    _handler = ref.watch(audioHandlerProvider);

    final playbackSub = _handler.playbackState.listen((playbackState) {
      final isPlaying = playbackState.playing;
      final position = playbackState.position;
      final buffered = playbackState.bufferedPosition;
      final shuffleMode =
          playbackState.shuffleMode == AudioServiceShuffleMode.all;
      final repeatMode = playbackState.repeatMode;

      state = state.copyWith(
        isPlaying: isPlaying,
        position: position,
        buffered: buffered,
        isShuffleModeEnabled: shuffleMode,
        repeatMode: repeatMode,
      );
    });

    final mediaItemSub = _handler.mediaItem.listen((mediaItem) {
      if (mediaItem != null) {
        final song = Song(
          id: mediaItem.id,
          title: mediaItem.title,
          artist: mediaItem.artist ?? 'Unknown',
          album: mediaItem.album ?? 'Unknown',
          albumArtUrl: mediaItem.artUri?.toString() ?? '',
          audioUrl: mediaItem.extras?['url'] ?? '',
          duration: mediaItem.duration ?? Duration.zero,
          source: _songSourceFromId(mediaItem.id),
        );
        state = state.copyWith(
          total: mediaItem.duration ?? Duration.zero,
          currentSong: song,
        );
        StorageService.addRecentSong(song);
      }
    });

    final positionSub = _handler.positionStream.listen((position) {
      state = state.copyWith(position: position);
    });

    ref.onDispose(() {
      playbackSub.cancel();
      mediaItemSub.cancel();
      positionSub.cancel();
    });

    return AudioState();
  }

  void play() => _handler.play();
  void pause() => _handler.pause();
  void seek(Duration position) => _handler.seek(position);
  void skipToNext() => _handler.skipToNext();
  void skipToPrevious() => _handler.skipToPrevious();

  void setShuffleMode(AudioServiceShuffleMode mode) =>
      _handler.setShuffleMode(mode);
  void setRepeatMode(AudioServiceRepeatMode mode) =>
      _handler.setRepeatMode(mode);

  void playSong(Song song) {
    state = state.copyWith(currentSong: song);
    final item = MediaItem(
      id: song.id,
      title: song.title,
      artist: song.artist,
      album: song.album,
      artUri: Uri.tryParse(song.albumArtUrl),
      extras: {'url': song.audioUrl},
      duration: song.duration,
    );
    _handler.playMediaItem(item);
  }

  void loadPlaylist(List<Song> songs, {int initialIndex = 0}) {
    if (songs.isEmpty) return;

    final mediaItems = songs
        .map(
          (song) => MediaItem(
            id: song.id,
            title: song.title,
            artist: song.artist,
            album: song.album,
            artUri: Uri.tryParse(song.albumArtUrl),
            extras: {'url': song.audioUrl},
            duration: song.duration,
          ),
        )
        .toList();

    _handler.updateQueue(mediaItems);
    _handler.skipToQueueItem(initialIndex);
    _handler.play();
  }

  SongSource _songSourceFromId(String id) {
    if (id.startsWith('yt_')) return SongSource.youtube;
    if (id.startsWith('local_')) return SongSource.local;
    return SongSource.youtube;
  }

  /// Adds [song] to the end of the current audio queue without interrupting
  /// the currently playing track.
  void addToQueue(Song song) {
    final item = MediaItem(
      id: song.id,
      title: song.title,
      artist: song.artist,
      album: song.album,
      artUri: Uri.tryParse(song.albumArtUrl),
      extras: {'url': song.audioUrl},
      duration: song.duration,
    );
    _handler.addQueueItem(item);
  }
}

class AudioPlayerHandler extends BaseAudioHandler
    with SeekHandler, QueueHandler {
  final _player = AudioPlayer();
  List<AudioSource> _audioSources = const [];

  AudioPlayerHandler() {
    _init();
  }

  Future<void> _init() async {
    _notifyAudioHandlerAboutPlaybackEvents();

    // Listen to sequence state changes to update queue
    _player.sequenceStateStream.listen((sequenceState) {
      // Dart infers sequenceState as non-nullable from stream configuration
      final sequence = sequenceState.effectiveSequence;
      if (sequence.isEmpty) return;

      final items = sequence.map((source) => source.tag as MediaItem).toList();
      queue.add(items);

      final currentIndex = sequenceState.currentIndex;
      if (currentIndex != null &&
          currentIndex >= 0 &&
          currentIndex < items.length) {
        mediaItem.add(items[currentIndex]);
      }
    });

    try {
      await _player.setAudioSources(_audioSources);
    } catch (e) {
      debugPrint("Error initializing audio source: $e");
    }
  }

  void _notifyAudioHandlerAboutPlaybackEvents() {
    _player.playbackEventStream.listen((PlaybackEvent event) {
      final playing = _player.playing;
      playbackState.add(
        playbackState.value.copyWith(
          controls: [
            MediaControl.skipToPrevious,
            if (playing) MediaControl.pause else MediaControl.play,
            MediaControl.stop,
            MediaControl.skipToNext,
          ],
          systemActions: const {
            MediaAction.seek,
            MediaAction.seekForward,
            MediaAction.seekBackward,
          },
          processingState: const {
            ProcessingState.idle: AudioProcessingState.idle,
            ProcessingState.loading: AudioProcessingState.loading,
            ProcessingState.buffering: AudioProcessingState.buffering,
            ProcessingState.ready: AudioProcessingState.ready,
            ProcessingState.completed: AudioProcessingState.completed,
          }[_player.processingState]!,
          playing: playing,
          updatePosition: _player.position,
          bufferedPosition: _player.bufferedPosition,
          speed: _player.speed,
          queueIndex: event.currentIndex,
          repeatMode: _getAudioServiceRepeatMode(_player.loopMode),
          shuffleMode: _player.shuffleModeEnabled
              ? AudioServiceShuffleMode.all
              : AudioServiceShuffleMode.none,
        ),
      );
    });
  }

  AudioServiceRepeatMode _getAudioServiceRepeatMode(LoopMode mode) {
    switch (mode) {
      case LoopMode.off:
        return AudioServiceRepeatMode.none;
      case LoopMode.one:
        return AudioServiceRepeatMode.one;
      case LoopMode.all:
        return AudioServiceRepeatMode.all;
    }
  }

  @override
  Future<void> updateQueue(List<MediaItem> queue) async {
    final audioSources = <AudioSource>[];
    final playableItems = <MediaItem>[];
    for (final item in queue) {
      final source = await _createAudioSource(item);
      if (source != null) {
        audioSources.add(source);
        playableItems.add(item);
      }
    }

    if (audioSources.isEmpty) {
      _audioSources = const [];
      this.queue.add(const []);
      await _player.stop();
      return;
    }

    _audioSources = audioSources;
    await _player.setAudioSources(_audioSources);
    this.queue.add(playableItems);
  }

  Future<AudioSource?> _createAudioSource(MediaItem item) async {
    String url = item.extras!['url'] as String;

    // Resolve YouTube streams on the fly
    if (url.startsWith('yt_stream_')) {
      try {
        url = await YouTubeRemoteSource.getAudioStreamUrl(url);
      } catch (e) {
        debugPrint("Error extracting YouTube stream: $e");
        return null;
      }
    }

    final uri = url.startsWith('/') ? Uri.file(url) : Uri.tryParse(url);
    if (uri == null || (!uri.hasScheme && !url.startsWith('/'))) {
      debugPrint('Skipping unsupported audio URL: $url');
      return null;
    }

    // Determine if local or remote
    if (url.startsWith('/')) {
      // Local file path usually starts with /
      return AudioSource.uri(uri, tag: item);
    } else {
      // Network
      if (uri.scheme != 'http' && uri.scheme != 'https') {
        debugPrint('Skipping unsupported remote URL scheme: ${uri.scheme}');
        return null;
      }
      return AudioSource.uri(uri, tag: item);
    }
  }

  @override
  Future<void> addQueueItem(MediaItem mediaItem) async {
    final source = await _createAudioSource(mediaItem);
    if (source == null) return;

    final newQueue = [...queue.value, mediaItem];
    _audioSources = [..._audioSources, source];
    await _player.setAudioSources(
      _audioSources,
      initialIndex: _player.currentIndex,
      initialPosition: _player.position,
    );
    queue.add(newQueue);
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index >= 0 && index < _audioSources.length) {
      await _player.seek(Duration.zero, index: index);
    }
  }

  @override
  Future<void> playMediaItem(MediaItem mediaItem) async {
    // Standard quick play flushes the queue
    await updateQueue([mediaItem]);
    if (_audioSources.isEmpty) return;
    await _player.play();
  }

  Stream<Duration> get positionStream => _player.positionStream;

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> stop() async {
    await _player.stop();
    return super.stop();
  }

  @override
  Future<void> skipToNext() => _player.seekToNext();

  @override
  Future<void> skipToPrevious() => _player.seekToPrevious();

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    switch (repeatMode) {
      case AudioServiceRepeatMode.none:
        await _player.setLoopMode(LoopMode.off);
        break;
      case AudioServiceRepeatMode.one:
        await _player.setLoopMode(LoopMode.one);
        break;
      case AudioServiceRepeatMode.all:
      case AudioServiceRepeatMode.group:
        await _player.setLoopMode(LoopMode.all);
        break;
    }
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    if (shuffleMode == AudioServiceShuffleMode.none) {
      await _player.setShuffleModeEnabled(false);
    } else {
      if (_audioSources.length > 1) {
        await _player.shuffle();
      }
      await _player.setShuffleModeEnabled(true);
    }
  }

  @override
  Future<void> onTaskRemoved() => stop();

  @override
  Future<void> customAction(String name, [Map<String, dynamic>? extras]) {
    if (name == 'dispose') {
      return _player.dispose();
    }
    return super.customAction(name, extras);
  }

  /// Resolves a YouTube video ID to a direct audio stream URL.
  /// Returns null if resolution fails.
  Future<String?> resolveYouTubeAudioUrl(String songId) async {
    try {
      // songId may be 'yt_<videoId>' or a raw video ID
      final videoId = songId.startsWith('yt_')
          ? songId.substring(3)
          : songId;
      final streamUrl = await YouTubeRemoteSource.getAudioStreamUrl(
        'yt_stream_$videoId',
      );
      return streamUrl;
    } catch (e) {
      debugPrint('resolveYouTubeAudioUrl error: $e');
      return null;
    }
  }
}
