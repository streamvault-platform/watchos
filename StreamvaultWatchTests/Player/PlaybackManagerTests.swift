import AVFoundation
import XCTest
@testable import StreamvaultWatch

// MARK: - Mock

final class MockAudioPlayer: AudioPlayer {
    private(set) var rate: Float = 0
    private(set) var replaceItemCallCount = 0
    private(set) var playCalled = false
    private(set) var pauseCalled = false
    private(set) var seekCalled = false
    private(set) var lastSeekTime: CMTime?
    private var timeObserverBlock: ((CMTime) -> Void)?

    func replaceCurrentItem(with item: AVPlayerItem?) {
        replaceItemCallCount += 1
    }

    func play() {
        playCalled = true
        rate = 1
    }

    func pause() {
        pauseCalled = true
        rate = 0
    }

    func seek(to time: CMTime, completionHandler: @escaping (Bool) -> Void) {
        seekCalled = true
        lastSeekTime = time
        completionHandler(true)
    }

    func addPeriodicTimeObserver(forInterval interval: CMTime, queue: DispatchQueue?, using block: @escaping (CMTime) -> Void) -> Any {
        timeObserverBlock = block
        return NSObject()
    }

    func removeTimeObserver(_ observer: Any) {}

    // Drives the PlaybackManager's currentTime update synchronously (tests are @MainActor)
    func simulateTimeUpdate(_ seconds: TimeInterval) {
        timeObserverBlock?(CMTime(seconds: seconds, preferredTimescale: 600))
    }
}

// MARK: - Tests

@MainActor
final class PlaybackManagerTests: XCTestCase {

    private var mock: MockAudioPlayer!
    private var manager: PlaybackManager!

    override func setUp() {
        super.setUp()
        mock = MockAudioPlayer()
        manager = PlaybackManager(player: mock)
    }

    // MARK: load

    func testLoadStartsPlaybackAtFirstTrackByDefault() {
        manager.load(tracks: makeTracks("a", "b", "c"))
        XCTAssertEqual(manager.currentIndex, 0)
        XCTAssertEqual(manager.currentTrack?.id, "a")
        XCTAssertTrue(manager.isPlaying)
        XCTAssertTrue(mock.playCalled)
    }

    func testLoadStartsPlaybackAtGivenIndex() {
        manager.load(tracks: makeTracks("a", "b", "c"), startingAt: 2)
        XCTAssertEqual(manager.currentIndex, 2)
        XCTAssertEqual(manager.currentTrack?.id, "c")
    }

    func testLoadEmptyQueueClearsState() {
        manager.load(tracks: makeTracks("a"))
        manager.load(tracks: [])
        XCTAssertNil(manager.currentIndex)
        XCTAssertNil(manager.currentTrack)
        XCTAssertFalse(manager.isPlaying)
    }

    func testLoadOutOfBoundsIndexClearsState() {
        manager.load(tracks: makeTracks("a"), startingAt: 5)
        XCTAssertNil(manager.currentIndex)
        XCTAssertFalse(manager.isPlaying)
    }

    // MARK: play / pause / toggle

    func testPauseSetsIsPlayingFalse() {
        manager.load(tracks: makeTracks("a"))
        manager.pause()
        XCTAssertFalse(manager.isPlaying)
        XCTAssertTrue(mock.pauseCalled)
    }

    func testTogglePlayPause() {
        manager.load(tracks: makeTracks("a"))
        XCTAssertTrue(manager.isPlaying)
        manager.togglePlayPause()
        XCTAssertFalse(manager.isPlaying)
        manager.togglePlayPause()
        XCTAssertTrue(manager.isPlaying)
    }

    func testPlayWithoutQueueDoesNothing() {
        manager.play()
        XCTAssertFalse(mock.playCalled)
    }

    // MARK: seek

    func testSeekCallsPlayerAndUpdatesCurrentTime() {
        manager.load(tracks: makeTracks("a"))
        manager.seek(to: 42.5)
        XCTAssertTrue(mock.seekCalled)
        XCTAssertEqual(mock.lastSeekTime?.seconds ?? -1, 42.5, accuracy: 0.001)
        XCTAssertEqual(manager.currentTime, 42.5, accuracy: 0.001)
    }

