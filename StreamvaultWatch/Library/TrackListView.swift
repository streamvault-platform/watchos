import SwiftUI

struct TrackListView: View {
    let album: Album
    @EnvironmentObject private var vm: LibraryViewModel
    @EnvironmentObject private var syncVM: SyncViewModel
    @State private var tracks: [Track] = []
    @State private var isLoading = false
    @State private var error: String?

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
                        VStack(alignment: .leading, spacing: 2) {
                            Text(track.title)
                            if let artist = track.artistName {
                                Text(artist)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    Section {
                        syncButton
                    }
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
