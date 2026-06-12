import SwiftUI

struct TrackListView: View {
    let album: Album
    @EnvironmentObject private var vm: LibraryViewModel
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
                List(tracks) { track in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(track.title)
                        if let artist = track.artistName {
                            Text(artist)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
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
}
