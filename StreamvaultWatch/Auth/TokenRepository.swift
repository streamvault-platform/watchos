import Foundation

final class TokenRepository: ObservableObject {
    // TODO: Keychain-backed JWT storage
    @Published private(set) var isAuthenticated = false
    @Published private(set) var serverUrl: String?
    @Published private(set) var accessToken: String?
    @Published private(set) var refreshToken: String?
}
