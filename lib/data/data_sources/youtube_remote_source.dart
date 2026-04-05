import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../../domain/entities/song.dart';

class YouTubeDownloadException implements Exception {
  const YouTubeDownloadException(this.message, {this.isRateLimited = false});

  final String message;
  final bool isRateLimited;

  @override
  String toString() => message;
}

class YouTubeRemoteSource {
  static final YouTubeRemoteSource _shared = YouTubeRemoteSource._internal();

  factory YouTubeRemoteSource() => _shared;

  YouTubeRemoteSource._internal();

  YoutubeExplode? _yt = YoutubeExplode();

  YoutubeExplode get _client {
    _yt ??= YoutubeExplode();
    return _yt!;
  }

  Future<List<Song>> searchSongs(String query) async {
    final results = await _client.search.search(query);
    return results.take(10).map((video) {
      return Song(
        id: "yt_${video.id.value}",
        title: video.title,
        artist: video.author,
        album: "YouTube Music",
        albumArtUrl: video.thumbnails.highResUrl,
        audioUrl: "yt_stream_${video.id.value}",
        duration: video.duration ?? Duration.zero,
        source: SongSource.youtube,
        videoQuality: AppVideoQuality.medium, // Default quality
        videoUrl: "yt_video_${video.id.value}",
      );
    }).toList();
  }

  /// Get available video qualities for a video
  Future<List<AppVideoQuality>> getAvailableQualities(String videoId) async {
    final cleanId = extractVideoId(videoId);
    if (cleanId == null) return [AppVideoQuality.medium];
    final manifest = await _client.videos.streamsClient.getManifest(cleanId);
    final qualities = <AppVideoQuality>[];

    if (manifest.muxed.any((s) => s.qualityLabel.contains('360'))) {
      qualities.add(AppVideoQuality.low);
    }
    if (manifest.muxed.any((s) => s.qualityLabel.contains('720'))) {
      qualities.add(AppVideoQuality.medium);
    }
    if (manifest.muxed.any((s) => s.qualityLabel.contains('1080'))) {
      qualities.add(AppVideoQuality.high);
    }
    if (manifest.muxed.any((s) => s.qualityLabel.contains('1440'))) {
      qualities.add(AppVideoQuality.hd);
    }
    if (manifest.muxed.any((s) => s.qualityLabel.contains('2160'))) {
      qualities.add(AppVideoQuality.fullHd);
    }

    return qualities.isEmpty ? [AppVideoQuality.low, AppVideoQuality.medium] : qualities;
  }

  /// Extracts the direct audio stream URL required for just_audio
  static Future<String> getAudioStreamUrl(String videoId) async {
    final cleanId = extractVideoId(videoId);
    if (cleanId == null) {
      throw ArgumentError('Invalid YouTube video id: $videoId');
    }
    final manifest = await YouTubeRemoteSource()
        ._client
        .videos
        .streamsClient
        .getManifest(cleanId);
    final audioStream = manifest.audioOnly.withHighestBitrate();
    return audioStream.url.toString();
  }

  /// Get video stream URL for specific quality
  Future<String> getVideoStreamUrl(
    String videoId,
    AppVideoQuality quality,
  ) async {
    final cleanId = extractVideoId(videoId);
    if (cleanId == null) {
      throw ArgumentError('Invalid YouTube video id: $videoId');
    }
    final manifest = await _client.videos.streamsClient.getManifest(cleanId);

    final videoStreams = manifest.muxed.where((stream) {
      switch (quality) {
        case AppVideoQuality.low:
          return stream.qualityLabel.contains('360');
        case AppVideoQuality.medium:
          return stream.qualityLabel.contains('720');
        case AppVideoQuality.high:
          return stream.qualityLabel.contains('1080');
        case AppVideoQuality.hd:
          return stream.qualityLabel.contains('1440');
        case AppVideoQuality.fullHd:
          return stream.qualityLabel.contains('2160');
      }
    }).toList();

    if (videoStreams.isEmpty) {
      // Fallback to any available muxed stream
      if (manifest.muxed.isNotEmpty) {
        return manifest.muxed.first.url.toString();
      } else {
        return manifest.videoOnly.first.url.toString();
      }
    }

    // Get the highest bitrate for the selected quality
    videoStreams.sort((a, b) => b.bitrate.compareTo(a.bitrate));
    return videoStreams.first.url.toString();
  }

