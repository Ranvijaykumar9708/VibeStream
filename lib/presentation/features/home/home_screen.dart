import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';


import '../../../domain/entities/song.dart';
import '../../../services/audio/audio_player_service.dart';
import '../../../services/storage/storage_service.dart';
import '../../../services/download/download_service.dart';
import '../../common_widgets/mini_player.dart';
import '../../common_widgets/song_artwork.dart';
import '../../common_widgets/glass_container.dart';
import '../../common_widgets/song_palette_builder.dart';
import '../../providers/music_providers.dart';
import '../player/music_player_screen.dart';
import '../player/youtube_player_screen.dart';
import '../player/local_video_player_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late final TextEditingController _searchController;
  String _searchQuery = 'top hits 2024';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: _searchQuery);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isApplePlatform =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS);
    final library = ref.watch(localLibraryProvider);
    final favorites =
        ref.watch(favoritesProvider).asData?.value ?? const <String>{};
    final recentSongs = ref.watch(recentSongsProvider);
    final youtubeResults = ref.watch(youtubeSearchProvider(_searchQuery));
    final audioState = ref.watch(audioStateProvider);
    final localTrackCount = library.asData?.value.length ?? 0;
    final recentCount = recentSongs.asData?.value.length ?? 0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF0C071C),
              Color(0xFF12093A),
              Color(0xFF070B1F),
              Color(0xFF030D16),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            CustomScrollView(
              slivers: [
                // ── App Bar ──────────────────────────────────────────────
                SliverAppBar(
                  pinned: true,
                  floating: false,
                  expandedHeight: 0,
                  toolbarHeight: 60,
                  backgroundColor: const Color(0xFF0C071C).withValues(alpha: 0.95),
                  surfaceTintColor: Colors.transparent,
                  elevation: 0,
                  title: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF00F0FF), Color(0xFFFF2D78)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: const Icon(
                          Icons.music_note_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'VibeStream',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 22,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    IconButton(
                      tooltip: 'Refresh library',
                      onPressed: () => ref.invalidate(localLibraryProvider),
                      icon: const Icon(
                        Icons.refresh_rounded,
                        color: Colors.white54,
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                ),

                // ── Content ──────────────────────────────────────────────
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // Greeting
                      Text(
                        _greeting(),
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.45),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _HeroPanel(
                        audioState: audioState,
                        localTrackCount: localTrackCount,
                        favoritesCount: favorites.length,
                        recentCount: recentCount,
                      ),
                      const SizedBox(height: 18),
                      // Stats Row
                      _StatsRow(
                        localCount: localTrackCount,
                        recentCount: recentCount,
                        favoritesCount: favorites.length,
                        onPlayAll: () {
                          library.whenData((songs) {
                            if (songs.isNotEmpty) {
                              ref
                                  .read(audioStateProvider.notifier)
                                  .loadPlaylist(songs);
                            }
                          });
                        },
                        onRecentsTap: () {
                          recentSongs.whenData((songs) {
                            if (songs.isEmpty) return;
                            _showSongListSheet(
                              context,
                              title: 'Recently Played',
                              icon: Icons.history_rounded,
                              color: const Color(0xFF00F0FF),
                              songs: songs,
                              favorites: favorites,
                            );
                          });
                        },
                        onFavoritesTap: () async {
                          final favIds = favorites;
                          library.whenData((songs) {
                            final favSongs = songs
                                .where((s) => favIds.contains(s.id))
                                .toList();
                            _showSongListSheet(
                              context,
                              title: 'Favorites',
                              icon: Icons.favorite_rounded,
                              color: const Color(0xFFFF2D78),
                              songs: favSongs.isEmpty
                                  ? []
                                  : favSongs,
                              favorites: favorites,
                            );
                          });
                        },
                      ),
                      const SizedBox(height: 28),

                      // YouTube Search card
                      _SearchSection(
                        controller: _searchController,
                        activeQuery: _searchQuery,
                        onSearch: _submitSearch,
                        onChipTap: (q) {
                          _searchController.text = q;
                          setState(() => _searchQuery = q);
                        },
                      ),
                      const SizedBox(height: 14),
                      _AsyncSongSection(
                        value: youtubeResults,
                        emptyLabel: 'Search for something to get started.',
                        songsBuilder: (songs) => _SongList(
                          songs: songs,
                          favorites: favorites,
                          onPlaySong: _playSong,
                          onPlayAll: () => _playAll(songs),
                          title: '${songs.length} results',
                          onPlaySongInBackground: _playYouTubeInBackground,
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Recently Played
                      _SectionLabel(
                        icon: Icons.history_rounded,
                        title: 'Recently Played',
                        color: const Color(0xFF00F0FF),
                      ),
                      const SizedBox(height: 12),
                      recentSongs.when(
                        data: (songs) => songs.isEmpty
                            ? const _EmptyCard(
                                label: 'Play something to build your history.',
                                icon: Icons.history_rounded,
                              )
                            : SizedBox(
                                height: 180,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: songs.length,
                                  separatorBuilder: (context, index) =>
                                      const SizedBox(width: 12),
                                  itemBuilder: (context, index) {
                                    final song = songs[index];
                                    return _RecentSongCard(
                                      song: song,
                                      isFavorite: favorites.contains(song.id),
                                      onTap: () => _playSong(song),
                                    );
                                  },
                                ),
                              ),
                        loading: () => const _LoadingCard(),
                        error: (error, stackTrace) => const _EmptyCard(
                          label: 'Could not load recents.',
                          icon: Icons.error_outline_rounded,
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Local Library
                      _SectionLabel(
                        icon: Icons.library_music_rounded,
                        title: 'Local Library',
                        color: const Color(0xFFA78BFA),
                      ),
                      const SizedBox(height: 12),
                      if (isApplePlatform)
                        const _EmptyCard(
                          label:
                              'Local scanning is unsupported on this platform.',
                          icon: Icons.phonelink_off_rounded,
                        )
                      else
                        _AsyncSongSection(
                          value: library,
                          emptyLabel:
                              'No local songs found. Grant storage permission.',
                          songsBuilder: (songs) => _SongList(
                            songs: songs,
                            favorites: favorites,
                            onPlaySong: _playSong,
                            onPlayAll: () => _playAll(songs),
                            title: '${songs.length} tracks',
                          ),
                        ),
                      const SizedBox(height: 28),

                      // Downloads
                      _SectionLabel(
                        icon: Icons.download_done_rounded,
                        title: 'Downloads',
                        color: const Color(0xFF34D399),
                      ),
                      const SizedBox(height: 12),
                      const _DownloadsSection(),
                    ]),
                  ),
                ),
              ],
            ),
            const Align(alignment: Alignment.bottomCenter, child: MiniPlayer()),
          ],
        ),
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning ☀️';
    if (hour < 17) return 'Good afternoon 🎧';
    return 'Good evening 🌙';
  }

  void _submitSearch() {
    final q = _searchController.text.trim();
    if (q.isEmpty) return;
    setState(() => _searchQuery = q);
  }

  Future<void> _playSong(Song song) async {
    if (song.source == SongSource.youtube) {
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => YouTubePlayerScreen(song: song)),
      );
      return;
    }
    ref.read(audioStateProvider.notifier).playSong(song);
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MusicPlayerScreen()),
    );
  }

  void _playAll(List<Song> songs) {
    if (songs.isEmpty) return;
    if (songs.first.source == SongSource.youtube) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => YouTubePlayerScreen(song: songs.first)),
      );
      return;
    }
    ref.read(audioStateProvider.notifier).loadPlaylist(songs);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MusicPlayerScreen()),
    );
  }

  void _showSongListSheet(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required List<Song> songs,
    required Set<String> favorites,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        expand: false,
        builder: (_, scrollController) => Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0A0818),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(26),
            ),
            border: Border.all(
              color: color.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            children: [
              // Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: color, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${songs.length} tracks',
                        style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(
                color: color.withValues(alpha: 0.15),
                height: 1,
              ),
              // Songs
              Expanded(
                child: songs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(icon,
                                color: Colors.white24, size: 48),
                            const SizedBox(height: 12),
                            Text(
                              'Nothing here yet',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.4),
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: songs.length,
                        itemBuilder: (_, i) {
                          final song = songs[i];
                          final isFav = favorites.contains(song.id);
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            leading: _ThumbnailWithDuration(song: song),
                            title: Text(
                              song.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            subtitle: Text(
                              song.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white
                                    .withValues(alpha: 0.5),
                                fontSize: 12,
                              ),
                            ),
                            trailing: Icon(
                              isFav
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              color: isFav
                                  ? const Color(0xFFFF2D78)
                                  : Colors.white24,
                              size: 20,
                            ),
                            onTap: () {
                              Navigator.pop(context);
                              _playSong(song);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Resolves the YouTube audio stream URL and plays it through audio_service
  /// (background-capable, no InAppWebView). Falls back to YouTubePlayerScreen
  /// if resolution fails.
  Future<void> _playYouTubeInBackground(Song song) async {
    if (!mounted) return;
    // Show a loading indicator while resolving
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF00F0FF),
              ),
            ),
            SizedBox(width: 12),
            Text('Loading audio stream…'),
          ],
        ),
        duration: Duration(seconds: 6),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Color(0xFF1E1B3A),
      ),
    );
    try {
      final resolved = await ref
          .read(audioHandlerProvider)
          .resolveYouTubeAudioUrl(song.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      if (resolved != null) {
        final bgSong = song.copyWith(audioUrl: resolved);
        ref.read(audioStateProvider.notifier).playSong(bgSong);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Playing "${song.title}" in background'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF00F0FF).withValues(alpha: 0.85),
          ),
        );
      } else {
        throw Exception('URL resolution returned null');
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      // Fallback: open the YouTube player
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => YouTubePlayerScreen(song: song)),
      );
    }
  }
}

