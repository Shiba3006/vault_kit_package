<p align="center">
  <img src="https://raw.githubusercontent.com/Shiba3006/vault_kit/main/assets/vault_kit_logo.png" height="120" alt="VaultKit Logo"/>
</p>

<h1 align="center">vault_kit</h1>

<p align="center">
  <strong>Secure credential storage for Flutter — zero dependencies, native encryption.</strong>
</p>

<p align="center">
  <a href="https://pub.dev/packages/vault_kit">
    <img src="https://img.shields.io/pub/v/vault_kit.svg" alt="pub version"/>
  </a>
  <a href="https://pub.dev/packages/vault_kit">
    <img src="https://img.shields.io/pub/likes/vault_kit" alt="pub likes"/>
  </a>
  <a href="https://pub.dev/packages/vault_kit">
    <img src="https://img.shields.io/pub/popularity/vault_kit" alt="pub popularity"/>
  </a>
  <a href="https://pub.dev/packages/vault_kit">
    <img src="https://img.shields.io/pub/points/vault_kit" alt="pub points"/>
  </a>
  <a href="https://opensource.org/licenses/MIT">
    <img src="https://img.shields.io/badge/License-MIT-blue.svg" alt="MIT License"/>
  </a>
</p>

<p align="center">
  <a href="https://pub.dev/packages/vault_kit">pub.dev</a> •
  <a href="https://github.com/Shiba3006/vault_kit">GitHub</a> •
  <a href="https://github.com/Shiba3006/vault_kit/issues">Issues</a>
</p>

---

## Why VaultKit?

Most Flutter apps store sensitive data like **tokens**, **passwords**, and **user credentials** in `SharedPreferences` — plain text, unencrypted, and exposed on rooted or jailbroken devices.

**VaultKit** solves this by encrypting your data at the OS level using battle-tested native security APIs — with a clean, simple Dart API that feels like you're just reading and writing key-value pairs.

---

## Features

- 🔐 **AES-256-GCM encryption** via Android Keystore — unique IV per entry
- 🔑 **iOS Keychain** backed by Secure Enclave — `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`
- 📦 **Generic storage** — store strings, models, or any JSON-encodable type
- 🗑 **Delete a single key** without affecting others
- 🧹 **Clear all** stored data in one call — perfect for logout
- ✅ **Zero third-party dependencies** — native only
- 🧪 **Fully testable** via Flutter's `MethodChannel` mock binding
- 🎯 **Single public API** — only `VaultKit` is exposed

---

## Platform Support

| Platform | Implementation | Min Version |
|----------|---------------|-------------|
| 🤖 Android | Android Keystore — AES-256-GCM | API 23+ |
| 🍎 iOS | iOS Keychain — Secure Enclave | iOS 11+ |

---

## Installation

Add to your `pubspec.yaml`:
```yaml
dependencies:
  vault_kit: ^1.0.0
```

Then run:
```bash
flutter pub get
```

---

## Quick Start
```dart
import 'package:vault_kit/vault_kit.dart';

final vault = VaultKit();

// Save
await vault.save(key: 'auth_token', value: 'eyJhbGci...');

// Fetch
final token = await vault.fetch<String>(key: 'auth_token');

// Delete
await vault.delete(key: 'auth_token');

// Clear all on logout
await vault.clearAll();
```

---

## Usage

### Save a value
```dart
// Save a string
await vault.save(key: 'auth_token', value: 'eyJhbGci...');
```

### Save a model
```dart
// Encode your model to JSON string first
await vault.save(
  key: 'user_credentials',
  value: jsonEncode({
    'username': 'john_doe',
    'password': 'mySecret123',
  }),
);
```

### Fetch a string
```dart
final token = await vault.fetch<String>(key: 'auth_token');

if (token != null) {
  print('Token: $token');
} else {
  print('No token stored');
}
```

### Fetch a model
```dart
final result = await vault.fetch<Map<String, dynamic>>(
  key: 'user_credentials',
  fromJson: (p) => (p is String ? jsonDecode(p) : p) as Map<String, dynamic>,
);

if (result != null) {
  print('Username: ${result['username']}');
  print('Password: ${result['password']}');
}
```

### Check if a key exists
```dart
if (await vault.has(key: 'auth_token')) {
  // Token exists — proceed with auto-login
}
```

### Delete a single key
```dart
// Only removes the token — other stored values remain untouched
await vault.delete(key: 'auth_token');
```

### Clear all on logout
```dart
// Wipes all credentials in one atomic operation
await vault.clearAll();
```

---

## Error Handling

