import XCTest
@testable import StreamvaultWatch

@MainActor
final class SyncViewModelTests: XCTestCase {
    private var mockManager: MockSyncManager!
    private var tempDir: URL!
    private var trackStore: TrackStore!
    private var viewModel: SyncViewModel!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        mockManager = MockSyncManager()
        trackStore = TrackStore(documentsURL: tempDir)
        viewModel = SyncViewModel(syncManager: mockManager, trackStore: trackStore)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: tempDir)
    }

    // MARK: - requestSync

    func test_requestSync_setsStatusToSynced_onSuccess() async throws {
        let album = Album(id: "a1", title: "Album", artistName: nil, year: nil, coverUrl: nil)
        let tracks = [makeTrack(id: "t1", albumId: "a1")]
        mockManager.syncResult = .success([makeSyncedTrack(id: "t1", albumId: "a1")])

        await viewModel.requestSync(album: album, tracks: tracks)

        XCTAssertEqual(viewModel.syncStatus(for: "a1"), .synced)
    }

    func test_requestSync_setsStatusToFailed_onError() async throws {
        let album = Album(id: "a1", title: "Album", artistName: nil, year: nil, coverUrl: nil)
        let tracks = [makeTrack(id: "t1", albumId: "a1")]
        mockManager.syncResult = .failure(SyncError.timeout)

        await viewModel.requestSync(album: album, tracks: tracks)

        if case .failed = viewModel.syncStatus(for: "a1") {
            // expected
        } else {
            XCTFail("Expected .failed but got \(viewModel.syncStatus(for: "a1"))")
        }
    }

    func test_requestSync_callsSyncAlbum_withCorrectArguments() async throws {
        let album = Album(id: "a1", title: "Album One", artistName: "Artist", year: 2024, coverUrl: nil)
        let tracks = [makeTrack(id: "t1", albumId: "a1"), makeTrack(id: "t2", albumId: "a1")]
        mockManager.syncResult = .success([])

        await viewModel.requestSync(album: album, tracks: tracks)

        XCTAssertEqual(mockManager.syncAlbumCalls.count, 1)
        XCTAssertEqual(mockManager.syncAlbumCalls[0].albumId, "a1")
        XCTAssertEqual(mockManager.syncAlbumCalls[0].albumTitle, "Album One")
        XCTAssertEqual(mockManager.syncAlbumCalls[0].tracks.count, 2)
    }

    func test_requestSync_noOp_whenTracksEmpty() async throws {
        let album = Album(id: "a1", title: "Album", artistName: nil, year: nil, coverUrl: nil)

        await viewModel.requestSync(album: album, tracks: [])

        XCTAssertTrue(mockManager.syncAlbumCalls.isEmpty)
        XCTAssertEqual(viewModel.syncStatus(for: "a1"), .notSynced)
    }

    func test_requestSync_updatesSyncedTracks_onSuccess() async throws {
        let album = Album(id: "a1", title: "Album", artistName: nil, year: nil, coverUrl: nil)
        let tracks = [makeTrack(id: "t1", albumId: "a1")]
        let synced = makeSyncedTrack(id: "t1", albumId: "a1")
        try trackStore.save(synced)
        mockManager.syncResult = .success([synced])

        await viewModel.requestSync(album: album, tracks: tracks)

        XCTAssertEqual(viewModel.syncedTracks.count, 1)
        XCTAssertEqual(viewModel.syncedTracks[0].id, "t1")
    }

    // MARK: - removeTrack

    func test_removeTrack_removesFromSyncedTracks() throws {
        let track = makeSyncedTrack(id: "t1", albumId: "a1")
        try trackStore.save(track)
        viewModel = SyncViewModel(syncManager: mockManager, trackStore: trackStore)

        viewModel.removeTrack("t1")

        XCTAssertEqual(viewModel.syncedTracks.count, 0)
    }

    func test_removeTrack_resetsAlbumStatus_whenLastTrackRemoved() throws {
        let track = makeSyncedTrack(id: "t1", albumId: "a1")
        try trackStore.save(track)
        viewModel = SyncViewModel(syncManager: mockManager, trackStore: trackStore)
        XCTAssertEqual(viewModel.syncStatus(for: "a1"), .synced)

        viewModel.removeTrack("t1")

        XCTAssertEqual(viewModel.syncStatus(for: "a1"), .notSynced)
    }

    // MARK: - Initial state

    func test_init_loadsExistingSyncedState() throws {
        let track = makeSyncedTrack(id: "t1", albumId: "a1")
        try trackStore.save(track)

        let freshVM = SyncViewModel(syncManager: mockManager, trackStore: trackStore)

        XCTAssertEqual(freshVM.syncedTracks.count, 1)
        XCTAssertEqual(freshVM.syncStatus(for: "a1"), .synced)
    }

    func test_deviceId_comesFromSyncManager() {
        XCTAssertEqual(viewModel.deviceId, "mock-device-id")
    }

    // MARK: - Helpers

    private func makeTrack(id: String, albumId: String) -> Track {
        Track(id: id, title: "Track \(id)", artistName: "Artist",
              albumTitle: "Album", albumId: albumId, durationMs: 30000, trackNumber: 1)
    }

    private func makeSyncedTrack(id: String, albumId: String) -> SyncedTrack {
        SyncedTrack(id: id, title: "Track \(id)", artistName: "Artist",
                    albumId: albumId, localPath: "/tmp/\(id)", syncedAt: Date())
    }
}

// MARK: - Mock

final class MockSyncManager: SyncManaging {
    let deviceId = "mock-device-id"
    var syncResult: Result<[SyncedTrack], Error> = .success([])
    var syncAlbumCalls: [(albumId: String, albumTitle: String, tracks: [Track])] = []

    func syncAlbum(
        albumId: String,
        albumTitle: String,
        tracks: [Track],
        onProgress: @escaping (Double) -> Void
    ) async throws -> [SyncedTrack] {
        syncAlbumCalls.append((albumId, albumTitle, tracks))
        return try syncResult.get()
    }
}
