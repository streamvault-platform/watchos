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
}

final class APIClient {
    private let tokenRepository: TokenRepository
    private let performDataTask: (URLRequest) async throws -> (Data, URLResponse)

    init(tokenRepository: TokenRepository, session: URLSession = .shared) {
        self.tokenRepository = tokenRepository
        self.performDataTask = { try await session.data(for: $0) }
    }

    init(tokenRepository: TokenRepository, dataTask: @escaping (URLRequest) async throws -> (Data, URLResponse)) {
        self.tokenRepository = tokenRepository
        self.performDataTask = dataTask
    }

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
