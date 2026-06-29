import SwiftUI

struct SyncView: View {
    @EnvironmentObject private var syncVM: SyncViewModel
    @EnvironmentObject private var playerVM: PlayerViewModel
    @State private var navigateToPlayer = false

    var body: some View {
        NavigationStack {
            Group {
                if syncVM.syncedTracks.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "arrow.down.circle")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("No downloads yet")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    List {
                        ForEach(Array(syncVM.syncedTracks.enumerated()), id: \.element.id) { index, track in
                            Button {
                                playerVM.loadAlbum(syncVM.syncedTracks, startingAt: index)
                                navigateToPlayer = true
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(track.title)
                                        .font(.body)
                                    if let artist = track.artistName {
                                        Text(artist)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                syncVM.removeTrack(syncVM.syncedTracks[index].id)
                            }
                        }
                    }
                    .navigationDestination(isPresented: $navigateToPlayer) {
                        PlayerView()
                    }
                }
            }
            .navigationTitle("Downloads")
        }
    }
}
