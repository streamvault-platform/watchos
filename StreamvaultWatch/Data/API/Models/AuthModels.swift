import Foundation

struct LoginRequest: Encodable {
    let username: String
    let password: String
}

struct TokenResponse: Codable {
    let accessToken: String
    let refreshToken: String
}
