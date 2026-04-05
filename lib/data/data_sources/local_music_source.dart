import 'dart:io';

import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../domain/entities/song.dart';

class LocalMusicSource {
  final OnAudioQuery _audioQuery = OnAudioQuery();

  Future<bool> checkAndRequestPermissions() async {
    if (Platform.isIOS || Platform.isMacOS) {
      final status = await Permission.mediaLibrary.request();
      return status.isGranted || status.isLimited;
    }

    // on_audio_query handles basic permissions but let's be robust
    final hasPerm = await _audioQuery.checkAndRequest(retryRequest: true);
    if (!hasPerm) {
      if (await Permission.audio.request().isGranted ||
          await Permission.storage.request().isGranted) {
        return true;
      }
    }
    return hasPerm;
  }

  Future<List<Song>> fetchLocalSongs() async {
    final hasPermission = await checkAndRequestPermissions();
    if (!hasPermission) return [];

    if (Platform.isIOS || Platform.isMacOS) {
      // The Android-oriented querySongs flow is not reliable on Apple platforms.
      // Return an empty library gracefully instead of risking a native crash.
      return const [];
    }

    List<SongModel> songs = await _audioQuery.querySongs(
      sortType: null,
      orderType: OrderType.ASC_OR_SMALLER,
      uriType: UriType.EXTERNAL,
      ignoreCase: true,
    );

    // Convert SongModel to Domain Entity Song
    return songs
        .where((s) => s.isMusic == true)
        .map(
          (s) => Song(
            id: "local_${s.id}",
            title: s.title,
            artist: s.artist ?? "Unknown Artist",
            album: s.album ?? "Unknown Album",
            albumArtUrl: s.id
                .toString(), // We parse this later for on_audio_query artwork widget
            audioUrl: s.data,
            duration: Duration(milliseconds: s.duration ?? 0),
            source: SongSource.local,
          ),
        )
        .toList();
  }
}
