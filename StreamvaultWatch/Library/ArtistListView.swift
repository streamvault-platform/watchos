import SwiftUI

struct ArtistListView: View {
    @EnvironmentObject private var vm: LibraryViewModel

    var body: some View {
        Group {
            if vm.isLoading && vm.artists.isEmpty {
                ProgressView()
            } else if let error = vm.error {
                VStack(spacing: 8) {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Retry") { Task { await vm.fetchArtists() } }
                }
                .padding()
            } else if vm.artists.isEmpty {
                Text("No artists")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                List(vm.artists) { artist in
                    NavigationLink(value: artist) {
                        Text(artist.name)
                    }
                }
            }
        }
        .navigationTitle("Artists")
        .navigationDestination(for: Artist.self) { artist in
            AlbumListView(artist: artist)
        }
        .task { await vm.fetchArtists() }
    }
}
