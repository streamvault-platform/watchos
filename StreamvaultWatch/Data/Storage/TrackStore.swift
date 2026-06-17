import Foundation

struct SyncedTrack: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let artistName: String?
    let albumId: String?
    let localPath: String
    let syncedAt: Date
}

final class TrackStore {
    private let storeURL: URL
    private let tracksDir: URL

    init(documentsURL: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]) {
        storeURL = documentsURL.appendingPathComponent("syncedTracks.json")
        tracksDir = documentsURL.appendingPathComponent("tracks")
    }

    static func localURL(for trackId: String) -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("tracks/\(trackId)")
    }

    func save(_ track: SyncedTrack) throws {
        var all = load()
        all.removeAll { $0.id == track.id }
        all.append(track)
        let data = try JSONEncoder().encode(all)
        try data.write(to: storeURL, options: .atomic)
    }

    func load() -> [SyncedTrack] {
        guard let data = try? Data(contentsOf: storeURL),
              let tracks = try? JSONDecoder().decode([SyncedTrack].self, from: data)
        else { return [] }
        return tracks
    }

    func isSynced(trackId: String) -> Bool {
        load().contains { $0.id == trackId }
    }

    func syncedAlbumIds() -> Set<String> {
        Set(load().compactMap(\.albumId))
    }

    func remove(trackId: String) throws {
        var all = load()
        guard let track = all.first(where: { $0.id == trackId }) else { return }
        all.removeAll { $0.id == trackId }
        let data = try JSONEncoder().encode(all)
        try data.write(to: storeURL, options: .atomic)
        try? FileManager.default.removeItem(atPath: track.localPath)
    }
}
