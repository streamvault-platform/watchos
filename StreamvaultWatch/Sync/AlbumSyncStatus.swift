import Foundation

enum AlbumSyncStatus: Equatable {
    case notSynced
    case syncing(progress: Double)
    case synced
    case failed(String)
}
