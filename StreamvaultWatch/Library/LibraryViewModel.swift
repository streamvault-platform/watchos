import Foundation

@MainActor
final class LibraryViewModel: ObservableObject {
    @Published private(set) var artists: [Artist] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: String?

    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func fetchArtists() async {
        isLoading = true
        error = nil
        do {
            artists = try await apiClient.get("/api/library/artists?page=0&size=200")
        } catch {
            self.error = "Could not load artists"
        }
        isLoading = false
    }

    func fetchAlbums(for artistId: String) async throws -> [Album] {
        try await apiClient.get("/api/library/albums?artistId=\(artistId)&page=0&size=200")
    }

    func fetchTracks(for albumId: String) async throws -> [Track] {
        try await apiClient.get("/api/library/tracks?albumId=\(albumId)&page=0&size=200")
    }
}
