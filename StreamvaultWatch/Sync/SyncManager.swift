import Foundation

enum SyncError: LocalizedError {
    case timeout
    case invalidDownloadURL(String)

    var errorDescription: String? {
        switch self {
        case .timeout: return "Sync timed out — check your connection"
        case .invalidDownloadURL(let id): return "Invalid download URL for track \(id)"
        }
    }
}

protocol SyncManaging: AnyObject {
    var deviceId: String { get }
    func syncAlbum(
        albumId: String,
        albumTitle: String,
        tracks: [Track],
        onProgress: @escaping (Double) -> Void
    ) async throws -> [SyncedTrack]
}

final class SyncManager: SyncManaging {
    let deviceId: String
    private let apiClient: APIClient
    private let trackStore: TrackStore
    private let session: URLSession

    init(
        apiClient: APIClient,
        trackStore: TrackStore = TrackStore(),
        session: URLSession = .shared,
        userDefaults: UserDefaults = UserDefaults(suiteName: "group.io.streamvault") ?? .standard
    ) {
        self.apiClient = apiClient
        self.trackStore = trackStore
        self.session = session
        if let existing = userDefaults.string(forKey: "syncDeviceId") {
            deviceId = existing
        } else {
            let new = UUID().uuidString
            userDefaults.set(new, forKey: "syncDeviceId")
            deviceId = new
        }
    }

    func syncAlbum(
        albumId: String,
        albumTitle: String,
        tracks: [Track],
        onProgress: @escaping (Double) -> Void
    ) async throws -> [SyncedTrack] {
        let trackIds = tracks.map(\.id)

        let wsURL = try apiClient.watchSyncWebSocketURL(deviceId: deviceId)
        let wsTask = session.webSocketTask(with: wsURL)
        wsTask.resume()
        defer { wsTask.cancel(with: .goingAway, reason: nil) }

        let response: SyncStatusResponse = try await apiClient.requestSync(deviceId: deviceId, trackIds: trackIds)
        let notification = try await waitForNotification(task: wsTask, syncRequestId: response.syncRequestId)

        return try await downloadManifest(notification.manifest, tracks: tracks, albumId: albumId, onProgress: onProgress)
    }

    // MARK: - Private

    private func waitForNotification(
        task: URLSessionWebSocketTask,
        syncRequestId: String
    ) async throws -> SyncReadyNotification {
        let decoder = JSONDecoder()
        return try await withThrowingTaskGroup(of: SyncReadyNotification?.self) { group in
            group.addTask {
                while true {
                    let msg = try await task.receive()
                    guard case .string(let text) = msg,
                          let data = text.data(using: .utf8),
                          let n = try? decoder.decode(SyncReadyNotification.self, from: data),
                          n.syncRequestId == syncRequestId else { continue }
                    return n
                }
            }
            group.addTask {
                try await Task.sleep(nanoseconds: 5 * 60 * 1_000_000_000)
                return nil
            }
            for try await result in group {
                group.cancelAll()
                if let n = result { return n }
                throw SyncError.timeout
            }
            throw SyncError.timeout
        }
    }

    private func downloadManifest(
        _ manifest: [SyncReadyNotification.ManifestEntry],
        tracks: [Track],
        albumId: String,
        onProgress: @escaping (Double) -> Void
    ) async throws -> [SyncedTrack] {
        let total = max(manifest.count, 1)
        var synced: [SyncedTrack] = []

        try await withThrowingTaskGroup(of: SyncedTrack.self) { group in
            for entry in manifest {
                let meta = tracks.first { $0.id == entry.trackId }
                group.addTask {
                    guard let url = URL(string: entry.downloadUrl) else {
                        throw SyncError.invalidDownloadURL(entry.trackId)
                    }
                    let localURL = TrackStore.localURL(for: entry.trackId)
                    try FileManager.default.createDirectory(
                        at: localURL.deletingLastPathComponent(),
                        withIntermediateDirectories: true
                    )
                    let (tempURL, _) = try await URLSession.shared.download(from: url)
                    try? FileManager.default.removeItem(at: localURL)
                    try FileManager.default.moveItem(at: tempURL, to: localURL)
                    return SyncedTrack(
                        id: entry.trackId,
                        title: meta?.title ?? entry.trackId,
                        artistName: meta?.artistName,
                        albumId: albumId,
                        localPath: localURL.path,
                        syncedAt: Date()
                    )
                }
            }
            for try await result in group {
                try trackStore.save(result)
                synced.append(result)
                let progress = Double(synced.count) / Double(total)
                Task { @MainActor in onProgress(progress) }
            }
        }
        return synced
    }
}
