import SwiftUI

struct TrackListView: View {
    let album: Album
    @EnvironmentObject private var vm: LibraryViewModel
    @EnvironmentObject private var syncVM: SyncViewModel
    @EnvironmentObject private var playerVM: PlayerViewModel
    @State private var tracks: [Track] = []
    @State private var isLoading = false
    @State private var error: String?
    @State private var navigateToPlayer = false

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if let error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
            } else if tracks.isEmpty {
                Text("No tracks")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                List {
                    ForEach(tracks) { track in
                        trackRow(track)
                    }
                    Section {
                        syncButton
                    }
                }
                .navigationDestination(isPresented: $navigateToPlayer) {
                    PlayerView()
                }
            }
        }
        .navigationTitle(album.title)
        .task {
            isLoading = true
            error = nil
            do {
                tracks = try await vm.fetchTracks(for: album.id)
            } catch {
                self.error = "Could not load tracks"
            }
            isLoading = false
        }
    }

    @ViewBuilder
    private func trackRow(_ track: Track) -> some View {
        let synced = syncVM.syncedTracks.first(where: { $0.id == track.id })
        if let synced {
            Button {
                let albumQueue = syncVM.syncedTracks
                    .filter { $0.albumId == album.id }
                    .sorted { ($0.id) < ($1.id) }
                let startIndex = albumQueue.firstIndex(where: { $0.id == synced.id }) ?? 0
                playerVM.loadAlbum(albumQueue, startingAt: startIndex)
                navigateToPlayer = true
            } label: {
                trackLabel(track, isAvailable: true)
            }
            .buttonStyle(.plain)
        } else {
            trackLabel(track, isAvailable: false)
        }
    }

    private func trackLabel(_ track: Track, isAvailable: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(track.title)
                .foregroundStyle(isAvailable ? .primary : .secondary)
            if let artist = track.artistName {
                Text(artist)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var syncButton: some View {
        let status = syncVM.syncStatus(for: album.id)
        switch status {
        case .notSynced:
            Button {
                Task { await syncVM.requestSync(album: album, tracks: tracks) }
            } label: {
                Label("Sync to Watch", systemImage: "arrow.down.circle")
            }
        case .syncing(let progress):
            VStack(alignment: .leading, spacing: 4) {
                Text("Syncing…")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .tint(.accentColor)
            }
            .padding(.vertical, 4)
        case .synced:
            Label("Synced", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.caption)
        case .failed:
            Button {
                Task { await syncVM.requestSync(album: album, tracks: tracks) }
            } label: {
                Label("Retry Sync", systemImage: "arrow.clockwise")
                    .foregroundStyle(.red)
            }
        }
    }
}
