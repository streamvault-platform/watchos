import XCTest
@testable import StreamvaultWatch

final class TokenRepositoryTests: XCTestCase {
    private var keychain: InMemoryKeychain!
    private var defaults: UserDefaults!
    private var repo: TokenRepository!

    override func setUp() {
        super.setUp()
        keychain = InMemoryKeychain()
        defaults = UserDefaults(suiteName: UUID().uuidString)!
        repo = TokenRepository(keychain: keychain, userDefaults: defaults)
    }

    func test_save_setsIsAuthenticated() {
        repo.save(serverUrl: "http://localhost:8080", accessToken: "at", refreshToken: "rt")
        XCTAssertTrue(repo.isAuthenticated)
        XCTAssertEqual(repo.accessToken, "at")
        XCTAssertEqual(repo.refreshToken, "rt")
        XCTAssertEqual(repo.serverUrl, "http://localhost:8080")
    }

    func test_save_writesTokensToKeychain() {
        repo.save(serverUrl: "http://localhost:8080", accessToken: "at", refreshToken: "rt")
        XCTAssertEqual(keychain.read(account: "accessToken"), "at")
        XCTAssertEqual(keychain.read(account: "refreshToken"), "rt")
    }

    func test_clearTokens_removesAuthentication() {
        repo.save(serverUrl: "http://localhost:8080", accessToken: "at", refreshToken: "rt")
        repo.clearTokens()
        XCTAssertFalse(repo.isAuthenticated)
        XCTAssertNil(repo.accessToken)
        XCTAssertNil(keychain.read(account: "accessToken"))
    }

    func test_existingToken_isAuthenticatedOnInit() {
        keychain.write(account: "accessToken", value: "existing-token")
        let freshRepo = TokenRepository(keychain: keychain, userDefaults: defaults)
        XCTAssertTrue(freshRepo.isAuthenticated)
    }
}
