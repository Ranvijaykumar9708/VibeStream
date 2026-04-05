enum SongSource { local, youtube, generated }

enum AppVideoQuality { low, medium, high, hd, fullHd }

class Song {
  final String id;
  final String title;
  final String artist;
  final String album;
  final String albumArtUrl;
  final String audioUrl;
  final Duration duration;
  final SongSource source;
  final AppVideoQuality? videoQuality;
  final String? videoUrl;

  Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.albumArtUrl,
    required this.audioUrl,
    required this.duration,
    this.source = SongSource.local,
    this.videoQuality,
    this.videoUrl,
  });

  factory Song.dummy() {
    return Song(
      id: "1",
      title: "Neon Lights (Dummy)",
      artist: "Synthwave Master",
      album: "Retro Nights",
      albumArtUrl:
          "https://images.unsplash.com/photo-1614613535308-eb5fbd3d2c17?auto=format&fit=crop&q=80&w=400",
      audioUrl: "https://server8.mp3quran.net/s_gmd/001.mp3", // Demo audio
      duration: const Duration(minutes: 3, seconds: 24),
      source: SongSource.youtube,
      videoQuality: AppVideoQuality.medium,
      videoUrl: null,
    );
  }

  Song copyWith({
    String? id,
    String? title,
    String? artist,
    String? album,
    String? albumArtUrl,
    String? audioUrl,
    Duration? duration,
    SongSource? source,
    AppVideoQuality? videoQuality,
    String? videoUrl,
  }) {
    return Song(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      albumArtUrl: albumArtUrl ?? this.albumArtUrl,
      audioUrl: audioUrl ?? this.audioUrl,
      duration: duration ?? this.duration,
      source: source ?? this.source,
      videoQuality: videoQuality ?? this.videoQuality,
      videoUrl: videoUrl ?? this.videoUrl,
    );
  }

  bool get hasNetworkArtwork => albumArtUrl.startsWith('http');
  bool get isLocal => source == SongSource.local;
  bool get isVideo {
    final path = (videoUrl?.isNotEmpty ?? false) ? videoUrl! : audioUrl;
    final lower = path.toLowerCase();
    return lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.m4v') ||
        lower.endsWith('.avi') ||
        lower.endsWith('.mkv') ||
        lower.endsWith('.webm');
  }

  bool get isAudioOnly => !isVideo;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'album': album,
      'albumArtUrl': albumArtUrl,
      'audioUrl': audioUrl,
      'durationMs': duration.inMilliseconds,
      'source': source.name,
      'videoQuality': videoQuality?.name,
      'videoUrl': videoUrl,
    };
  }

  factory Song.fromJson(Map<String, dynamic> json) {
    return Song(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Unknown Title',
      artist: json['artist'] as String? ?? 'Unknown Artist',
      album: json['album'] as String? ?? 'Unknown Album',
      albumArtUrl: json['albumArtUrl'] as String? ?? '',
      audioUrl: json['audioUrl'] as String? ?? '',
      duration: Duration(milliseconds: json['durationMs'] as int? ?? 0),
      source: SongSource.values.byName(
        json['source'] as String? ?? SongSource.local.name,
      ),
      videoQuality: json['videoQuality'] != null
          ? AppVideoQuality.values.byName(json['videoQuality'] as String)
          : null,
      videoUrl: json['videoUrl'] as String?,
    );
  }
}
