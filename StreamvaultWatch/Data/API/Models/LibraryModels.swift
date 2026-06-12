import Foundation

struct Artist: Codable, Identifiable, Hashable {
    let id: String
    let name: String
}

struct Album: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let artistName: String?
    let year: Int?
    let coverUrl: String?
}

struct Track: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let artistName: String?
    let albumTitle: String?
    let albumId: String?
    let durationMs: Int?
    let trackNumber: Int?
}
