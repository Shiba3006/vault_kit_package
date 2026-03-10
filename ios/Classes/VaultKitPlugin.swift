import Flutter
import Foundation
import Security

public class VaultKitPlugin: NSObject, FlutterPlugin {

    private let serviceKey = "vault_kit_storage"

    // -------------------------------------------------------
    // 🔌 Plugin Registration
    // -------------------------------------------------------

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "vault_kit_channel",
            binaryMessenger: registrar.messenger()
        )
        let instance = VaultKitPlugin()

        // 👇 clear Keychain on fresh install
        instance.clearKeychainIfFirstLaunch()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    // -------------------------------------------------------
    // 📡 Method Channel Handler
    // -------------------------------------------------------

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "save":
            guard let args  = call.arguments as? [String: Any],
                  let key   = args["key"] as? String,
                  let value = args["value"] as? String,
                  !key.isEmpty, !value.isEmpty
            else { result(FlutterError(code: "INVALID_ARGUMENT", message: "Key and value required", details: nil)); return }
            do { try save(key: key, value: value); result(true) }
            catch { result(FlutterError(code: "ENCRYPT_FAILED", message: error.localizedDescription, details: nil)) }

        case "fetch":
            guard let args = call.arguments as? [String: Any],
                  let key  = args["key"] as? String, !key.isEmpty
            else { result(FlutterError(code: "INVALID_ARGUMENT", message: "Key required", details: nil)); return }
            do { result(try load(key: key)) }
            catch { result(FlutterError(code: "DECRYPT_FAILED", message: error.localizedDescription, details: nil)) }

        case "delete":
            guard let args = call.arguments as? [String: Any],
                  let key  = args["key"] as? String, !key.isEmpty
            else { result(FlutterError(code: "INVALID_ARGUMENT", message: "Key required", details: nil)); return }
            do { try delete(key: key); result(true) }
            catch { result(FlutterError(code: "DELETE_FAILED", message: error.localizedDescription, details: nil)) }

        case "clearAll":
            do { try clearAll(); result(true) }
            catch { result(FlutterError(code: "CLEAR_FAILED", message: error.localizedDescription, details: nil)) }

        case "has":
            guard let args = call.arguments as? [String: Any],
                  let key  = args["key"] as? String, !key.isEmpty
            else { result(false); return }
            result(has(key: key))

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // -------------------------------------------------------
    // 🔑 Keychain — Save
    // -------------------------------------------------------

    private func save(key: String, value: String) throws {
        guard let data = value.data(using: .utf8) else { throw VaultKitError.encodingFailed }
        SecItemDelete([kSecClass: kSecClassGenericPassword,
                       kSecAttrService: serviceKey,
                       kSecAttrAccount: key] as CFDictionary)
        let status = SecItemAdd([kSecClass:           kSecClassGenericPassword,
                                  kSecAttrService:    serviceKey,
                                  kSecAttrAccount:    key,
                                  kSecValueData:      data,
                                  kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                                  kSecAttrSynchronizable: false] as CFDictionary, nil)
        guard status == errSecSuccess else { throw VaultKitError.saveFailed(status) }
    }

    // -------------------------------------------------------
    // 🔓 Keychain — Load
    // -------------------------------------------------------

    private func load(key: String) throws -> String? {
        var item: CFTypeRef?
        let status = SecItemCopyMatching([kSecClass:       kSecClassGenericPassword,
                                          kSecAttrService: serviceKey,
                                          kSecAttrAccount: key,
                                          kSecReturnData:  true,
                                          kSecMatchLimit:  kSecMatchLimitOne] as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8)
        else { throw VaultKitError.loadFailed(status) }
        return value
    }

    // -------------------------------------------------------
    // 🗑 Keychain — Delete single key
    // -------------------------------------------------------

    private func delete(key: String) throws {
        let status = SecItemDelete([kSecClass:       kSecClassGenericPassword,
                                    kSecAttrService: serviceKey,
                                    kSecAttrAccount: key] as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound
        else { throw VaultKitError.deleteFailed(status) }
    }

    // -------------------------------------------------------
    // 🧹 Keychain — Clear all under this service
    // -------------------------------------------------------

    private func clearAll() throws {
        let status = SecItemDelete([kSecClass:       kSecClassGenericPassword,
                                    kSecAttrService: serviceKey] as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound
        else { throw VaultKitError.deleteFailed(status) }
    }

    // -------------------------------------------------------
    // 🛠 Helpers
    // -------------------------------------------------------

    private func has(key: String) -> Bool {
        SecItemCopyMatching([kSecClass:       kSecClassGenericPassword,
                              kSecAttrService: serviceKey,
                              kSecAttrAccount: key,
                              kSecMatchLimit:  kSecMatchLimitOne] as CFDictionary, nil) == errSecSuccess
    }

    private func clearKeychainIfFirstLaunch() {
        let key = "vault_kit_has_launched"
        let hasLaunched = UserDefaults.standard.bool(forKey: key)
        if !hasLaunched {
            // First launch — clear any stale Keychain data from previous installs
            try? clearAll()
            UserDefaults.standard.set(true, forKey: key)
        }
    }
}

// -------------------------------------------------------
// ❌ Keychain Errors
// -------------------------------------------------------

enum VaultKitError: LocalizedError {
    case encodingFailed
    case loadFailed(OSStatus)
    case saveFailed(OSStatus)
    case deleteFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .encodingFailed:      return "Failed to encode value"
        case .loadFailed(let s):   return "Keychain load failed: \(s)"
        case .saveFailed(let s):   return "Keychain save failed: \(s)"
        case .deleteFailed(let s): return "Keychain delete failed: \(s)"
        }
    }
}