  /// Download audio from YouTube video
  Future<String?> downloadAudio(
    String videoId, {
    String? customFileName,
  }) async {
    final cleanId = extractVideoId(videoId);
    if (cleanId == null) {
      throw const YouTubeDownloadException(
        'This track does not have a valid YouTube video id.',
      );
    }

    try {
      final video = await _client.videos.get(cleanId);
      final manifest = await _client.videos.streamsClient.getManifest(cleanId);
      final audioStream = manifest.audioOnly.withHighestBitrate();

      final dir = await getApplicationDocumentsDirectory();
      final fileName =
          customFileName ??
          '${video.title}.mp3'.replaceAll(RegExp(r'[^\w\s.-]'), '_');
      final file = File('${dir.path}/downloads/$fileName');

      await file.parent.create(recursive: true);

      final stream = _client.videos.streamsClient.get(audioStream);
      final fileStream = file.openWrite();

      await stream.pipe(fileStream);
      await fileStream.flush();
      await fileStream.close();

      return file.path;
    } catch (e) {
      throw _mapDownloadError(
        e,
        fallbackMessage: 'Audio download is unavailable right now.',
      );
    }
  }

  /// Download video from YouTube
  Future<String?> downloadVideo(
    String videoId,
    AppVideoQuality quality, {
    String? customFileName,
  }) async {
    final cleanId = extractVideoId(videoId);
    if (cleanId == null) {
      throw const YouTubeDownloadException(
        'This track does not have a valid YouTube video id.',
      );
    }

    HttpClient? httpClient;
    try {
      final video = await _client.videos.get(cleanId);
      final streamUrl = await getVideoStreamUrl(videoId, quality);

      final dir = await getApplicationDocumentsDirectory();
      final fileName =
          customFileName ??
          '${video.title}_${quality.name}.mp4'.replaceAll(
            RegExp(r'[^\w\s.-]'),
            '_',
          );
      final file = File('${dir.path}/downloads/$fileName');

      await file.parent.create(recursive: true);

      httpClient = HttpClient();
      final request = await httpClient.getUrl(Uri.parse(streamUrl));
      final response = await request.close();
      final fileStream = file.openWrite();

      await response.pipe(fileStream);
      await fileStream.flush();
      await fileStream.close();

      return file.path;
    } catch (e) {
      throw _mapDownloadError(
        e,
        fallbackMessage: 'Video download is unavailable right now.',
      );
    } finally {
      httpClient?.close();
    }
  }

  YouTubeDownloadException _mapDownloadError(
    Object error, {
    required String fallbackMessage,
  }) {
    final text = error.toString();
    if (text.contains('RequestLimitExceededException')) {
      return const YouTubeDownloadException(
        'YouTube is rate-limiting this connection right now. Wait a bit and try the download again.',
        isRateLimited: true,
      );
    }
    return YouTubeDownloadException(fallbackMessage);
  }

  static String? extractVideoId(String value) {
    if (value.startsWith('yt_stream_')) {
      return value.replaceFirst('yt_stream_', '');
    }
    if (value.startsWith('yt_video_')) {
      return value.replaceFirst('yt_video_', '');
    }
    if (value.startsWith('yt_')) {
      return value.replaceFirst('yt_', '');
    }
    return VideoId.parseVideoId(value);
  }

  static String buildWatchUrl(String videoId) {
    return 'https://www.youtube.com/watch?v=$videoId';
  }

  void dispose() {
    _yt?.close();
    _yt = null;
  }
}
