# VibeStream

VibeStream is a Flutter music player focused on three flows:

- browsing audio files on the device
- searching and playing YouTube content
- downloading YouTube audio or video for local playback

The app uses Riverpod for state management, `audio_service` + `just_audio` for background audio, and Hive for lightweight local persistence.

## Current Features

- local library scan on supported Android devices
- YouTube search with embedded playback
- background audio playback through the app audio handler
- favorites and recently played history stored with Hive
- downloaded media browser for audio and video files
- mini player and full-screen player UI

## Tech Stack

- Flutter
- Riverpod
- `audio_service`
- `just_audio`
- `youtube_explode_dart`
- `youtube_player_flutter`
- Hive

## Project Structure

```text
lib/
  core/
    theme/
  data/
    data_sources/
  domain/
    entities/
  presentation/
    common_widgets/
    features/
    providers/
  services/
    audio/
    download/
    storage/
```

## Getting Started

1. Install Flutter and the Android/iOS toolchains.
2. Fetch dependencies:

```bash
flutter pub get
```

3. Run the app:

```bash
flutter run
```

4. Validate the project:

```bash
flutter analyze
```

## Platform Notes

- Android is the main target for local media scanning.
- iOS/macOS currently request media-library permission, but the local library view intentionally returns an empty list because the query flow is not implemented there yet.
- YouTube features require network access at runtime.
- Downloaded files are stored in the app documents directory under `downloads/`.

## Persistence

Hive boxes are used for:

- favorites
- recent songs
- imported media
- app settings

## Known Limitations

- The current Android manifest still needs the runtime-related media/network declarations required for the local-library and YouTube flows to work reliably on device.
- The Downloads section does not auto-refresh immediately after a new download finishes.
- "Play all" for YouTube results opens the first video rather than providing a true sequential YouTube queue experience.

## Design Notes

The UI is built around a custom neon/glass visual language, with:

- gradient-heavy backgrounds
- glassmorphism containers
- a persistent mini player
- separate local, YouTube, and download playback surfaces
# VibeStream
