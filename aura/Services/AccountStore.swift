import SwiftUI
import CryptoKit

// ============================================================
// MARK: - LOCAL ACCOUNT STORE (Keychain-lite via UserDefaults)
// ============================================================

/// Simple local account store. For production, replace with
/// Keychain Services or a real backend.
struct AccountStore {

    private static let accountsKey = "aura.accounts"

    struct Account: Codable {
        let email: String
        let passwordHash: String
        let displayName: String
    }

    // MARK: - Public API

    static func accountExists(email: String) -> Bool {
        loadAll().contains { $0.email.lowercased() == email.lowercased() }
    }

    static func createAccount(email: String, password: String, displayName: String) -> Bool {
        guard !accountExists(email: email) else { return false }
        var all = loadAll()
        let hash = sha256(password)
        all.append(Account(email: email.lowercased(),
                           passwordHash: hash,
                           displayName: displayName))
        save(all)
        return true
    }

    static func verifyCredentials(email: String, password: String) -> Account? {
        let hash = sha256(password)
        return loadAll().first {
            $0.email.lowercased() == email.lowercased() && $0.passwordHash == hash
        }
    }

    // MARK: - Persistence

    private static func loadAll() -> [Account] {
        guard let data = UserDefaults.standard.data(forKey: accountsKey),
              let accounts = try? JSONDecoder().decode([Account].self, from: data)
        else { return [] }
        return accounts
    }

    private static func save(_ accounts: [Account]) {
        if let data = try? JSONEncoder().encode(accounts) {
            UserDefaults.standard.set(data, forKey: accountsKey)
        }
    }

    private static func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}
