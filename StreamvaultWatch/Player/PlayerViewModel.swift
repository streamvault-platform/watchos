import Combine
import Foundation

@MainActor
final class PlayerViewModel: ObservableObject {

    let playbackManager: PlaybackManager
    private var cancellables = Set<AnyCancellable>()

    init(playbackManager: PlaybackManager) {
        self.playbackManager = playbackManager
        // Forward all PlaybackManager changes so views re-render
        playbackManager.objectWillChange
            .sink { [weak self] in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    // MARK: - Forwarded state

    var currentTrack: SyncedTrack? { playbackManager.currentTrack }
    var isPlaying: Bool { playbackManager.isPlaying }
    var currentTime: TimeInterval { playbackManager.currentTime }
    var duration: TimeInterval { playbackManager.duration }
    var hasTrack: Bool { playbackManager.currentTrack != nil }

    // MARK: - Derived display state

    var seekProgress: Double {
        guard duration > 0 else { return 0 }
        return min(currentTime / duration, 1)
    }

    var formattedCurrentTime: String { formatTime(currentTime) }
    var formattedDuration: String { formatTime(duration) }

    // MARK: - Actions

    func loadAlbum(_ tracks: [SyncedTrack], startingAt index: Int = 0) {
        playbackManager.load(tracks: tracks, startingAt: index)
    }

    func togglePlayPause() { playbackManager.togglePlayPause() }
    func skipNext() { playbackManager.skipNext() }
    func skipPrevious() { playbackManager.skipPrevious() }

    func seek(to progress: Double) {
        playbackManager.seek(to: progress * duration)
    }

    // MARK: - Private

    private func formatTime(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let total = Int(seconds)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
