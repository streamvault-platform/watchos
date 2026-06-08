import Foundation

/// Stores JWT tokens via an injectable KeychainStorage and server URL in UserDefaults.
/// Reads synchronously on init — no network call ever made here.
final class TokenRepository: ObservableObject {
    @Published private(set) var isAuthenticated = false
    @Published private(set) var serverUrl: String?
    @Published private(set) var accessToken: String?
    @Published private(set) var refreshToken: String?

    private let keychain: KeychainStorage
    private let userDefaults: UserDefaults

    init(
        keychain: KeychainStorage = SystemKeychain(
            service: "io.streamvault.watch",
            accessGroup: "group.io.streamvault"
        ),
        userDefaults: UserDefaults = UserDefaults(suiteName: "group.io.streamvault") ?? .standard
    ) {
        self.keychain = keychain
        self.userDefaults = userDefaults
        serverUrl = userDefaults.string(forKey: "serverUrl")
        accessToken = keychain.read(account: "accessToken")
        refreshToken = keychain.read(account: "refreshToken")
        isAuthenticated = accessToken != nil
    }

    func save(serverUrl: String, accessToken: String, refreshToken: String) {
        self.serverUrl = serverUrl
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        isAuthenticated = true
        userDefaults.set(serverUrl, forKey: "serverUrl")
        keychain.write(account: "accessToken", value: accessToken)
        keychain.write(account: "refreshToken", value: refreshToken)
    }

    func clearTokens() {
        accessToken = nil
        refreshToken = nil
        isAuthenticated = false
        keychain.delete(account: "accessToken")
        keychain.delete(account: "refreshToken")
    }
}
