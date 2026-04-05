import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/data_sources/youtube_remote_source.dart';
import '../../domain/entities/song.dart';

class DownloadResult {
  const DownloadResult._({this.filePath, this.message});

  final String? filePath;
  final String? message;

  bool get isSuccess => filePath != null;

  static DownloadResult success(String filePath) =>
      DownloadResult._(filePath: filePath);

  static DownloadResult failure(String message) =>
      DownloadResult._(message: message);
}

class DownloadService {
  static Future<DownloadResult> downloadAudio(
    Song song, {
    String? customFileName,
  }) async {
    try {
      if (song.source == SongSource.youtube) {
        final filePath = await YouTubeRemoteSource().downloadAudio(
          song.id,
          customFileName: customFileName,
        );
        return filePath == null
            ? DownloadResult.failure('Unable to download the audio stream.')
            : DownloadResult.success(filePath);
      }

      return DownloadResult.failure('Downloads are only supported for YouTube tracks.');
    } on YouTubeDownloadException catch (e) {
      return DownloadResult.failure(e.message);
    } catch (e) {
      debugPrint('Error downloading audio: $e');
      return DownloadResult.failure('Unable to download the audio stream.');
    }
  }

  static Future<DownloadResult> downloadVideo(
    Song song,
    AppVideoQuality quality, {
    String? customFileName,
  }) async {
    try {
      if (song.source == SongSource.youtube) {
        final filePath = await YouTubeRemoteSource().downloadVideo(
          song.id,
          quality,
          customFileName: customFileName,
        );
        return filePath == null
            ? DownloadResult.failure('Unable to download the video stream.')
            : DownloadResult.success(filePath);
      }

      return DownloadResult.failure('Downloads are only supported for YouTube tracks.');
    } on YouTubeDownloadException catch (e) {
      return DownloadResult.failure(e.message);
    } catch (e) {
      debugPrint('Error downloading video: $e');
      return DownloadResult.failure('Unable to download the video stream.');
    }
  }

  static Future<List<File>> getDownloadedFiles() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final downloadsDir = Directory('${dir.path}/downloads');

      if (!await downloadsDir.exists()) {
        return [];
      }

      final files = await downloadsDir.list().toList();
      return files.whereType<File>().toList();
    } catch (e) {
      debugPrint('Error getting downloaded files: $e');
      return [];
    }
  }

  static Future<void> deleteDownloadedFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('Error deleting file: $e');
    }
  }
}
