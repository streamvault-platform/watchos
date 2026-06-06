import Foundation

struct Artist: Decodable, Identifiable, Hashable {
    let id: String
    let name: String
}

struct Album: Decodable, Identifiable, Hashable {
    let id: String
    let title: String
    let artistName: String?
    let year: Int?
    let coverArtUrl: String?
}

struct Track: Decodable, Identifiable, Hashable {
    let id: String
    let title: String
    let artistName: String?
    let albumTitle: String?
    let albumId: String?
    let durationSeconds: Int?
    let trackNumber: Int?
}
