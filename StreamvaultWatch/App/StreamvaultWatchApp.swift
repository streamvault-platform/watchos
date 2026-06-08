import SwiftUI

@main
struct StreamvaultWatchApp: App {
    @StateObject private var tokenRepository: TokenRepository
    private let apiClient: APIClient

    init() {
        let repo = TokenRepository()
        _tokenRepository = StateObject(wrappedValue: repo)
        apiClient = APIClient(tokenRepository: repo)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(tokenRepository)
        }
    }
}
