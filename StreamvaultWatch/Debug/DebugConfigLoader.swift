#if DEBUG
import Foundation

enum DebugConfigLoader {
    private struct Config: Decodable {
        let serverUrl: String
        let accessToken: String
        let refreshToken: String
    }

    static func apply(to repo: TokenRepository) {
        guard let url = Bundle.main.url(forResource: "DebugConfig", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let config = try? JSONDecoder().decode(Config.self, from: data),
              !config.accessToken.hasPrefix("YOUR_")
        else { return }

        repo.save(
            serverUrl: config.serverUrl,
            accessToken: config.accessToken,
            refreshToken: config.refreshToken
        )
    }
}
#endif
