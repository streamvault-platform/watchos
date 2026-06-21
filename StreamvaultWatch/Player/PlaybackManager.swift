import AVFoundation
import Combine

protocol AudioPlayer: AnyObject {
    var rate: Float { get }
    func replaceCurrentItem(with item: AVPlayerItem?)
    func play()
    func pause()
    func seek(to time: CMTime, completionHandler: @escaping (Bool) -> Void)
    func addPeriodicTimeObserver(forInterval interval: CMTime, queue: DispatchQueue?, using block: @escaping (CMTime) -> Void) -> Any
    func removeTimeObserver(_ observer: Any)
}

extension AVPlayer: AudioPlayer {}

@MainActor
final class PlaybackManager: ObservableObject {

    @Published private(set) var queue: [SyncedTrack] = []
    @Published private(set) var currentIndex: Int? = nil
    @Published private(set) var isPlaying: Bool = false
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0

    var currentTrack: SyncedTrack? {
        guard let i = currentIndex, queue.indices.contains(i) else { return nil }
        return queue[i]
    }

    private let player: AudioPlayer
    // nonisolated(unsafe) lets deinit access the token without actor isolation warnings
    nonisolated(unsafe) private var timeObserverToken: Any?
    private var itemEndObserver: NSObjectProtocol?

    init(player: AudioPlayer = AVPlayer()) {
        self.player = player
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            MainActor.assumeIsolated {
                self?.currentTime = time.seconds
            }
        }
    }

    deinit {
        if let token = timeObserverToken {
            player.removeTimeObserver(token)
        }
        if let obs = itemEndObserver {
            NotificationCenter.default.removeObserver(obs)
        }
    }

    // MARK: - Public API

    func load(tracks: [SyncedTrack], startingAt index: Int = 0) {
        queue = tracks
        guard !tracks.isEmpty, tracks.indices.contains(index) else {
            currentIndex = nil
            player.replaceCurrentItem(with: nil)
            isPlaying = false
            return
        }
        currentIndex = index
        loadCurrentItem()
        player.play()
        isPlaying = true
    }

    func play() {
        guard currentIndex != nil else { return }
        player.play()
        isPlaying = true
    }

    func pause() {
        player.pause()
        isPlaying = false
    }

    func togglePlayPause() {
        isPlaying ? pause() : play()
    }

    func seek(to time: TimeInterval) {
        let target = CMTime(seconds: time, preferredTimescale: 600)
        player.seek(to: target) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.currentTime = time
            }
        }
    }

    func skipNext() {
        guard let i = currentIndex else { return }
        let next = i + 1
        guard next < queue.count else {
            pause()
            return
        }
        currentIndex = next
        loadCurrentItem()
        if isPlaying { player.play() }
    }

    func skipPrevious() {
        guard let i = currentIndex else { return }
        if currentTime > 3 {
            seek(to: 0)
            return
        }
        guard i > 0 else {
            seek(to: 0)
            return
        }
        currentIndex = i - 1
        loadCurrentItem()
        if isPlaying { player.play() }
    }

    // MARK: - Private

    private func loadCurrentItem() {
        if let obs = itemEndObserver {
            NotificationCenter.default.removeObserver(obs)
            itemEndObserver = nil
        }
        guard let track = currentTrack else { return }
        let item = AVPlayerItem(url: URL(fileURLWithPath: track.localPath))
        player.replaceCurrentItem(with: item)
        currentTime = 0
        duration = 0

        itemEndObserver = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.didPlayToEndTimeNotification,
            object: item,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.skipNext()
            }
        }

        Task { [weak self] in
            guard let self else { return }
            if let secs = try? await item.asset.load(.duration).seconds,
               secs.isFinite, !secs.isNaN {
                self.duration = secs
            }
        }
    }

    // MARK: - Test hooks

    #if DEBUG
    func _simulateItemEnd() { skipNext() }
    #endif
}
