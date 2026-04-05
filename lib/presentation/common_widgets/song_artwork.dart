import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';

import '../../domain/entities/song.dart';

class SongArtwork extends StatelessWidget {
  const SongArtwork({
    super.key,
    required this.song,
    this.size = 56,
    this.borderRadius = 16,
  });

  final Song song;
  final double size;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final artworkId = int.tryParse(song.albumArtUrl);

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Container(
        width: size,
        height: size,
        color: Colors.white.withValues(alpha: 0.08),
        child: song.hasNetworkArtwork
            ? Image.network(
                song.albumArtUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    _ArtworkFallback(
                      iconSize: size * 0.45,
                      isVideo: song.isVideo,
                    ),
              )
            : artworkId != null && song.isLocal
            ? QueryArtworkWidget(
                id: artworkId,
                type: ArtworkType.AUDIO,
                artworkFit: BoxFit.cover,
                nullArtworkWidget: _ArtworkFallback(
                  iconSize: size * 0.45,
                  isVideo: song.isVideo,
                ),
              )
            : _ArtworkFallback(
                iconSize: size * 0.45,
                isVideo: song.isVideo,
              ),
      ),
    );
  }
}

class _ArtworkFallback extends StatelessWidget {
  const _ArtworkFallback({required this.iconSize, this.isVideo = false});

  final double iconSize;
  final bool isVideo;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF00C2A8), Color(0xFFFFB703)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          isVideo ? Icons.video_library_rounded : Icons.graphic_eq_rounded,
          color: Colors.black87,
          size: iconSize,
        ),
      ),
    );
  }
}
