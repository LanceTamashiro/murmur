import CryptoKit
import Foundation
import os.log
import NoteStore

private let logger = Logger(subsystem: "com.unconventionalpsychotherapy.murmur", category: "SessionRecovery")

struct RecoveryData: Codable {
    let text: String
    let language: String
    let startTime: Date
    let savedAt: Date
    let sourceApp: String?
}

@MainActor
final class SessionRecoveryManager {
    private let saveInterval: TimeInterval = 10
    private var saveTask: Task<Void, Never>?

    private static var recoveryFileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let murmurDir = appSupport.appendingPathComponent("Murmur", isDirectory: true)
        try? FileManager.default.createDirectory(at: murmurDir, withIntermediateDirectories: true)
        return murmurDir.appendingPathComponent("session-recovery.enc")
    }

    // MARK: - Encryption Key (Keychain-backed)

    private static let keychainService = "com.unconventionalpsychotherapy.murmur.recovery"
    private static let keychainAccount = "recovery-key"

    private static func getOrCreateKey() -> SymmetricKey {
        // Try to load existing key from Keychain
        if let existingKeyData = loadKeyFromKeychain() {
            return SymmetricKey(data: existingKeyData)
        }
        // Generate a new key and store it
        let key = SymmetricKey(size: .bits256)
        let keyData = key.withUnsafeBytes { Data($0) }
        saveKeyToKeychain(keyData)
        return key
    }

    private static func loadKeyFromKeychain() -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    private static func saveKeyToKeychain(_ keyData: Data) {
        // Delete any existing key first
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        SecItemAdd(addQuery as CFDictionary, nil)
    }

    // MARK: - Periodic Save

    /// Start periodic saves of in-progress transcription.
    func startPeriodicSave(textProvider: @escaping @MainActor () -> (text: String, language: String, sourceApp: String?)?, startTime: Date) {
        stopPeriodicSave()
        logger.info("Starting periodic recovery saves (every \(self.saveInterval)s)")

        saveTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(saveInterval))
                guard !Task.isCancelled else { break }

                if let data = textProvider() {
                    let trimmed = data.text.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { continue }

                    let recovery = RecoveryData(
                        text: data.text,
                        language: data.language,
                        startTime: startTime,
                        savedAt: Date(),
                        sourceApp: data.sourceApp
                    )
                    save(recovery)
                }
            }
        }
    }

    func stopPeriodicSave() {
        saveTask?.cancel()
        saveTask = nil
    }

    /// Clear the recovery file (called after successful save-as-note).
    func clearRecovery() {
        let url = Self.recoveryFileURL
        try? FileManager.default.removeItem(at: url)
        logger.info("Recovery file cleared")
    }

    /// Check for a recovery file on launch. Returns the data if found.
    static func checkForRecovery() -> RecoveryData? {
        let url = recoveryFileURL
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }

        do {
            let encryptedData = try Data(contentsOf: url)
            let key = getOrCreateKey()
            let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
            let decryptedData = try AES.GCM.open(sealedBox, using: key)
            let recovery = try JSONDecoder().decode(RecoveryData.self, from: decryptedData)

            // Ignore recovery files older than 24 hours
            if Date().timeIntervalSince(recovery.savedAt) > 86400 {
                try? FileManager.default.removeItem(at: url)
                logger.info("Stale recovery file removed (>24h old)")
                return nil
            }
            logger.info("Recovery file found (\(recovery.text.count) chars)")
            return recovery
        } catch {
            logger.error("Failed to read recovery file: \(error)")
            try? FileManager.default.removeItem(at: url)
            return nil
        }
    }

    /// Restore recovered text as a new note.
    static func restoreAsNote(recovery: RecoveryData, noteStore: NoteStoreService) -> Bool {
        do {
            let note = try noteStore.createNote(
                bodyMarkdown: recovery.text,
                sourceApp: recovery.sourceApp,
                language: recovery.language
            )
            // Backdate the creation time to the original session start
            note.createdAt = recovery.startTime
            logger.info("Recovered session restored as note (id=\(note.id))")
            // Clean up
            try? FileManager.default.removeItem(at: recoveryFileURL)
            return true
        } catch {
            logger.error("Failed to restore recovered session: \(error)")
            return false
        }
    }

    // MARK: - Private

    private func save(_ recovery: RecoveryData) {
        do {
            let data = try JSONEncoder().encode(recovery)
            let key = Self.getOrCreateKey()
            let sealedBox = try AES.GCM.seal(data, using: key)
            guard let combined = sealedBox.combined else {
                logger.error("Failed to get combined sealed box data")
                return
            }
            try combined.write(to: Self.recoveryFileURL, options: .atomic)
            logger.debug("Recovery save: \(recovery.text.count) chars (encrypted)")
        } catch {
            logger.error("Failed to save recovery data: \(error)")
        }
    }
}
