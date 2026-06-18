import SwiftUI

@main
struct StreamvaultWatchApp: App {
    @StateObject private var tokenRepository: TokenRepository
    @StateObject private var libraryViewModel: LibraryViewModel
    @StateObject private var syncViewModel: SyncViewModel

    init() {
        let repo = TokenRepository()
        #if DEBUG
        DebugConfigLoader.apply(to: repo)
        #endif
        let client = APIClient(tokenRepository: repo)
        let syncManager = SyncManager(apiClient: client)
        _tokenRepository = StateObject(wrappedValue: repo)
        _libraryViewModel = StateObject(wrappedValue: LibraryViewModel(apiClient: client))
        _syncViewModel = StateObject(wrappedValue: SyncViewModel(syncManager: syncManager))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(tokenRepository)
                .environmentObject(libraryViewModel)
                .environmentObject(syncViewModel)
        }
    }
}
