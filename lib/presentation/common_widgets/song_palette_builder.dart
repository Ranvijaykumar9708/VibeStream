import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';

import '../../domain/entities/song.dart';

class SongPalette {
  const SongPalette({
    required this.primary,
    required this.secondary,
    required this.glow,
  });

  final Color primary;
  final Color secondary;
  final Color glow;
}

class SongPaletteBuilder extends StatelessWidget {
  const SongPaletteBuilder({
    super.key,
    required this.song,
    required this.builder,
  });

  final Song song;
  final Widget Function(BuildContext context, SongPalette palette) builder;

  static final Map<String, Future<SongPalette>> _paletteCache =
      <String, Future<SongPalette>>{};

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SongPalette>(
      future: _paletteCache.putIfAbsent(song.id, () => _resolvePalette(song)),
      builder: (context, snapshot) {
        final palette = snapshot.data ?? _fallbackPalette(song);
        return builder(context, palette);
      },
    );
  }

  static Future<SongPalette> _resolvePalette(Song song) async {
    if (!song.hasNetworkArtwork) {
      return _fallbackPalette(song);
    }

    try {
      final palette = await PaletteGenerator.fromImageProvider(
        NetworkImage(song.albumArtUrl),
        size: const Size(180, 180),
        maximumColorCount: 12,
      );

      final dominant = palette.dominantColor?.color;
      final vibrant = palette.vibrantColor?.color;
      final muted = palette.mutedColor?.color;

      return SongPalette(
        primary: _brighten(dominant ?? vibrant ?? _fallbackPalette(song).primary),
        secondary: _brighten(vibrant ?? muted ?? _fallbackPalette(song).secondary),
        glow: (dominant ?? vibrant ?? _fallbackPalette(song).primary)
            .withValues(alpha: 0.38),
      );
    } catch (_) {
      return _fallbackPalette(song);
    }
  }

  static SongPalette _fallbackPalette(Song song) {
    switch (song.source) {
      case SongSource.youtube:
        return const SongPalette(
          primary: Color(0xFFFF6B6B),
          secondary: Color(0xFFFFB347),
          glow: Color(0x66FF6B6B),
        );
      case SongSource.generated:
        return const SongPalette(
          primary: Color(0xFF7CFFB2),
          secondary: Color(0xFF00D5FF),
          glow: Color(0x667CFFB2),
        );
      case SongSource.local:
        return const SongPalette(
          primary: Color(0xFF8B7BFF),
          secondary: Color(0xFF00E5FF),
          glow: Color(0x668B7BFF),
        );
    }
  }

  static Color _brighten(Color color) {
    final hsl = HSLColor.fromColor(color);
    final adjusted = hsl.withSaturation((hsl.saturation + 0.12).clamp(0.0, 1.0))
        .withLightness((hsl.lightness + 0.08).clamp(0.0, 0.72));
    return adjusted.toColor();
  }
}
