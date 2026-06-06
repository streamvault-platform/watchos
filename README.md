# streamvault-watchos

Native Apple Watch client for Streamvault.

Swift · SwiftUI · AVFoundation · URLSession

## Requirements
- Xcode 16+
- watchOS 9+ deployment target
- [xcodegen](https://github.com/yonas-forks/xcodeGenSwift) to generate the Xcode project

## Getting started

```bash
brew install xcodegen
xcodegen generate
open StreamvaultWatch.xcodeproj
```

## Architecture

```
StreamvaultWatch/
  App/          ← entry point + dependency wiring
  Navigation/   ← root navigation view
  Auth/         ← login screen, JWT keychain storage
  Library/      ← browse artists → albums → tracks
  Sync/         ← download tracks to watch storage
  Player/       ← offline playback via AVPlayer + Now Playing
  Data/
    API/        ← URLSession-based API client + response models
    Storage/    ← persisted synced-track metadata (Codable + FileManager)
  UI/           ← shared components
```

## Key flows

1. **Auth** — enter server URL + credentials → JWT stored in Keychain
2. **Browse** — fetch artists/albums/tracks from core API over Wi-Fi
3. **Sync** — download selected album's tracks to `Documents/tracks/` on the watch
4. **Play** — AVPlayer reads local files; Now Playing info + Digital Crown seek wired automatically
