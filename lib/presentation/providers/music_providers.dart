import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/data_sources/local_music_source.dart';
import '../../data/data_sources/youtube_remote_source.dart';
import '../../domain/entities/song.dart';
import '../../services/storage/storage_service.dart';

final localMusicSourceProvider = Provider<LocalMusicSource>((ref) {
  return LocalMusicSource();
});

final youtubeRemoteSourceProvider = Provider<YouTubeRemoteSource>((ref) {
  return YouTubeRemoteSource();
});

final localLibraryProvider = FutureProvider<List<Song>>((ref) async {
  return ref.watch(localMusicSourceProvider).fetchLocalSongs();
});

final youtubeSearchProvider = FutureProvider.family<List<Song>, String>((
  ref,
  query,
) async {
  if (query.trim().isEmpty) {
    return const <Song>[];
  }

  return ref.watch(youtubeRemoteSourceProvider).searchSongs(query.trim());
});

final favoritesProvider = StreamProvider<Set<String>>((ref) async* {
  yield StorageService.getFavoriteIds();
  yield* StorageService.favoritesBox.watch().map(
    (_) => StorageService.getFavoriteIds(),
  );
});

final recentSongsProvider = StreamProvider<List<Song>>((ref) async* {
  yield StorageService.getRecentSongs();
  yield* StorageService.recentSongsBox.watch().map(
    (_) => StorageService.getRecentSongs(),
  );
});

final importedMediaProvider = StreamProvider<List<Song>>((ref) async* {
  yield StorageService.getImportedSongs();
  yield* StorageService.importedMediaBox.watch().map(
    (_) => StorageService.getImportedSongs(),
  );
});


