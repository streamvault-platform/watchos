import SwiftUI

struct SyncView: View {
    @EnvironmentObject private var syncVM: SyncViewModel

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
                        ForEach(syncVM.syncedTracks) { track in
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
                        .onDelete { indexSet in
                            for index in indexSet {
                                syncVM.removeTrack(syncVM.syncedTracks[index].id)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Downloads")
        }
    }
}
