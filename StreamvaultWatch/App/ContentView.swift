import SwiftUI

/// Auth gate. Reads from Keychain on init — no network call required.
struct ContentView: View {
    @EnvironmentObject var tokenRepository: TokenRepository
    let apiClient: APIClient

    var body: some View {
        if tokenRepository.isAuthenticated {
            NavigationStack {
                ArtistListView()
            }
        } else {
            AuthView(tokenRepository: tokenRepository, apiClient: apiClient)
        }
    }
}
