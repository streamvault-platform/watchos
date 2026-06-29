import SwiftUI

struct PlayerView: View {
    @EnvironmentObject private var playerVM: PlayerViewModel

    var body: some View {
        VStack(spacing: 6) {
            trackInfo
            Spacer(minLength: 0)
            seekBar
            timeLabels
            controls
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .navigationTitle("Now Playing")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Subviews

    private var trackInfo: some View {
        VStack(spacing: 2) {
            Text(playerVM.currentTrack?.title ?? "—")
                .font(.headline)
                .lineLimit(2)
                .multilineTextAlignment(.center)
            if let artist = playerVM.currentTrack?.artistName {
                Text(artist)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private var seekBar: some View {
        Slider(
            value: Binding(
                get: { playerVM.seekProgress },
                set: { playerVM.seek(to: $0) }
            ),
            in: 0...1
        )
        .disabled(playerVM.duration == 0)
    }

    private var timeLabels: some View {
        HStack {
            Text(playerVM.formattedCurrentTime)
            Spacer()
            Text(playerVM.formattedDuration)
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
    }

    private var controls: some View {
        HStack(spacing: 20) {
            Button { playerVM.skipPrevious() } label: {
                Image(systemName: "backward.fill")
                    .font(.body)
            }
            Button { playerVM.togglePlayPause() } label: {
                Image(systemName: playerVM.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title3)
                    .frame(width: 28)
            }
            Button { playerVM.skipNext() } label: {
                Image(systemName: "forward.fill")
                    .font(.body)
            }
        }
        .buttonStyle(.plain)
    }
}