    // MARK: skipNext

    func testSkipNextAdvancesIndex() {
        manager.load(tracks: makeTracks("a", "b", "c"))
        manager.skipNext()
        XCTAssertEqual(manager.currentIndex, 1)
        XCTAssertEqual(manager.currentTrack?.id, "b")
    }

    func testSkipNextAtEndOfQueueStopsPlayback() {
        manager.load(tracks: makeTracks("a"))
        manager.skipNext()
        XCTAssertFalse(manager.isPlaying)
        XCTAssertEqual(manager.currentIndex, 0, "index stays at last track")
    }

    func testSkipNextContinuesIfPlaying() {
        manager.load(tracks: makeTracks("a", "b"))
        mock.playCalled = false
        manager.skipNext()
        XCTAssertTrue(mock.playCalled)
    }

    func testSkipNextDoesNotPlayIfPaused() {
        manager.load(tracks: makeTracks("a", "b"))
        manager.pause()
        mock.playCalled = false
        manager.skipNext()
        XCTAssertFalse(mock.playCalled)
    }

    // MARK: skipPrevious

    func testSkipPreviousDecrements() {
        manager.load(tracks: makeTracks("a", "b", "c"), startingAt: 2)
        manager.skipPrevious()
        XCTAssertEqual(manager.currentIndex, 1)
        XCTAssertEqual(manager.currentTrack?.id, "b")
    }

    func testSkipPreviousAtFirstTrackSeeksToZero() {
        manager.load(tracks: makeTracks("a", "b"))
        manager.skipPrevious()
        XCTAssertEqual(manager.currentIndex, 0, "index unchanged")
        XCTAssertTrue(mock.seekCalled)
        XCTAssertEqual(mock.lastSeekTime?.seconds ?? -1, 0, accuracy: 0.001)
    }

    func testSkipPreviousRewindsWhenTimeOver3() {
        manager.load(tracks: makeTracks("a", "b"), startingAt: 1)
        mock.simulateTimeUpdate(5.0)
        XCTAssertEqual(manager.currentTime, 5.0, accuracy: 0.001)
        manager.skipPrevious()
        // Should rewind, not go to previous track
        XCTAssertEqual(manager.currentIndex, 1, "should stay on same track")
        XCTAssertTrue(mock.seekCalled)
        XCTAssertEqual(mock.lastSeekTime?.seconds ?? -1, 0, accuracy: 0.001)
    }

    // MARK: item end auto-advance

    func testItemEndAutoAdvancesToNextTrack() {
        manager.load(tracks: makeTracks("a", "b"))
        manager._simulateItemEnd()
        XCTAssertEqual(manager.currentIndex, 1)
        XCTAssertEqual(manager.currentTrack?.id, "b")
    }

    func testItemEndAtLastTrackStops() {
        manager.load(tracks: makeTracks("a"))
        manager._simulateItemEnd()
        XCTAssertFalse(manager.isPlaying)
    }

    // MARK: time observer

    func testPeriodicTimeObserverUpdatesCurrentTime() {
        manager.load(tracks: makeTracks("a"))
        mock.simulateTimeUpdate(12.3)
        XCTAssertEqual(manager.currentTime, 12.3, accuracy: 0.001)
    }

    func testLoadResetsCurrentTime() {
        manager.load(tracks: makeTracks("a"))
        mock.simulateTimeUpdate(30.0)
        manager.load(tracks: makeTracks("b"))
        XCTAssertEqual(manager.currentTime, 0)
    }

    // MARK: - Helpers

    private func makeTracks(_ ids: String...) -> [SyncedTrack] {
        ids.map { id in
            SyncedTrack(id: id, title: "Track \(id)", artistName: "Artist",
                        albumId: "album-1", localPath: "/tmp/\(id).m4a", syncedAt: Date())
        }
    }
}
