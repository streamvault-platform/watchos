import XCTest
@testable import StreamvaultWatch

final class APIClientTests: XCTestCase {
    private var keychain: InMemoryKeychain!
    private var tokenRepository: TokenRepository!
    private var client: APIClient!
    private var requestHandler: ((URLRequest) throws -> (Data, URLResponse))?

    override func setUp() {
        super.setUp()
        keychain = InMemoryKeychain()
        tokenRepository = TokenRepository(
            keychain: keychain,
            userDefaults: UserDefaults(suiteName: UUID().uuidString)!
        )
        requestHandler = nil
        client = APIClient(tokenRepository: tokenRepository) { [weak self] request in
            guard let handler = self?.requestHandler else { throw URLError(.unknown) }
            return try handler(request)
        }
    }

    // MARK: - Request shape

    func test_login_sendsPostToCorrectURL() async throws {
        var captured: URLRequest?
        requestHandler = { req in
            captured = req
            return try self.successResponse(for: req, body: TokenResponse(accessToken: "a", refreshToken: "r"))
        }

        _ = try await client.login(serverUrl: "http://localhost:8080", username: "alice", password: "s3cr3t")

        XCTAssertEqual(captured?.url?.absoluteString, "http://localhost:8080/api/auth/login")
        XCTAssertEqual(captured?.httpMethod, "POST")
        XCTAssertEqual(captured?.value(forHTTPHeaderField: "Content-Type"), "application/json")
    }

    func test_login_encodesCredentialsInBody() async throws {
        var capturedBody: Data?
        requestHandler = { req in
            capturedBody = req.httpBody
            return try self.successResponse(for: req, body: TokenResponse(accessToken: "a", refreshToken: "r"))
        }

        _ = try await client.login(serverUrl: "http://localhost:8080", username: "alice", password: "s3cr3t")

        let decoded = try XCTUnwrap(capturedBody.flatMap { try? JSONDecoder().decode(LoginRequest.self, from: $0) })
        XCTAssertEqual(decoded.username, "alice")
        XCTAssertEqual(decoded.password, "s3cr3t")
    }

    // MARK: - Response decoding

    func test_login_decodesTokenResponse() async throws {
        requestHandler = { req in
            try self.successResponse(for: req, body: TokenResponse(accessToken: "access", refreshToken: "refresh"))
        }

        let result = try await client.login(serverUrl: "http://localhost:8080", username: "u", password: "p")

        XCTAssertEqual(result.accessToken, "access")
        XCTAssertEqual(result.refreshToken, "refresh")
    }

    // MARK: - Error handling

    func test_login_throws_unauthorized_on401() async {
        requestHandler = { req in
            let http = HTTPURLResponse(url: req.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
            return (Data(), http)
        }

        await assertThrows(APIError.unauthorized) {
            _ = try await self.client.login(serverUrl: "http://localhost:8080", username: "u", password: "p")
        }
    }

    func test_login_throws_httpError_on500() async {
        requestHandler = { req in
            let http = HTTPURLResponse(url: req.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (Data(), http)
        }

        await assertThrows(APIError.httpError(500)) {
            _ = try await self.client.login(serverUrl: "http://localhost:8080", username: "u", password: "p")
        }
    }

    func test_login_throws_networkError_onConnectionFailure() async {
        requestHandler = { _ in throw URLError(.notConnectedToInternet) }

        do {
            _ = try await client.login(serverUrl: "http://localhost:8080", username: "u", password: "p")
            XCTFail("Expected APIError.networkError")
        } catch APIError.networkError {
            // expected
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func test_login_throws_invalidURL_forMalformedServerUrl() async {
        await assertThrows(APIError.invalidURL) {
            _ = try await self.client.login(serverUrl: "not a url ://", username: "u", password: "p")
        }
    }

    // MARK: - Helpers

    private func successResponse<T: Encodable>(for request: URLRequest, body: T) throws -> (Data, URLResponse) {
        let data = try JSONEncoder().encode(body)
        let http = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        return (data, http)
    }

    private func assertThrows<E: Error & Equatable>(_ expected: E, block: () async throws -> Void) async {
        do {
            try await block()
            XCTFail("Expected \(expected) to be thrown")
        } catch let error as E {
            XCTAssertEqual(error, expected)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

// APIError needs Equatable for assertThrows
extension APIError: Equatable {
    public static func == (lhs: APIError, rhs: APIError) -> Bool {
        switch (lhs, rhs) {
        case (.unauthorized, .unauthorized): return true
        case (.invalidURL, .invalidURL): return true
        case (.httpError(let a), .httpError(let b)): return a == b
        case (.networkError, .networkError): return true
        case (.decodingError, .decodingError): return true
        default: return false
        }
    }
}
