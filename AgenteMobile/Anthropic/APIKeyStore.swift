//
//  APIKeyStore.swift
//  AgenteMobile
//
//  Created by Erick Silva
//

import Foundation
import Observation
import Security

enum APIKeyStoreError: LocalizedError {
    case keychain(OSStatus)

    var errorDescription: String? {
        switch self {
        case .keychain(let status):
            let reason = SecCopyErrorMessageString(status, nil) as String? ?? "status \(status)"
            return "Keychain error: \(reason)"
        }
    }
}

/// Holds the Anthropic API key in the Keychain so it never lives in source code
/// or in the app binary.
///
/// For development, an `ANTHROPIC_API_KEY` environment variable (Xcode scheme →
/// Run → Environment, or `SIMCTL_CHILD_ANTHROPIC_API_KEY` with simctl) takes
/// precedence over the stored key.
@Observable
final class APIKeyStore {
    private(set) var hasKey: Bool = false

    private static let service = Bundle.main.bundleIdentifier ?? "AgenteMobile"
    private static let account = "anthropic-api-key"
    private static let environmentVariable = "ANTHROPIC_API_KEY"

    init() {
        hasKey = currentKey != nil
    }

    /// The key to send with requests, or nil when none is configured.
    var currentKey: String? {
        if let envKey = ProcessInfo.processInfo.environment[Self.environmentVariable],
           !envKey.isEmpty {
            return envKey
        }
        return readKeychain()
    }

    /// True when the key comes from the environment, so the stored one is ignored.
    var isUsingEnvironmentKey: Bool {
        !(ProcessInfo.processInfo.environment[Self.environmentVariable] ?? "").isEmpty
    }

    func save(_ key: String) throws {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        try deleteKeychain()

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: Self.account,
            kSecValueData as String: Data(trimmed.utf8),
            // Stays on this device: excluded from iCloud Keychain and device migration
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw APIKeyStoreError.keychain(status) }

        hasKey = currentKey != nil
    }

    func delete() throws {
        try deleteKeychain()
        hasKey = currentKey != nil
    }

    // MARK: - Keychain

    private func readKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: Self.account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let key = String(data: data, encoding: .utf8),
              !key.isEmpty else { return nil }
        return key
    }

    private func deleteKeychain() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: Self.account
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw APIKeyStoreError.keychain(status)
        }
    }
}
