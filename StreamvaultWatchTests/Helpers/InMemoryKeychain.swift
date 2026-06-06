import Foundation
@testable import StreamvaultWatch

final class InMemoryKeychain: KeychainStorage {
    private(set) var storage: [String: String] = [:]

    func read(account: String) -> String? { storage[account] }
    func write(account: String, value: String) { storage[account] = value }
    func delete(account: String) { storage.removeValue(forKey: account) }
}
