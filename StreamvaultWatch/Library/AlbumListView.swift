import SwiftUI

struct AlbumListView: View {
    let artist: Artist
    @EnvironmentObject private var vm: LibraryViewModel
    @State private var albums: [Album] = []
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
            } else if albums.isEmpty {
                Text("No albums")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                List(albums) { album in
                    NavigationLink(value: album) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(album.title)
                            if let year = album.year {
                                Text(String(year))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(artist.name)
        .navigationDestination(for: Album.self) { album in
            TrackListView(album: album)
        }
        .task {
            isLoading = true
            error = nil
            do {
                albums = try await vm.fetchAlbums(for: artist.id)
            } catch {
                self.error = "Could not load albums"
            }
            isLoading = false
        }
    }
}
