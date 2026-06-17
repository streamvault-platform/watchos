import XCTest
@testable import StreamvaultWatch

final class TrackStoreTests: XCTestCase {
    private var tempDir: URL!
    private var store: TrackStore!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        store = TrackStore(documentsURL: tempDir)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: tempDir)
    }

    func test_load_returnsEmptyArray_whenNoDataStored() {
        XCTAssertEqual(store.load(), [])
    }

    func test_save_and_load_roundtrips() throws {
        let track = makeTrack(id: "t1", title: "Song A", albumId: "album1")
        try store.save(track)
        let loaded = store.load()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].id, "t1")
        XCTAssertEqual(loaded[0].title, "Song A")
    }

    func test_save_multipleTrack_preservesAll() throws {
        try store.save(makeTrack(id: "t1", title: "A", albumId: "album1"))
        try store.save(makeTrack(id: "t2", title: "B", albumId: "album1"))
        XCTAssertEqual(store.load().count, 2)
    }

    func test_save_existingId_updatesInPlace() throws {
        try store.save(makeTrack(id: "t1", title: "Original", albumId: "album1"))
        try store.save(makeTrack(id: "t1", title: "Updated", albumId: "album1"))
        let loaded = store.load()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].title, "Updated")
    }

    func test_isSynced_returnsFalse_forUnknownTrack() {
        XCTAssertFalse(store.isSynced(trackId: "unknown"))
    }

    func test_isSynced_returnsTrue_afterSave() throws {
        try store.save(makeTrack(id: "t1", title: "A", albumId: "album1"))
        XCTAssertTrue(store.isSynced(trackId: "t1"))
    }

    func test_syncedAlbumIds_returnsDistinctAlbumIds() throws {
        try store.save(makeTrack(id: "t1", title: "A", albumId: "album1"))
        try store.save(makeTrack(id: "t2", title: "B", albumId: "album1"))
        try store.save(makeTrack(id: "t3", title: "C", albumId: "album2"))
        XCTAssertEqual(store.syncedAlbumIds(), ["album1", "album2"])
    }

    func test_syncedAlbumIds_excludesTracksWithNilAlbumId() throws {
        let track = SyncedTrack(
            id: "t1", title: "A", artistName: nil,
            albumId: nil, localPath: "/tmp/t1", syncedAt: Date()
        )
        try store.save(track)
        XCTAssertTrue(store.syncedAlbumIds().isEmpty)
    }

    func test_remove_deletesTrackFromStore() throws {
        try store.save(makeTrack(id: "t1", title: "A", albumId: "album1"))
        try store.save(makeTrack(id: "t2", title: "B", albumId: "album1"))
        try store.remove(trackId: "t1")
        let loaded = store.load()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].id, "t2")
    }

    func test_remove_unknownId_doesNotThrow() throws {
        XCTAssertNoThrow(try store.remove(trackId: "nonexistent"))
    }

    func test_remove_deletesLocalFile() throws {
        let fakePath = tempDir.appendingPathComponent("tracks/t1")
        try FileManager.default.createDirectory(
            at: fakePath.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("audio".utf8).write(to: fakePath)
        let track = SyncedTrack(
            id: "t1", title: "A", artistName: nil,
            albumId: "album1", localPath: fakePath.path, syncedAt: Date()
        )
        try store.save(track)
        try store.remove(trackId: "t1")
        XCTAssertFalse(FileManager.default.fileExists(atPath: fakePath.path))
    }

    // MARK: - Helpers

    private func makeTrack(id: String, title: String, albumId: String?) -> SyncedTrack {
        SyncedTrack(
            id: id, title: title, artistName: "Artist",
            albumId: albumId, localPath: "/tmp/\(id)", syncedAt: Date()
        )
    }
}
