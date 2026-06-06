# Streamvault watchOS — Claude Instructions

## Project
Native Apple Watch client for Streamvault — offline music sync and playback.
Swift 5.10 · SwiftUI · AVFoundation · URLSession · Keychain

Primary differentiator: sync albums over Wi-Fi while paired, play offline without any
network connection. Now Playing info + Digital Crown seek wired automatically.

For platform-wide scope and API contracts, see the root CLAUDE.md.

## Stack constraints
- UI: SwiftUI only. No UIKit, no WatchKit `InterfaceController` subclasses.
- Navigation: `NavigationStack` + `.navigationDestination(for:)` value-based routing.
  Never `NavigationView` (deprecated watchOS 9+).
- State: `@Observable` (Swift 5.9 / watchOS 10+) for new VMs. Use `ObservableObject` +
  `@Published` only when targeting watchOS 9 (which needs the older pattern). Target is
  watchOS 9+ — use `ObservableObject` for now; migrate to `@Observable` when min bumps to 10.
- Async: Swift concurrency (`async`/`await`, `Task`, `AsyncStream`). No Combine, no callbacks.
- Networking: `URLSession` + `Codable`. No third-party networking library.
- Auth storage: Keychain via `SecItem*` APIs. Never `UserDefaults` for tokens.
- Settings (server URL): `UserDefaults`. Not sensitive.
- Local track storage: `FileManager` + `Documents/tracks/{trackId}` — app-private, no
  media library integration.
- Track metadata persistence: `Codable` structs encoded as JSON to
  `Documents/syncedTracks.json`. No Core Data, no SwiftData (targets watchOS 9).
- Playback: `AVPlayer` in `PlaybackManager` (plain class, `@MainActor`). Never play audio
  from a ViewModel directly.
- Now Playing: `MPNowPlayingInfoCenter` + `MPRemoteCommandCenter` — wired once in
  `PlaybackManager.init()`.
- DI: manual, via `AppDependencies` (an `ObservableObject` created in `StreamvaultWatchApp`
  and passed via `.environmentObject`). No Swinject, no Needle.
- Project generation: `xcodegen` from `project.yml`. Never edit `project.pbxproj` by hand.

## Architecture
```
App/            ← @main entry point + AppDependencies wiring
Navigation/     ← RootView (auth gate + NavigationStack)
Auth/           ← AuthView, AuthViewModel, TokenRepository
Library/        ← ArtistListView, AlbumListView, TrackListView, LibraryViewModel
Sync/           ← SyncView, SyncViewModel, SyncManager
Player/         ← PlayerView, PlayerViewModel, PlaybackManager
Data/
  API/          ← APIClient (URLSession), response models (Codable)
  Storage/      ← TrackStore (Codable + FileManager)
UI/             ← LoadingView, ErrorView, shared modifiers
```

No business logic in Views. ViewModels call managers/repositories; managers own side effects.

## Package
`io.streamvault.watch`

## Key flows
1. **Auth**: `TokenRepository` reads/writes `accessToken`, `refreshToken` from Keychain;
   `serverUrl` from UserDefaults. `AuthViewModel` calls `APIClient.login()` and writes
   results to `TokenRepository`. `RootView` shows `AuthView` when `tokenRepo.isAuthenticated == false`.
2. **Library browse**: `LibraryViewModel` calls `APIClient.listArtists/listAlbums/listTracks`.
   No local cache for browse — always live. Offline browse not supported (sync is for playback only).
3. **Sync**: `SyncManager.syncAlbum(_:tracks:)` iterates tracks, calls
   `APIClient.downloadUrl(for:)`, runs `URLSession.download(from:)`, moves temp file to
   `Documents/tracks/{trackId}`, appends to `syncedTracks.json`.
4. **Playback**: `PlaybackManager` holds `AVPlayer`, queue, and time observer. `PlayerViewModel`
   mirrors published state. `PlaybackManager.playQueue(tracks:startingAt:)` is the only entry
   point for starting playback.

## Build
```bash
brew install xcodegen
cd watchos
xcodegen generate          # creates StreamvaultWatch.xcodeproj
open StreamvaultWatch.xcodeproj
```
Xcode 16+ required. watchOS Simulator available for UI work; audio playback requires a
physical Apple Watch.

## Do NOT
- Store tokens in `UserDefaults`
- Access `FileManager` or `Keychain` from a `@MainActor`-isolated ViewModel — use
  `Task.detached` or a background actor if reads become slow
- Play audio directly from a View or ViewModel
- Use `UIApplication`, `UIViewController`, or any UIKit type — not available on watchOS
- Use third-party networking or DI libraries without confirming first
- Target watchOS < 9 — there is no business case for Series 4 or earlier