// ─────────────────────── Stats Row ───────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.localCount,
    required this.recentCount,
    required this.favoritesCount,
    required this.onPlayAll,
    this.onRecentsTap,
    this.onFavoritesTap,
  });

  final int localCount;
  final int recentCount;
  final int favoritesCount;
  final VoidCallback onPlayAll;
  final VoidCallback? onRecentsTap;
  final VoidCallback? onFavoritesTap;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _StatCard(
              icon: Icons.library_music_rounded,
              label: 'Local',
              value: localCount,
              color: const Color(0xFFA78BFA),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatCard(
              icon: Icons.history_rounded,
              label: 'Recents',
              value: recentCount,
              color: const Color(0xFF00F0FF),
              onTap: onRecentsTap,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatCard(
              icon: Icons.favorite_rounded,
              label: 'Favorites',
              value: favoritesCount,
              color: const Color(0xFFFF2D78),
              onTap: onFavoritesTap,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: onPlayAll,
              child: GlassContainer(
                blur: 20,
                color: const Color(0xFF00F0FF).withValues(alpha: 0.12),
                border: Border.all(
                  color: const Color(0xFF00F0FF).withValues(alpha: 0.35),
                ),
                borderRadius: BorderRadius.circular(18),
                padding: const EdgeInsets.all(8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.play_circle_filled_rounded,
                      color: Color(0xFF00F0FF),
                      size: 24,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Play All',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({
    required this.audioState,
    required this.localTrackCount,
    required this.favoritesCount,
    required this.recentCount,
  });

  final AudioState audioState;
  final int localTrackCount;
  final int favoritesCount;
  final int recentCount;

  @override
  Widget build(BuildContext context) {
    final currentSong = audioState.currentSong;

    if (currentSong == null) {
      return GlassContainer(
        blur: 24,
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        borderRadius: BorderRadius.circular(28),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00F0FF), Color(0xFFFF2D78)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Start a session',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Search YouTube, explore local tracks, or reopen a recent favorite. Your next play is only one tap away.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.68),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _HeroMetric(label: 'Local', value: '$localTrackCount'),
                _HeroMetric(label: 'Favorites', value: '$favoritesCount'),
                _HeroMetric(label: 'Recents', value: '$recentCount'),
              ],
            ),
          ],
        ),
      );
    }

    return SongPaletteBuilder(
      song: currentSong,
      builder: (context, palette) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: LinearGradient(
            colors: [
              palette.primary.withValues(alpha: 0.42),
              const Color(0xFF121027),
              palette.secondary.withValues(alpha: 0.18),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: palette.glow,
              blurRadius: 28,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: GlassContainer(
          blur: 22,
          color: Colors.black.withValues(alpha: 0.18),
          border: Border.all(color: palette.primary.withValues(alpha: 0.2)),
          borderRadius: BorderRadius.circular(30),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: palette.primary.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      audioState.isPlaying ? 'NOW PLAYING' : 'READY TO RESUME',
                      style: TextStyle(
                        color: palette.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.7,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    currentSong.isLocal ? 'Local session' : 'Streaming session',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.65),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Hero(
                    tag: 'song-artwork-${currentSong.id}',
                    child: SongArtwork(
                      song: currentSong,
                      size: 88,
                      borderRadius: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentSong.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          currentSong.artist,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.72),
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 14),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: audioState.total.inMilliseconds == 0
                                ? 0
                                : (audioState.position.inMilliseconds /
                                          audioState.total.inMilliseconds)
                                      .clamp(0, 1)
                                      .toDouble(),
                            minHeight: 4,
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.08,
                            ),
                            valueColor: AlwaysStoppedAnimation(
                              palette.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _HeroMetric(label: 'Local', value: '$localTrackCount'),
                  _HeroMetric(label: 'Favorites', value: '$favoritesCount'),
                  _HeroMetric(label: 'Recents', value: '$recentCount'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 92,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.52),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final int value;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final display = value == 0 ? '—' : '$value';
    return GestureDetector(
      onTap: onTap,
      child: GlassContainer(
        blur: 20,
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(18),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(height: 3),
            Text(
              display,
              style: TextStyle(
                color: value == 0 ? color.withValues(alpha: 0.4) : color,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                height: 1.1,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 9,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
            if (onTap != null) ...[  
              const SizedBox(height: 2),
              Icon(
                Icons.arrow_drop_down_rounded,
                color: color.withValues(alpha: 0.5),
                size: 12,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────── Section Label ───────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.icon,
    required this.title,
    required this.color,
  });

  final IconData icon;
  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────── Search Section Card ─────────────────────────────────

class _SearchSection extends StatelessWidget {
  const _SearchSection({
    required this.controller,
    required this.activeQuery,
    required this.onSearch,
    required this.onChipTap,
  });

  final TextEditingController controller;
  final String activeQuery;
  final VoidCallback onSearch;
  final ValueChanged<String> onChipTap;

  static const _chips = [
    ('🎵', 'top hits 2024'),
    ('☁️', 'lofi chill'),
    ('💪', 'workout motivation'),
    ('🎶', 'bollywood hits'),
    ('🎸', 'english pop'),
    ('🌙', 'night drive'),
    ('🎹', 'piano instrumental'),
    ('🔥', 'trending now'),
  ];

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      blur: 20,
      color: Colors.white.withValues(alpha: 0.05),
      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      borderRadius: BorderRadius.circular(22),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF2D78), Color(0xFFFF6B35)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.youtube_searched_for_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'YouTube Search',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
              const Spacer(),
              Text(
                'Tap a genre below',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.35),
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Search input row
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFFFF2D78).withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                const SizedBox(width: 14),
                Icon(
                  Icons.search_rounded,
                  color: const Color(0xFFFF2D78).withValues(alpha: 0.7),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: controller,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => onSearch(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Artist, song, or playlist…',
                      hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.3),
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: onSearch,
                  child: Container(
                    margin: const EdgeInsets.all(6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF2D78), Color(0xFFFF6B35)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF2D78).withValues(alpha: 0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Text(
                      'Search',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Genre chips (wrapping 2 rows)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _chips.map((chip) {
              final isActive = activeQuery == chip.$2;
              return GestureDetector(
                onTap: () => onChipTap(chip.$2),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: isActive
                        ? const Color(0xFFFF2D78).withValues(alpha: 0.25)
                        : Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isActive
                          ? const Color(0xFFFF2D78).withValues(alpha: 0.6)
                          : Colors.white.withValues(alpha: 0.08),
                      width: isActive ? 1.2 : 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(chip.$1, style: const TextStyle(fontSize: 12)),
                      const SizedBox(width: 5),
                      Text(
                        chip.$2,
                        style: TextStyle(
                          color: isActive
                              ? const Color(0xFFFF2D78)
                              : Colors.white.withValues(alpha: 0.65),
                          fontSize: 12,
                          fontWeight: isActive
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────── Async Song Section ───────────────────────────────────

class _AsyncSongSection extends StatelessWidget {
  const _AsyncSongSection({
    required this.value,
    required this.emptyLabel,
    required this.songsBuilder,
  });

  final AsyncValue<List<Song>> value;
  final String emptyLabel;
  final Widget Function(List<Song> songs) songsBuilder;

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: (songs) =>
          songs.isEmpty ? _EmptyCard(label: emptyLabel) : songsBuilder(songs),
      loading: () => const _LoadingCard(),
      error: (error, stackTrace) => const _EmptyCard(
        label: 'Something went wrong.',
        icon: Icons.error_outline_rounded,
      ),
    );
  }
}

// ─────────────────────── Song List ───────────────────────────────────────────

class _SongList extends ConsumerWidget {
  const _SongList({
    required this.songs,
    required this.favorites,
    required this.onPlaySong,
    required this.onPlayAll,
    required this.title,
    this.onPlaySongInBackground,
  });

  final List<Song> songs;
  final Set<String> favorites;
  final Future<void> Function(Song song) onPlaySong;
  final VoidCallback onPlayAll;
  final String title;
  final Future<void> Function(Song song)? onPlaySongInBackground;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GlassContainer(
      blur: 18,
      color: Colors.white.withValues(alpha: 0.04),
      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      borderRadius: BorderRadius.circular(20),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      child: Column(
        children: [
          // ── Header row ─────────────────────────────────
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              // Shuffle
              _IconAction(
                icon: Icons.shuffle_rounded,
                color: const Color(0xFFA78BFA),
                tooltip: 'Shuffle',
                onTap: () {
                  final shuffled = List<Song>.from(songs)..shuffle();
                  ref
                      .read(audioStateProvider.notifier)
                      .loadPlaylist(shuffled);
                  if (shuffled.first.source == SongSource.youtube) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            YouTubePlayerScreen(song: shuffled.first),
                      ),
                    );
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MusicPlayerScreen(),
                      ),
                    );
                  }
                },
              ),
              const SizedBox(width: 4),
              // Play all
              _IconAction(
                icon: Icons.play_arrow_rounded,
                color: const Color(0xFF00F0FF),
                tooltip: 'Play all',
                onTap: onPlayAll,
              ),
            ],
          ),
          const Divider(color: Colors.white12, height: 12),
          for (final song in songs)
            _SongTile(
              song: song,
              isFavorite: favorites.contains(song.id),
              onTap: () => onPlaySong(song),
              onFavoriteTap: () => StorageService.toggleFavorite(song.id),
              onPlayInBackground: onPlaySongInBackground != null
                  ? () => onPlaySongInBackground!(song)
                  : null,
              onAddToQueue: () {
                ref.read(audioStateProvider.notifier).addToQueue(song);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content:
                        Text('"${song.title}" added to queue'),
                    duration: const Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: const Color(0xFF1E1B3A),
                  ),
                );
              },
              onDownloadAudio: song.source == SongSource.youtube
                  ? () async {
                      final result =
                          await DownloadService.downloadAudio(song);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              result.isSuccess
                                  ? 'Audio downloaded!'
                                  : result.message ?? 'Failed',
                            ),
                            backgroundColor: result.isSuccess
                                ? const Color(0xFF34D399)
                                    .withValues(alpha: 0.9)
                                : Colors.red.shade700,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    }
                  : null,
              onDownloadVideo: song.source == SongSource.youtube
                  ? () async {
                      final result = await DownloadService.downloadVideo(
                        song,
                        AppVideoQuality.high,
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              result.isSuccess
                                  ? 'Video downloaded!'
                                  : result.message ?? 'Failed',
                            ),
                            backgroundColor: result.isSuccess
                                ? const Color(0xFF34D399)
                                    .withValues(alpha: 0.9)
                                : Colors.red.shade700,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    }
                  : null,
            ),
        ],
      ),
    );
  }
}

// ─────────────────────── Song Tile ───────────────────────────────────────────

class _SongTile extends StatelessWidget {
  const _SongTile({
    required this.song,
    required this.isFavorite,
    required this.onTap,
    required this.onFavoriteTap,
    this.onPlayInBackground,
    this.onAddToQueue,
    this.onDownloadAudio,
    this.onDownloadVideo,
  });

  final Song song;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onFavoriteTap;
  final VoidCallback? onPlayInBackground;
  final VoidCallback? onAddToQueue;
  final VoidCallback? onDownloadAudio;
  final VoidCallback? onDownloadVideo;

  @override
  Widget build(BuildContext context) {
    final isYouTube = song.source == SongSource.youtube;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      leading: _ThumbnailWithDuration(song: song),
      title: Text(
        song.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
      subtitle: Row(
        children: [
          if (isYouTube)
            Container(
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: const Color(0xFFFF2D78).withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: const Color(0xFFFF2D78).withValues(alpha: 0.4),
                  width: 0.5,
                ),
              ),
              child: const Text(
                'YT',
                style: TextStyle(
                  color: Color(0xFFFF2D78),
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          Expanded(
            child: Text(
              song.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: onFavoriteTap,
            child: Icon(
              isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: isFavorite ? const Color(0xFFFF2D78) : Colors.white24,
              size: 20,
            ),
          ),
          const SizedBox(width: 2),
          GestureDetector(
            onTap: () => _showOptions(context),
            child: Icon(
              Icons.more_vert_rounded,
              color: Colors.white.withValues(alpha: 0.4),
              size: 20,
            ),
          ),
        ],
      ),
      onTap: onTap,
    );
  }

  void _showOptions(BuildContext context) {
    final isYouTube = song.source == SongSource.youtube;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0F0C24),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Song info header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SongArtwork(song: song, size: 48, borderRadius: 0),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          song.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white12, height: 1),
            // Actions
            if (isYouTube && onPlayInBackground != null)
              _OptionTile(
                icon: Icons.headphones_rounded,
                color: const Color(0xFF00F0FF),
                label: 'Play audio in background',
                subtitle: 'Stream audio, screen stays off',
                onTap: () {
                  Navigator.pop(context);
                  onPlayInBackground!();
                },
              ),
            if (onAddToQueue != null)
              _OptionTile(
                icon: Icons.playlist_add_rounded,
                color: const Color(0xFFA78BFA),
                label: 'Add to queue',
                onTap: () {
                  Navigator.pop(context);
                  onAddToQueue!();
                },
              ),
            if (onDownloadAudio != null)
              _OptionTile(
                icon: Icons.audio_file_rounded,
                color: const Color(0xFF34D399),
                label: 'Download audio',
                onTap: () {
                  Navigator.pop(context);
                  onDownloadAudio!();
                },
              ),
            if (onDownloadVideo != null)
              _OptionTile(
                icon: Icons.video_file_rounded,
                color: const Color(0xFFFF2D78),
                label: 'Download video',
                onTap: () {
                  Navigator.pop(context);
                  onDownloadVideo!();
                },
              ),
            _OptionTile(
              icon: isFavorite ? Icons.heart_broken_rounded : Icons.favorite_rounded,
              color: const Color(0xFFFF2D78),
              label: isFavorite ? 'Remove from favorites' : 'Add to favorites',
              onTap: () {
                Navigator.pop(context);
                onFavoriteTap();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

}

// ─────────────────────── Thumbnail with Duration Badge ───────────────────────

class _ThumbnailWithDuration extends StatelessWidget {
  const _ThumbnailWithDuration({required this.song});
  final Song song;

  @override
  Widget build(BuildContext context) {
    final dur = song.duration;
    final hasTime = dur.inSeconds > 0;
    final label = hasTime
        ? '${dur.inMinutes}:${(dur.inSeconds.remainder(60)).toString().padLeft(2, '0')}'
        : null;
    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        SongArtwork(song: song),
        if (label != null)
          Positioned(
            bottom: 2,
            right: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────── Icon Action (───────────────────────────────────────────

class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
      ),
    );
  }
}

// ─────────────────────── Option Tile ───────────────────────────────────────────

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
      title: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 11,
              ),
            )
          : null,
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}

// ─────────────────────── Recent Song Card ────────────────────────────────────

class _RecentSongCard extends StatelessWidget {
  const _RecentSongCard({
    required this.song,
    required this.isFavorite,
    required this.onTap,
  });

  final Song song;
  final bool isFavorite;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: GlassContainer(
        width: 130,
        blur: 18,
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        borderRadius: BorderRadius.circular(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
              ),
              child: SongArtwork(song: song, size: 100, borderRadius: 0),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      song.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────── Utility Cards ───────────────────────────────────────

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.label, this.icon = Icons.inbox_rounded});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      blur: 14,
      color: Colors.white.withValues(alpha: 0.04),
      border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      borderRadius: BorderRadius.circular(18),
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      child: Column(
        children: [
          Icon(icon, color: Colors.white24, size: 32),
          const SizedBox(height: 10),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Color(0xFF00F0FF),
        ),
      ),
    );
  }
}

