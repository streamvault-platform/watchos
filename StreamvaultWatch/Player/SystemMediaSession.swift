import MediaPlayer

protocol SystemMediaSession {
    func updateNowPlaying(_ info: [String: Any]?)
    func onPlay(_ handler: @escaping () -> Void)
    func onPause(_ handler: @escaping () -> Void)
    func onNext(_ handler: @escaping () -> Void)
    func onPrevious(_ handler: @escaping () -> Void)
    func onSeek(_ handler: @escaping (TimeInterval) -> Void)
}

final class LiveSystemMediaSession: SystemMediaSession {
    private let commandCenter = MPRemoteCommandCenter.shared()

    func updateNowPlaying(_ info: [String: Any]?) {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    func onPlay(_ handler: @escaping () -> Void) {
        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { _ in handler(); return .success }
    }

    func onPause(_ handler: @escaping () -> Void) {
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { _ in handler(); return .success }
    }

    func onNext(_ handler: @escaping () -> Void) {
        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.nextTrackCommand.addTarget { _ in handler(); return .success }
    }

    func onPrevious(_ handler: @escaping () -> Void) {
        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.addTarget { _ in handler(); return .success }
    }

    func onSeek(_ handler: @escaping (TimeInterval) -> Void) {
        commandCenter.changePlaybackPositionCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.addTarget { event in
            if let e = event as? MPChangePlaybackPositionCommandEvent {
                handler(e.positionTime)
            }
            return .success
        }
    }
}
