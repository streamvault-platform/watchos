import XCTest
@testable import StreamvaultWatch

@MainActor
final class PlayerViewModelTests: XCTestCase {

    private var mock: MockAudioPlayer!
    private var playbackManager: PlaybackManager!
    private var vm: PlayerViewModel!

    override func setUp() {
        super.setUp()
        mock = MockAudioPlayer()
        playbackManager = PlaybackManager(player: mock)
        vm = PlayerViewModel(playbackManager: playbackManager)
    }

    // MARK: - seekProgress

    func testSeekProgressIsZeroWithNoDuration() {
        XCTAssertEqual(vm.seekProgress, 0)
    }

    func testSeekProgressComputedFromCurrentTimeAndDuration() {
        playbackManager.load(tracks: makeTracks("a"), startingAt: 0)
        mock.simulateTimeUpdate(30)
        playbackManager._setDuration(120)
        XCTAssertEqual(vm.seekProgress, 0.25, accuracy: 0.001)
    }

    func testSeekProgressClampsToOne() {
        playbackManager.load(tracks: makeTracks("a"))
        mock.simulateTimeUpdate(200)
        playbackManager._setDuration(100)
        XCTAssertLessThanOrEqual(vm.seekProgress, 1.0)
    }

    // MARK: - formattedCurrentTime / formattedDuration

    func testFormatsZeroAsZeroZeroZero() {
        XCTAssertEqual(vm.formattedCurrentTime, "0:00")
    }

    func testFormatsSecondsOnly() {
        playbackManager.load(tracks: makeTracks("a"))
        mock.simulateTimeUpdate(45)
        XCTAssertEqual(vm.formattedCurrentTime, "0:45")
    }

    func testFormatsMinutesAndSeconds() {
        playbackManager.load(tracks: makeTracks("a"))
        mock.simulateTimeUpdate(90)
        XCTAssertEqual(vm.formattedCurrentTime, "1:30")
    }

    func testFormatsLargeDuration() {
        playbackManager.load(tracks: makeTracks("a"))
        mock.simulateTimeUpdate(3661)
        XCTAssertEqual(vm.formattedCurrentTime, "61:01")
    }

    func testFormattedDurationUsesPlaybackManagerDuration() {
        playbackManager.load(tracks: makeTracks("a"))
        playbackManager._setDuration(180)
        XCTAssertEqual(vm.formattedDuration, "3:00")
    }

    // MARK: - loadAlbum

    func testLoadAlbumDelegatesToPlaybackManager() {
        let tracks = makeTracks("a", "b", "c")
        vm.loadAlbum(tracks, startingAt: 1)
        XCTAssertEqual(playbackManager.currentIndex, 1)
        XCTAssertEqual(playbackManager.currentTrack?.id, "b")
    }

    // MARK: - seek

    func testSeekConvertsProgressToTime() {
        playbackManager.load(tracks: makeTracks("a"))
        playbackManager._setDuration(200)
        vm.seek(to: 0.5)
        XCTAssertTrue(mock.seekCalled)
        XCTAssertEqual(mock.lastSeekTime?.seconds ?? -1, 100, accuracy: 0.1)
    }

    func testSeekWithZeroDurationSeeksToZero() {
        playbackManager.load(tracks: makeTracks("a"))
        vm.seek(to: 0.5)
        XCTAssertEqual(mock.lastSeekTime?.seconds ?? -1, 0, accuracy: 0.001)
    }

    // MARK: - forwarded state

    func testHasTrackFalseWhenNoTrackLoaded() {
        XCTAssertFalse(vm.hasTrack)
    }

    func testHasTrackTrueAfterLoad() {
        vm.loadAlbum(makeTracks("a"))
        XCTAssertTrue(vm.hasTrack)
    }

    func testIsPlayingMirrorsPlaybackManager() {
        vm.loadAlbum(makeTracks("a"))
        XCTAssertTrue(vm.isPlaying)
        vm.togglePlayPause()
        XCTAssertFalse(vm.isPlaying)
    }

    func testCurrentTrackMirrorsPlaybackManager() {
        vm.loadAlbum(makeTracks("x", "y"), startingAt: 1)
        XCTAssertEqual(vm.currentTrack?.id, "y")
    }

    func testSkipNextDelegatesToPlaybackManager() {
        vm.loadAlbum(makeTracks("a", "b"))
        vm.skipNext()
        XCTAssertEqual(playbackManager.currentIndex, 1)
    }

    func testSkipPreviousDelegatesToPlaybackManager() {
        vm.loadAlbum(makeTracks("a", "b"), startingAt: 1)
        vm.skipPrevious()
        XCTAssertEqual(playbackManager.currentIndex, 0)
    }

    // MARK: - Helpers

    private func makeTracks(_ ids: String...) -> [SyncedTrack] {
        ids.map { id in
            SyncedTrack(id: id, title: "Track \(id)", artistName: "Artist",
                        albumId: "album-1", localPath: "/tmp/\(id).m4a", syncedAt: Date())
        }
    }
}
