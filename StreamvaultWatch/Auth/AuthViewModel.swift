import Foundation

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var serverUrlInput: String = ""
    @Published var username: String = ""
    @Published var password: String = ""
    @Published private(set) var isLoading = false
    @Published private(set) var error: String?

    private let tokenRepository: TokenRepository
    private let apiClient: APIClient

    init(tokenRepository: TokenRepository, apiClient: APIClient) {
        self.tokenRepository = tokenRepository
        self.apiClient = apiClient
        self.serverUrlInput = tokenRepository.serverUrl ?? ""
    }

    func login() async {
        let url = serverUrlInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !url.isEmpty, !username.isEmpty, !password.isEmpty else {
            error = "All fields are required"
            return
        }
        isLoading = true
        error = nil
        do {
            let tokens = try await apiClient.login(
                serverUrl: url,
                username: username,
                password: password
            )
            tokenRepository.save(
                serverUrl: url,
                accessToken: tokens.accessToken,
                refreshToken: tokens.refreshToken
            )
        } catch let apiError as APIError {
            error = apiError.errorDescription
        } catch {
            self.error = "Login failed"
        }
        isLoading = false
    }

    func logout() {
        tokenRepository.clearTokens()
        username = ""
        password = ""
        error = nil
    }
}
