import Foundation

enum APIError: LocalizedError {
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
}

final class APIClient {
    private let tokenRepository: TokenRepository
    private let session: URLSession

    init(tokenRepository: TokenRepository, session: URLSession = .shared) {
        self.tokenRepository = tokenRepository
        self.session = session
    }

    // MARK: - Auth

    func login(serverUrl: String, username: String, password: String) async throws -> TokenResponse {
        guard let url = URL(string: "\(serverUrl)/api/auth/login") else { throw APIError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(LoginRequest(username: username, password: password))
        return try await perform(request)
    }

    // MARK: - Internals

    func get<T: Decodable>(_ path: String) async throws -> T {
        guard let base = tokenRepository.serverUrl,
              let url = URL(string: "\(base)\(path)")
        else { throw APIError.invalidURL }
        var request = URLRequest(url: url)
        if let token = tokenRepository.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return try await perform(request)
    }

    private func perform<T: Decodable>(_ request: URLRequest) async throws -> T {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
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
