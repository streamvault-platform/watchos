import XCTest
@testable import StreamvaultWatch

@MainActor
final class AuthViewModelTests: XCTestCase {
    private var keychain: InMemoryKeychain!
    private var tokenRepository: TokenRepository!
    private var apiClient: APIClient!
    private var vm: AuthViewModel!

    override func setUp() {
        super.setUp()
        keychain = InMemoryKeychain()
        tokenRepository = TokenRepository(
            keychain: keychain,
            userDefaults: UserDefaults(suiteName: UUID().uuidString)!
        )
        MockURLProtocol.requestHandler = nil
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        apiClient = APIClient(tokenRepository: tokenRepository, session: URLSession(configuration: config))
        vm = AuthViewModel(tokenRepository: tokenRepository, apiClient: apiClient)
    }

    // MARK: - Validation

    func test_login_emptyFields_setsError() async {
        await vm.login()
        XCTAssertEqual(vm.error, "All fields are required")
        XCTAssertFalse(tokenRepository.isAuthenticated)
    }

    func test_login_emptyPassword_setsError() async {
        vm.serverUrlInput = "http://localhost:8080"
        vm.username = "alice"
        await vm.login()
        XCTAssertEqual(vm.error, "All fields are required")
    }

    // MARK: - Success

    func test_login_success_savesTokens() async {
        mockSuccess(accessToken: "at", refreshToken: "rt")
        vm.serverUrlInput = "http://localhost:8080"
        vm.username = "alice"
        vm.password = "s3cr3t"

        await vm.login()

        XCTAssertNil(vm.error)
        XCTAssertTrue(tokenRepository.isAuthenticated)
        XCTAssertEqual(tokenRepository.accessToken, "at")
        XCTAssertEqual(tokenRepository.refreshToken, "rt")
        XCTAssertEqual(tokenRepository.serverUrl, "http://localhost:8080")
    }

    func test_login_success_writesTokensToKeychain() async {
        mockSuccess(accessToken: "at", refreshToken: "rt")
        vm.serverUrlInput = "http://localhost:8080"
        vm.username = "alice"
        vm.password = "s3cr3t"

        await vm.login()

        XCTAssertEqual(keychain.read(account: "accessToken"), "at")
        XCTAssertEqual(keychain.read(account: "refreshToken"), "rt")
    }

    func test_login_success_clearsIsLoading() async {
        mockSuccess(accessToken: "at", refreshToken: "rt")
        vm.serverUrlInput = "http://localhost:8080"
        vm.username = "alice"
        vm.password = "s3cr3t"

        await vm.login()

        XCTAssertFalse(vm.isLoading)
    }

    // MARK: - Errors

    func test_login_unauthorized_setsError() async {
        MockURLProtocol.requestHandler = { request in
            let http = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
            return (http, Data())
        }
        vm.serverUrlInput = "http://localhost:8080"
        vm.username = "alice"
        vm.password = "wrong"

        await vm.login()

        XCTAssertEqual(vm.error, "Invalid credentials")
        XCTAssertFalse(tokenRepository.isAuthenticated)
    }

    func test_login_networkError_setsError() async {
        MockURLProtocol.requestHandler = { _ in throw URLError(.notConnectedToInternet) }
        vm.serverUrlInput = "http://localhost:8080"
        vm.username = "alice"
        vm.password = "s3cr3t"

        await vm.login()

        XCTAssertNotNil(vm.error)
        XCTAssertFalse(tokenRepository.isAuthenticated)
    }

    func test_login_serverError_setsError() async {
        MockURLProtocol.requestHandler = { request in
            let http = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (http, Data())
        }
        vm.serverUrlInput = "http://localhost:8080"
        vm.username = "alice"
        vm.password = "s3cr3t"

        await vm.login()

        XCTAssertNotNil(vm.error)
        XCTAssertFalse(tokenRepository.isAuthenticated)
    }

    // MARK: - Logout

    func test_logout_clearsAuthentication() async {
        mockSuccess(accessToken: "at", refreshToken: "rt")
        vm.serverUrlInput = "http://localhost:8080"
        vm.username = "alice"
        vm.password = "s3cr3t"
        await vm.login()
        XCTAssertTrue(tokenRepository.isAuthenticated)

        vm.logout()

        XCTAssertFalse(tokenRepository.isAuthenticated)
        XCTAssertNil(tokenRepository.accessToken)
        XCTAssertNil(keychain.read(account: "accessToken"))
    }

    func test_logout_clearsFormFields() async {
        vm.username = "alice"
        vm.password = "s3cr3t"

        vm.logout()

        XCTAssertEqual(vm.username, "")
        XCTAssertEqual(vm.password, "")
    }

    // MARK: - Offline

    func test_existingToken_isAuthenticatedWithoutNetworkCall() {
        keychain.write(account: "accessToken", value: "existing-token")
        let offlineRepo = TokenRepository(
            keychain: keychain,
            userDefaults: UserDefaults(suiteName: UUID().uuidString)!
        )
        XCTAssertTrue(offlineRepo.isAuthenticated)
    }

    // MARK: - Helpers

    private func mockSuccess(accessToken: String, refreshToken: String) {
        let response = TokenResponse(accessToken: accessToken, refreshToken: refreshToken)
        MockURLProtocol.requestHandler = { request in
            let data = try JSONEncoder().encode(response)
            let http = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (http, data)
        }
    }
}
