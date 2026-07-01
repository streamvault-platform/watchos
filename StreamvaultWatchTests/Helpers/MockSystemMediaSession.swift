import Foundation
@testable import StreamvaultWatch

final class MockSystemMediaSession: SystemMediaSession {
    private(set) var nowPlayingHistory: [[String: Any]?] = []
    private(set) var playHandler: (() -> Void)?
    private(set) var pauseHandler: (() -> Void)?
    private(set) var nextHandler: (() -> Void)?
    private(set) var previousHandler: (() -> Void)?
    private(set) var seekHandler: ((TimeInterval) -> Void)?

    var lastNowPlaying: [String: Any]? { nowPlayingHistory.last.flatMap { $0 } }
    // true when the most recent call was updateNowPlaying(nil)
    var wasCleared: Bool { !nowPlayingHistory.isEmpty && nowPlayingHistory.last! == nil }

    func updateNowPlaying(_ info: [String: Any]?) { nowPlayingHistory.append(info) }
    func onPlay(_ handler: @escaping () -> Void)                { playHandler = handler }
    func onPause(_ handler: @escaping () -> Void)               { pauseHandler = handler }
    func onNext(_ handler: @escaping () -> Void)                { nextHandler = handler }
    func onPrevious(_ handler: @escaping () -> Void)            { previousHandler = handler }
    func onSeek(_ handler: @escaping (TimeInterval) -> Void)    { seekHandler = handler }
}
