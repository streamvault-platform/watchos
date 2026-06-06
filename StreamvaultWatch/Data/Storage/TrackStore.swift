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
    // TODO: persist SyncedTrack list as JSON in Documents/
}
