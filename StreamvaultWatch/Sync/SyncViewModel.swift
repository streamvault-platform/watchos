import Foundation

@MainActor
final class SyncViewModel: ObservableObject {
    @Published private(set) var albumSyncStatus: [String: AlbumSyncStatus] = [:]
    @Published private(set) var syncedTracks: [SyncedTrack] = []

    private let syncManager: SyncManaging
    private let trackStore: TrackStore

    init(syncManager: SyncManaging, trackStore: TrackStore = TrackStore()) {
        self.syncManager = syncManager
        self.trackStore = trackStore
        loadSyncedState()
    }

    var deviceId: String { syncManager.deviceId }

    func requestSync(album: Album, tracks: [Track]) async {
        guard tracks.isEmpty == false else { return }
        albumSyncStatus[album.id] = .syncing(progress: 0)
        do {
            _ = try await syncManager.syncAlbum(
                albumId: album.id,
                albumTitle: album.title,
                tracks: tracks,
                onProgress: { [weak self] progress in
                    self?.albumSyncStatus[album.id] = .syncing(progress: progress)
                }
            )
            albumSyncStatus[album.id] = .synced
            syncedTracks = trackStore.load()
        } catch {
            albumSyncStatus[album.id] = .failed(error.localizedDescription)
        }
    }

    func removeTrack(_ trackId: String) {
        try? trackStore.remove(trackId: trackId)
        syncedTracks = trackStore.load()
        let remaining = trackStore.syncedAlbumIds()
        for (albumId, status) in albumSyncStatus {
            if case .synced = status, !remaining.contains(albumId) {
                albumSyncStatus[albumId] = .notSynced
            }
        }
    }

    func syncStatus(for albumId: String) -> AlbumSyncStatus {
        albumSyncStatus[albumId] ?? .notSynced
    }

    // MARK: - Private

    private func loadSyncedState() {
        syncedTracks = trackStore.load()
        for albumId in trackStore.syncedAlbumIds() {
            albumSyncStatus[albumId] = .synced
        }
    }
}
