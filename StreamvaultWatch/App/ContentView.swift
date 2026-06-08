import SwiftUI

/// Auth gate. Reads from shared App Group storage on init — no network call required.
struct ContentView: View {
    @EnvironmentObject var tokenRepository: TokenRepository

    var body: some View {
        if tokenRepository.isAuthenticated {
            NavigationStack {
                ArtistListView()
            }
        } else {
            WaitingForPhoneView()
        }
    }
}
