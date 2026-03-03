import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

// -------------------------------------------------------
// 🔌 Channel Abstraction — private
// -------------------------------------------------------

abstract class _VaultKitChannel {
  Future<void> invokeVoid(String method, Map<String, dynamic> args);
  Future<String?> invokeString(String method, Map<String, dynamic> args);
  Future<bool> invokeBool(String method, Map<String, dynamic> args);
}

class _DefaultVaultKitChannel implements _VaultKitChannel {
  const _DefaultVaultKitChannel();

  static const _channel = MethodChannel('vault_kit_channel');

  @override
  Future<void> invokeVoid(String method, Map<String, dynamic> args) async {
    await _channel.invokeMethod(method, args);
  }

  @override
  Future<String?> invokeString(String method, Map<String, dynamic> args) async {
    return await _channel.invokeMethod<String>(method, args);
  }

  @override
  Future<bool> invokeBool(String method, Map<String, dynamic> args) async {
    return await _channel.invokeMethod<bool>(method, args) ?? false;
  }
}

// -------------------------------------------------------
// 🔐 VaultKit — the only public API
// -------------------------------------------------------

/// {@template vault_kit}
/// VaultKit — Secure credential storage for Flutter.
///
/// Encrypts and stores sensitive data using native OS security:
/// - 🤖 **Android** — Android Keystore with AES-256-GCM encryption
/// - 🍎 **iOS** — iOS Keychain with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`
///
/// ## Setup
///
/// ```dart
/// final vault = VaultKit();
/// ```
///
/// ## Usage
///
/// ```dart
/// Save a string
/// await vault.save(key: 'auth_token', value: 'eyJhbGci...');
///
/// Save a model
/// await vault.save(key: 'user', value: jsonEncode(userModel.toJson()));
///
/// Fetch a string
/// final token = await vault.fetch<String>(key: 'auth_token');
///
/// Fetch a model
/// final user = await vault.fetch(
///   key: 'user',
///   fromJson: UserModel.fromJson,
/// );
///
/// Check existence
/// if (await vault.has(key: 'auth_token')) { ... }
///
/// Delete one key
/// await vault.delete(key: 'auth_token');
///
/// Clear all on logout
/// await vault.clearAll();
/// ```
/// {@endtemplate}
class VaultKit {
  /// {@macro vault_kit}
  VaultKit() : _channel = const _DefaultVaultKitChannel();

  final _VaultKitChannel _channel;

  // -------------------------------------------------------
  // 🔒 Private Helpers
  // -------------------------------------------------------

  Future<void> _setObject<T>(
    String key,
    T object,
    String Function(T) encode,
  ) async {
    await _channel.invokeVoid('save', {'key': key, 'value': encode(object)});
  }

  Future<T?> _getObject<T>(
    String key,
    T Function(dynamic) decode,
  ) async {
    final jsonString = await _channel.invokeString('fetch', {'key': key});
    if (jsonString == null) return null;
    return decode(jsonDecode(jsonString));
  }

  // -------------------------------------------------------
  // 💾 Save
  // -------------------------------------------------------

  /// Encrypts and stores [value] under [key].
  ///
  /// If a value already exists for [key], it will be **overwritten**.
  ///
  /// Throws [PlatformException] if encryption or storage fails.
  ///
  /// ```dart
  /// await vault.save(key: 'auth_token', value: 'eyJhbGci...');
  /// await vault.save(key: 'user', value: jsonEncode(userModel.toJson()));
  /// ```
  Future<void> save({required String key, required String value}) async {
    await _setObject<String>(key, value, (p) => jsonEncode(p));
  }

  // -------------------------------------------------------
  // 📦 Fetch
  // -------------------------------------------------------

  /// Decrypts and returns the value stored under [key],
  /// or `null` if no value exists for that key.
  ///
  /// Use [fromJson] to automatically deserialize into model type [T].
  ///
  /// Throws [PlatformException] if decryption fails.
  ///
  /// ```dart
  /// Fetch a string
  /// final token = await vault.fetch<String>(key: 'auth_token');
  ///
  /// Fetch a model
  /// final user = await vault.fetch(
  ///   key: 'user',
  ///   fromJson: UserModel.fromJson,
  /// );
  /// ```
  Future<T?> fetch<T>({
    required String key,
    T Function(dynamic)? fromJson,
  }) async {
    return _getObject<T>(key, fromJson ?? (p) => p as T);
  }

  // -------------------------------------------------------
  // 🗑 Delete
  // -------------------------------------------------------

  /// Deletes the value stored under [key].
  ///
  /// If no value exists for [key], this is a no-op — no error is thrown.
  ///
  /// Throws [PlatformException] if deletion fails unexpectedly.
  ///
  /// ```dart
  /// await vault.delete(key: 'auth_token');
  /// ```
  Future<void> delete({required String key}) async {
    await _channel.invokeVoid('delete', {'key': key});
  }

  // -------------------------------------------------------
  // 🧹 Clear All
  // -------------------------------------------------------

  /// Deletes **all** values stored by VaultKit.
  ///
  /// Typically called during logout to wipe all cached credentials.
  ///
  /// Throws [PlatformException] if the operation fails.
  ///
  /// ```dart
  /// await vault.clearAll();
  /// ```
  Future<void> clearAll() async {
    await _channel.invokeVoid('clearAll', {});
  }

  // -------------------------------------------------------
  // 🔍 Has
  // -------------------------------------------------------

  /// Returns `true` if a value exists for [key], `false` otherwise.
  ///
  /// Does **not** decrypt the value — only checks for existence.
  /// Never throws — returns `false` on any failure.
  ///
  /// ```dart
  /// if (await vault.has(key: 'auth_token')) {
  ///   // Token exists — proceed with auto-login
  /// }
  /// ```
  Future<bool> has({required String key}) async {
    try {
      return await _channel.invokeBool('has', {'key': key});
    } catch (e) {
      debugPrint('VaultKit.has() failed for key "$key": $e');
      return false;
    }
  }
}
