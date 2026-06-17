import Foundation

enum APIError: LocalizedError, Equatable {
    case unauthorized
    case httpError(Int)
    case decodingError(Error)
    case networkError(Error)
    case invalidURL

    var errorDescription: String? {
        switch self {
        case .unauthorized: return "Invalid credentials"
        case .httpError(let code): return "Server error (\(code))"
        case .decodingError: return "Unexpected server response"
        case .networkError: return "Check your Wi-Fi connection"
        case .invalidURL: return "Invalid server URL"
        }
    }

    static func == (lhs: APIError, rhs: APIError) -> Bool {
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

final class APIClient {
    private let tokenRepository: TokenRepository
    private let performDataTask: (URLRequest) async throws -> (Data, URLResponse)
    private let session: URLSession

    init(tokenRepository: TokenRepository, session: URLSession = .shared) {
        self.tokenRepository = tokenRepository
        self.session = session
        self.performDataTask = { try await session.data(for: $0) }
    }

    init(tokenRepository: TokenRepository, dataTask: @escaping (URLRequest) async throws -> (Data, URLResponse)) {
        self.tokenRepository = tokenRepository
        self.session = .shared
        self.performDataTask = dataTask
    }

    func get<T: Decodable>(_ path: String) async throws -> T {
        let request = try buildRequest(path: path, method: "GET")
        return try await perform(request)
    }

    func post<B: Encodable, T: Decodable>(_ path: String, body: B) async throws -> T {
        var request = try buildRequest(path: path, method: "POST")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        return try await perform(request)
    }

    func requestSync(deviceId: String, trackIds: [String]) async throws -> SyncStatusResponse {
        try await post("/api/sync/request", body: SyncRequest(deviceId: deviceId, trackIds: trackIds))
    }

    func watchSyncWebSocketURL(deviceId: String) throws -> URL {
        guard let base = tokenRepository.serverUrl,
              let baseURL = URL(string: base),
              let token = tokenRepository.accessToken
        else { throw APIError.invalidURL }

        let wsScheme = baseURL.scheme == "https" ? "wss" : "ws"
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw APIError.invalidURL
        }
        components.scheme = wsScheme
        components.path = "/ws/watch-sync/\(deviceId)"
        components.queryItems = [URLQueryItem(name: "token", value: token)]
        guard let url = components.url else { throw APIError.invalidURL }
        return url
    }

    // MARK: - Private

    private func buildRequest(path: String, method: String) throws -> URLRequest {
        guard let base = tokenRepository.serverUrl,
              let url = URL(string: "\(base)\(path)")
        else { throw APIError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = method
        if let token = tokenRepository.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    private func perform<T: Decodable>(_ request: URLRequest) async throws -> T {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await performDataTask(request)
        } catch {
            throw APIError.networkError(error)
        }
        if let http = response as? HTTPURLResponse {
            if http.statusCode == 401 { throw APIError.unauthorized }
            guard (200..<300).contains(http.statusCode) else {
                throw APIError.httpError(http.statusCode)
            }
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }
}
