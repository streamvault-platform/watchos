import Foundation

struct SyncRequest: Encodable {
    let deviceId: String
    let trackIds: [String]
}

struct SyncStatusResponse: Decodable {
    let syncRequestId: String
    let status: String
    let deviceId: String
    let trackCount: Int
}

struct SyncReadyNotification: Decodable {
    let type: String
    let syncRequestId: String
    let deviceId: String
    let manifest: [ManifestEntry]

    struct ManifestEntry: Decodable {
        let trackId: String
        let downloadUrl: String
        let fileSizeBytes: Int64
    }
}
