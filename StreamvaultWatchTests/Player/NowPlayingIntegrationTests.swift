import MediaPlayer
import XCTest
@testable import StreamvaultWatch

@MainActor
final class NowPlayingIntegrationTests: XCTestCase {

    private var mock: MockAudioPlayer!
    private var session: MockSystemMediaSession!
    private var manager: PlaybackManager!

    override func setUp() {
        super.setUp()
        mock = MockAudioPlayer()
        session = MockSystemMediaSession()
        manager = PlaybackManager(player: mock, mediaSession: session)
    }

    // MARK: - Now Playing info

    func testNowPlayingSetOnLoad() {
        manager.load(tracks: makeTracks("a"))
        let info = session.lastNowPlaying
        XCTAssertEqual(info?[MPMediaItemPropertyTitle] as? String, "Track a")
        XCTAssertEqual(info?[MPMediaItemPropertyArtist] as? String, "Artist")
    }

    func testNowPlayingClearedWhenQueueEmpty() {
        manager.load(tracks: makeTracks("a"))
        manager.load(tracks: [])
        XCTAssertTrue(session.wasCleared)
    }

    func testNowPlayingRateZeroWhenPaused() {
        manager.load(tracks: makeTracks("a"))
        manager.pause()
        let rate = session.lastNowPlaying?[MPNowPlayingInfoPropertyPlaybackRate] as? Double
        XCTAssertEqual(rate, 0.0)
    }

    func testNowPlayingRateOneWhenPlaying() {
        manager.load(tracks: makeTracks("a"))
        manager.pause()
        manager.play()
        let rate = session.lastNowPlaying?[MPNowPlayingInfoPropertyPlaybackRate] as? Double
        XCTAssertEqual(rate, 1.0)
    }

    func testNowPlayingElapsedTimeUpdatesOnSeek() {
        manager.load(tracks: makeTracks("a"))
        manager.seek(to: 42)
        let elapsed = session.lastNowPlaying?[MPNowPlayingInfoPropertyElapsedPlaybackTime] as? TimeInterval
        XCTAssertEqual(elapsed ?? -1, 42, accuracy: 0.001)
    }

    func testNowPlayingDurationIncludedWhenNonZero() {
        manager.load(tracks: makeTracks("a"))
        manager._setDuration(180)
        let dur = session.lastNowPlaying?[MPMediaItemPropertyPlaybackDuration] as? TimeInterval
        XCTAssertEqual(dur ?? -1, 180, accuracy: 0.001)
    }

    func testNowPlayingDurationOmittedWhenZero() {
        manager.load(tracks: makeTracks("a"))
        // duration starts at 0 after load
        XCTAssertNil(session.lastNowPlaying?[MPMediaItemPropertyPlaybackDuration])
    }

    func testNowPlayingTitleUpdatesOnSkipNext() {
        manager.load(tracks: makeTracks("a", "b"))
        manager.skipNext()
        let title = session.lastNowPlaying?[MPMediaItemPropertyTitle] as? String
        XCTAssertEqual(title, "Track b")
    }

    // MARK: - Remote command handlers

    func testPlayCommandResumesPlayback() {
        manager.load(tracks: makeTracks("a"))
        manager.pause()
        XCTAssertFalse(manager.isPlaying)
        session.playHandler?()
        XCTAssertTrue(manager.isPlaying)
    }

    func testPauseCommandPausesPlayback() {
        manager.load(tracks: makeTracks("a"))
        XCTAssertTrue(manager.isPlaying)
        session.pauseHandler?()
        XCTAssertFalse(manager.isPlaying)
    }

    func testNextCommandAdvancesTrack() {
        manager.load(tracks: makeTracks("a", "b"))
        session.nextHandler?()
        XCTAssertEqual(manager.currentIndex, 1)
    }

    func testPreviousCommandGoesToPreviousTrack() {
        manager.load(tracks: makeTracks("a", "b"), startingAt: 1)
        session.previousHandler?()
        XCTAssertEqual(manager.currentIndex, 0)
    }

    func testSeekCommandSeeksToPosition() {
        manager.load(tracks: makeTracks("a"))
        session.seekHandler?(75.0)
        XCTAssertTrue(mock.seekCalled)
        XCTAssertEqual(mock.lastSeekTime?.seconds ?? -1, 75.0, accuracy: 0.001)
    }

    // MARK: - Helpers

    private func makeTracks(_ ids: String...) -> [SyncedTrack] {
        ids.map { id in
            SyncedTrack(id: id, title: "Track \(id)", artistName: "Artist",
                        albumId: "album-1", localPath: "/tmp/\(id).m4a", syncedAt: Date())
        }
    }
}