All operations throw a `PlatformException` on failure. Wrap calls in try/catch:
```dart
try {
  await vault.save(key: 'auth_token', value: 'eyJhbGci...');
} on PlatformException catch (e) {
  print('[${e.code}] ${e.message}');
}
```

### Error codes

| Code | Cause |
|------|-------|
| `INVALID_ARGUMENT` | Key or value is null or empty |
| `ENCRYPT_FAILED` | Encryption or Keychain save failed |
| `DECRYPT_FAILED` | Decryption or Keychain load failed |
| `DELETE_FAILED` | Failed to delete a specific key |
| `CLEAR_FAILED` | Failed to clear all keys |

> `has()` never throws — it returns `false` on any failure.

---

## Security Deep Dive

### Android

Data is encrypted using **AES-256-GCM** via the Android Keystore system:

- The encryption key lives inside the **Android Keystore** — it never leaves the secure hardware
- A **unique IV (Initialization Vector)** is generated for every encryption operation, meaning the same value encrypted twice produces completely different ciphertext
- `setUserAuthenticationRequired(false)` — accessible without biometrics, but protected from extraction
- The key is never exposed to your app code — only the encrypted bytes are stored in `SharedPreferences`

### iOS

Data is stored in the **iOS Keychain** using Apple's Security framework:

- Backed by the **Secure Enclave** on supported devices
- `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` — data is only accessible when the device is unlocked and **never transferred** to another device or backed up to iCloud
- Each key is stored as a separate Keychain entry scoped to your app's bundle ID

### Comparison

| | SharedPreferences | VaultKit |
|---|---|---|
| Encryption | ❌ None | ✅ AES-256-GCM / Keychain |
| Rooted devices | ❌ Data exposed | ✅ Protected by Keystore |
| Jailbroken devices | ❌ Data exposed | ✅ Protected by Secure Enclave |
| iCloud backup | ⚠️ Backed up | ✅ Device-only |
| Key isolation | ❌ Plain key-value | ✅ Each entry has unique IV |
| Error handling | ❌ Silent failures | ✅ PlatformException with codes |

---

## Testing

VaultKit is fully testable using Flutter's `MethodChannel` mock binding — no real device or platform needed:
```dart
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vault_kit/vault_kit.dart';

void main() {
  late VaultKit vault;
  final Map<String, String> storage = {};

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    vault = VaultKit();
    storage.clear();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('vault_kit_channel'),
      (MethodCall call) async {
        switch (call.method) {
          case 'save':
            storage[call.arguments['key']] = call.arguments['value'];
            return null;
          case 'fetch':
            return storage[call.arguments['key']];
          case 'delete':
            storage.remove(call.arguments['key']);
            return null;
          case 'clearAll':
            storage.clear();
            return null;
          case 'has':
            return storage.containsKey(call.arguments['key']);
          default:
            return null;
        }
      },
    );
  });

  test('saves and fetches a token', () async {
    await vault.save(key: 'token', value: 'eyJhbGci...');
    final result = await vault.fetch<String>(key: 'token');
    expect(result, equals('eyJhbGci...'));
  });
}
```

Run tests:
```bash
flutter test test/vault_kit_test.dart
```

---

## Example App

A full working example is available in the [`/example`](./example) folder demonstrating:

- Saving and fetching an auth token
- Saving and fetching user credentials (username + password) as JSON
- Deleting individual keys
- Clearing all data to simulate logout
- Live timestamped log output

---

## API Reference
```dart
class VaultKit {
  /// Encrypts and stores [value] under [key].
  Future<void> save({required String key, required String value});

  /// Decrypts and returns the value for [key], or null if not found.
  Future<T?> fetch<T>({required String key, T Function(dynamic)? fromJson});

  /// Deletes the value stored under [key].
  Future<void> delete({required String key});

  /// Deletes all values stored by VaultKit.
  Future<void> clearAll();

  /// Returns true if a value exists for [key], false otherwise.
  Future<bool> has({required String key});
}
```

---

## Contributing

Contributions are welcome! Here's how to get started:

1. Fork the repository
2. Create your branch (`git checkout -b feat/your-feature`)
3. Commit your changes (`git commit -m 'feat: add your feature'`)
4. Push to the branch (`git push origin feat/your-feature`)
5. Open a Pull Request

Please open an [issue](https://github.com/Shiba3006/vault_kit/issues) first for major changes.

---

## Changelog

See [CHANGELOG.md](./CHANGELOG.md) for a list of changes.

---

## License

This project is licensed under the **MIT License** — see [LICENSE](./LICENSE) for details.

---

<p align="center">
  Made with ❤️ for the Flutter community by <a href="https://github.com/Shiba3006">Your Name</a>
</p>