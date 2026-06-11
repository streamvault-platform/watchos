import XCTest
@testable import StreamvaultWatch

@MainActor
final class LibraryViewModelTests: XCTestCase {
    private var vm: LibraryViewModel!
    private var requestHandler: ((URLRequest) throws -> (Data, URLResponse))?

    override func setUp() {
        super.setUp()
        let keychain = InMemoryKeychain()
        let repo = TokenRepository(
            keychain: keychain,
            userDefaults: UserDefaults(suiteName: UUID().uuidString)!
        )
        repo.save(serverUrl: "http://localhost:8080", accessToken: "tok", refreshToken: "ref")
        let client = APIClient(tokenRepository: repo) { [weak self] req in
            guard let handler = self?.requestHandler else { throw URLError(.unknown) }
            return try handler(req)
        }
        vm = LibraryViewModel(apiClient: client)
    }

    // MARK: - fetchArtists

    func test_fetchArtists_populatesArtists() async throws {
        requestHandler = { req in
            try self.ok(req, body: [Artist(id: "1", name: "The Beatles")])
        }
        await vm.fetchArtists()
        XCTAssertEqual(vm.artists.count, 1)
        XCTAssertEqual(vm.artists.first?.name, "The Beatles")
        XCTAssertFalse(vm.isLoading)
        XCTAssertNil(vm.error)
    }

    func test_fetchArtists_setsErrorOnFailure() async {
        requestHandler = { _ in throw URLError(.notConnectedToInternet) }
        await vm.fetchArtists()
        XCTAssertTrue(vm.artists.isEmpty)
        XCTAssertNotNil(vm.error)
        XCTAssertFalse(vm.isLoading)
    }

    func test_fetchArtists_sendsRequestToCorrectPath() async throws {
        var captured: URLRequest?
        requestHandler = { req in
            captured = req
            return try self.ok(req, body: [Artist]())
        }
        await vm.fetchArtists()
        XCTAssertTrue(captured?.url?.path == "/api/library/artists")
    }

    // MARK: - fetchAlbums

    func test_fetchAlbums_returnsAlbums() async throws {
        requestHandler = { req in
            try self.ok(req, body: [Album(id: "a1", title: "Abbey Road", artistName: "The Beatles", year: 1969, coverUrl: nil)])
        }
        let albums = try await vm.fetchAlbums(for: "1")
        XCTAssertEqual(albums.count, 1)
        XCTAssertEqual(albums.first?.title, "Abbey Road")
    }

    func test_fetchAlbums_includesArtistIdQueryParam() async throws {
        var captured: URLRequest?
        requestHandler = { req in
            captured = req
            return try self.ok(req, body: [Album]())
        }
        _ = try await vm.fetchAlbums(for: "artist-42")
        XCTAssertTrue(captured?.url?.query?.contains("artistId=artist-42") == true)
    }

    // MARK: - fetchTracks

    func test_fetchTracks_returnsTracks() async throws {
        requestHandler = { req in
            try self.ok(req, body: [Track(id: "t1", title: "Come Together", artistName: "The Beatles", albumTitle: "Abbey Road", albumId: "a1", durationMs: 259000, trackNumber: 1)])
        }
        let tracks = try await vm.fetchTracks(for: "a1")
        XCTAssertEqual(tracks.count, 1)
        XCTAssertEqual(tracks.first?.title, "Come Together")
    }

    func test_fetchTracks_includesAlbumIdQueryParam() async throws {
        var captured: URLRequest?
        requestHandler = { req in
            captured = req
            return try self.ok(req, body: [Track]())
        }
        _ = try await vm.fetchTracks(for: "album-99")
        XCTAssertTrue(captured?.url?.query?.contains("albumId=album-99") == true)
    }

    // MARK: - Helpers

    private func ok<T: Encodable>(_ request: URLRequest, body: T) throws -> (Data, URLResponse) {
        let data = try JSONEncoder().encode(body)
        let http = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        return (data, http)
    }
}
