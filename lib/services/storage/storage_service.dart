import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../../domain/entities/song.dart';

class StorageService {
  static const String _favoritesBox = 'favorites';
  static const String _recentSongsBox = 'recent_songs';
  static const String _importedMediaBox = 'imported_media';
  static const String _settingsBox = 'settings';

  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox<String>(_favoritesBox); // Just storing song IDs for now
    await Hive.openBox<String>(_recentSongsBox);
    await Hive.openBox<String>(_importedMediaBox);
    await Hive.openBox<String>(_settingsBox);
  }

  static Future<void> toggleFavorite(String songId) async {
    final box = Hive.box<String>(_favoritesBox);
    if (box.containsKey(songId)) {
      await box.delete(songId);
    } else {
      await box.put(songId, songId);
    }
  }

  static bool isFavorite(String songId) {
    if (!Hive.isBoxOpen(_favoritesBox)) return false;
    final box = Hive.box<String>(_favoritesBox);
    return box.containsKey(songId);
  }

  static Box<String> get favoritesBox => Hive.box<String>(_favoritesBox);

  static Set<String> getFavoriteIds() {
    if (!Hive.isBoxOpen(_favoritesBox)) return <String>{};
    return Hive.box<String>(
      _favoritesBox,
    ).keys.map((key) => key.toString()).toSet();
  }

  static Future<void> addRecentSong(Song song) async {
    if (!Hive.isBoxOpen(_recentSongsBox)) return;
    final box = Hive.box<String>(_recentSongsBox);
    await box.delete(song.id);
    await box.put(song.id, jsonEncode(song.toJson()));

    while (box.length > 12) {
      await box.delete(box.keyAt(0));
    }
  }

  static List<Song> getRecentSongs() {
    if (!Hive.isBoxOpen(_recentSongsBox)) return const <Song>[];

    return Hive.box<String>(_recentSongsBox).values
        .map((raw) => Song.fromJson(jsonDecode(raw) as Map<String, dynamic>))
        .toList()
        .reversed
        .toList();
  }

  static Box<String> get recentSongsBox => Hive.box<String>(_recentSongsBox);

  static Box<String> get settingsBox => Hive.box<String>(_settingsBox);

  static Box<String> get importedMediaBox => Hive.box<String>(_importedMediaBox);

  static Future<void> saveImportedSongs(List<Song> songs) async {
    final box = importedMediaBox;
    await box.clear();
    for (final song in songs) {
      await box.put(song.id, jsonEncode(song.toJson()));
    }
  }

  static Future<void> addImportedSongs(List<Song> songs) async {
    if (songs.isEmpty) return;
    final existing = getImportedSongs();
    final merged = <String, Song>{
      for (final song in existing) song.id: song,
      for (final song in songs) song.id: song,
    };
    await saveImportedSongs(merged.values.toList());
  }

  static List<Song> getImportedSongs() {
    if (!Hive.isBoxOpen(_importedMediaBox)) return const <Song>[];

    return Hive.box<String>(_importedMediaBox).values
        .map((raw) => Song.fromJson(jsonDecode(raw) as Map<String, dynamic>))
        .toList();
  }

  static Future<void> removeImportedSong(String songId) async {
    if (!Hive.isBoxOpen(_importedMediaBox)) return;
    await Hive.box<String>(_importedMediaBox).delete(songId);
  }

}