// ─────────────────────── Downloads Section ───────────────────────────────────

class _DownloadsSection extends StatefulWidget {
  const _DownloadsSection();

  @override
  State<_DownloadsSection> createState() => _DownloadsSectionState();
}

class _DownloadsSectionState extends State<_DownloadsSection> {
  List<File> _files = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    final files = await DownloadService.getDownloadedFiles();
    if (mounted) {
      setState(() {
        _files = files;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const _LoadingCard();
    if (_files.isEmpty) {
      return const _EmptyCard(
        label: 'No downloads yet. Download tracks from YouTube.',
        icon: Icons.download_rounded,
      );
    }

    return GlassContainer(
      blur: 18,
      color: Colors.white.withValues(alpha: 0.04),
      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      borderRadius: BorderRadius.circular(20),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text(
              '${_files.length} file${_files.length == 1 ? '' : 's'}',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(
            height: 110,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _files.length,
              separatorBuilder: (context, index) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final file = _files[index];
                final name = file.path.split('/').last;
                final lower = name.toLowerCase();
                final isAudio = lower.endsWith('.mp3') ||
                    lower.endsWith('.m4a') ||
                    lower.endsWith('.aac') ||
                    lower.endsWith('.flac') ||
                    lower.endsWith('.wav') ||
                    lower.endsWith('.opus');
                final isVideo = lower.endsWith('.mp4') ||
                    lower.endsWith('.mov') ||
                    lower.endsWith('.mkv') ||
                    lower.endsWith('.webm');

                return GestureDetector(
                  onTap: () {
                    if (isAudio) {
                      final song = Song(
                        id: 'local_$name',
                        title: name.replaceAll(RegExp(r'\.\w+$'), ''),
                        artist: 'Downloaded',
                        album: 'Downloads',
                        albumArtUrl: '',
                        audioUrl: file.path,
                        duration: Duration.zero,
                        source: SongSource.local,
                      );
                      context
                          .findAncestorStateOfType<_HomeScreenState>()
                          ?._playSong(song);
                    } else if (isVideo) {
                      final song = Song(
                        id: 'local_$name',
                        title: name.replaceAll(RegExp(r'\.\w+$'), ''),
                        artist: 'Downloaded',
                        album: 'Downloads',
                        albumArtUrl: '',
                        audioUrl: file.path,
                        videoUrl: file.path,
                        duration: Duration.zero,
                        source: SongSource.local,
                      );
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => LocalVideoPlayerScreen(song: song),
                        ),
                      );
                    }
                  },
                  child: GlassContainer(
                    width: 90,
                    blur: 12,
                    color: isAudio
                        ? const Color(0xFF34D399).withValues(alpha: 0.08)
                        : const Color(0xFFFF2D78).withValues(alpha: 0.08),
                    border: Border.all(
                      color: isAudio
                          ? const Color(0xFF34D399).withValues(alpha: 0.2)
                          : const Color(0xFFFF2D78).withValues(alpha: 0.2),
                    ),
                    borderRadius: BorderRadius.circular(14),
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isAudio
                              ? Icons.audio_file_rounded
                              : Icons.video_file_rounded,
                          color: isAudio
                              ? const Color(0xFF34D399)
                              : const Color(0xFFFF2D78),
                          size: 28,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                          ),
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
