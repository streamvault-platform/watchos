import SwiftUI

@main
struct StreamvaultWatchApp: App {
    @StateObject private var tokenRepository: TokenRepository
    @StateObject private var libraryViewModel: LibraryViewModel

    init() {
        let repo = TokenRepository()
        #if DEBUG
        DebugConfigLoader.apply(to: repo)
        #endif
        let client = APIClient(tokenRepository: repo)
        _tokenRepository = StateObject(wrappedValue: repo)
        _libraryViewModel = StateObject(wrappedValue: LibraryViewModel(apiClient: client))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(tokenRepository)
                .environmentObject(libraryViewModel)
        }
    }
}
