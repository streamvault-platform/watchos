import Foundation
import Security

protocol KeychainStorage {
    func read(account: String) -> String?
    func write(account: String, value: String)
    func delete(account: String)
}

final class SystemKeychain: KeychainStorage {
    private let service: String
    private let accessGroup: String?

    init(service: String, accessGroup: String? = nil) {
        self.service = service
        self.accessGroup = accessGroup
    }

    func read(account: String) -> String? {
        var query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlock,
        ]
        if let group = accessGroup { query[kSecAttrAccessGroup] = group }
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data
        else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func write(account: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }
        delete(account: account)
        var item: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlock,
        ]
        if let group = accessGroup { item[kSecAttrAccessGroup] = group }
        SecItemAdd(item as CFDictionary, nil)
    }

    func delete(account: String) {
        var query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
        ]
        if let group = accessGroup { query[kSecAttrAccessGroup] = group }
        SecItemDelete(query as CFDictionary)
    }
}
