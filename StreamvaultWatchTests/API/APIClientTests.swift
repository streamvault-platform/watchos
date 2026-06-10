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
        tokenRepository.save(
            serverUrl: "http://localhost:8080",
            accessToken: "test-token",
            refreshToken: "test-refresh"
        )
        requestHandler = nil
        client = APIClient(tokenRepository: tokenRepository) { [weak self] request in
            guard let handler = self?.requestHandler else { throw URLError(.unknown) }
            return try handler(request)
        }
    }

    // MARK: - Request shape

    func test_get_sendsRequestToCorrectURL() async throws {
        var captured: URLRequest?
        requestHandler = { req in
            captured = req
            return try self.successResponse(for: req, body: Stub(value: "ok"))
        }

        let _: Stub = try await client.get("/api/tracks")

        XCTAssertEqual(captured?.url?.absoluteString, "http://localhost:8080/api/tracks")
    }

    func test_get_attachesAuthorizationHeader() async throws {
        var captured: URLRequest?
        requestHandler = { req in
            captured = req
            return try self.successResponse(for: req, body: Stub(value: "ok"))
        }

        let _: Stub = try await client.get("/api/tracks")

        XCTAssertEqual(captured?.value(forHTTPHeaderField: "Authorization"), "Bearer test-token")
    }

    // MARK: - Response decoding

    func test_get_decodesResponse() async throws {
        requestHandler = { req in
            try self.successResponse(for: req, body: Stub(value: "hello"))
        }

        let result: Stub = try await client.get("/api/tracks")

        XCTAssertEqual(result.value, "hello")
    }

    // MARK: - Error handling

    func test_get_throws_unauthorized_on401() async {
        requestHandler = { req in
            let http = HTTPURLResponse(url: req.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
            return (Data(), http)
        }

        await assertThrows(APIError.unauthorized) {
            let _: Stub = try await self.client.get("/api/tracks")
        }
    }

    func test_get_throws_httpError_on500() async {
        requestHandler = { req in
            let http = HTTPURLResponse(url: req.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (Data(), http)
        }

        await assertThrows(APIError.httpError(500)) {
            let _: Stub = try await self.client.get("/api/tracks")
        }
    }

    func test_get_throws_networkError_onConnectionFailure() async {
        requestHandler = { _ in throw URLError(.notConnectedToInternet) }

        do {
            let _: Stub = try await client.get("/api/tracks")
            XCTFail("Expected APIError.networkError")
        } catch APIError.networkError {
            // expected
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func test_get_throws_invalidURL_whenServerUrlNotSet() async {
        let emptyRepo = TokenRepository(
            keychain: InMemoryKeychain(),
            userDefaults: UserDefaults(suiteName: UUID().uuidString)!
        )
        let clientWithoutServer = APIClient(tokenRepository: emptyRepo) { _ in
            throw URLError(.unknown)
        }

        await assertThrows(APIError.invalidURL) {
            let _: Stub = try await clientWithoutServer.get("/api/tracks")
        }
    }

    // MARK: - Helpers

    private struct Stub: Codable { let value: String }

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
