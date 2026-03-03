import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// {@template vault_kit}
/// VaultKit — Secure credential storage for Flutter.
///
/// Uses
/// **Android Keystore (AES-256-GCM)** on Android and
/// **iOS Keychain** on iOS to encrypt and store sensitive data.
///
/// ## Basic Usage
///
/// ```dart
/// final vault = VaultKit();
///
///  Save a string
/// await vault.save(key: 'auth_token', value: 'eyJhbGci...');
///
///  Save a model
/// await vault.save(
///   key: 'user',
///   value: userModel.toJson(),
/// );
///
///  Fetch a string
/// final token = await vault.fetch<String>(key: 'auth_token');
///
///  Fetch a model
/// final user = await vault.fetch(
///   key: 'user',
///   fromJson: UserModel.fromJson,
/// );
///
///  Check existence
/// final exists = await vault.has('auth_token');
///
///  Delete one key
/// await vault.delete('auth_token');
///
///  Clear all — e.g. on logout
/// await vault.clearAll();
/// ```
/// {@endtemplate}
class _VaultKitInitializer {
  /// {@macro vault_kit}
  _VaultKitInitializer({_VaultKitChannel? channel})
      : _channel = channel ?? const _DefaultVaultKitChannel();

  final _VaultKitChannel _channel;

  // -------------------------------------------------------
  // 💾 Save
  // -------------------------------------------------------

  /// Encrypts and stores [value] under the given [key].
  ///
  /// - On **Android**: encrypted using AES-256-GCM via Android Keystore.
  /// - On **iOS**: stored in the Keychain with
  ///   `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`.
  ///
  /// If a value already exists for [key], it will be overwritten.
  ///
  /// [value] can be any JSON-encodable type: `String`, `int`,
  /// `Map<String, dynamic>`, or any model with a `toJson()` method.
  ///
  /// Throws a [VaultKitException] if encryption or storage fails.
  ///
  /// ```dart
  ///  Save a token
  /// await vault.save(key: 'auth_token', value: 'eyJhbGci...');
  ///
  ///  Save a model
  /// await vault.save(key: 'user', value: userModel.toJson());
  /// ```
  Future<void> save<T>({required String key, required T value}) async {
    await _channel.invokeVoid('save', {'key': key, 'value': jsonEncode(value)});
  }

  // -------------------------------------------------------
  // 📦 Fetch
  // -------------------------------------------------------

  /// Decrypts and returns the value stored under [key], or `null`
  /// if no value exists for that key.
  ///
  /// Use [fromJson] to deserialize into a specific model type.
  /// If [fromJson] is not provided, the raw decoded value is returned.
  ///
  /// Throws a [VaultKitException] if decryption fails.
  /// Throws a [VaultKitParseException] if [fromJson] fails to parse.
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
    final jsonString = await _channel.invokeString('fetch', {'key': key});
    if (jsonString == null) return null;
    try {
      final decoded = jsonDecode(jsonString);
      return fromJson != null ? fromJson(decoded) : decoded as T?;
    } catch (e) {
      throw _VaultKitParseException(key: key, cause: e.toString());
    }
  }

  // -------------------------------------------------------
  // 🗑 Delete
  // -------------------------------------------------------

  /// Deletes the value stored under [key].
  ///
  /// If no value exists for [key], this is a no-op — no error is thrown.
  ///
  /// Throws a [VaultKitException] if deletion fails unexpectedly.
  ///
  /// ```dart
  /// await vault.delete('auth_token');
  /// ```
  Future<void> delete(String key) async {
    await _channel.invokeVoid('delete', {'key': key});
  }

  // -------------------------------------------------------
  // 🧹 Clear All
  // -------------------------------------------------------

  /// Deletes **all** values stored by VaultKit.
  ///
  /// Typically called on logout to wipe all cached credentials.
  ///
  /// Throws a [VaultKitException] if the operation fails.
  ///
  /// ```dart
  /// On logout
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
  /// Does not decrypt the value — only checks for existence.
  ///
  /// ```dart
  /// if (await vault.has('auth_token')) {
  /// Token is stored, proceed with auto-login
  /// }
  /// ```
  Future<bool> has(String key) async {
    return await _channel.invokeBool('has', {'key': key});
  }
}

// -------------------------------------------------------
// 🔌 Channel Abstraction — enables mocking in tests
// -------------------------------------------------------

/// Internal channel abstraction — not part of the public API.
/// Allows [_VaultKitInitializer] to be tested without a real platform channel.
abstract class _VaultKitChannel {
  Future<void> invokeVoid(String method, Map<String, dynamic> args);
  Future<String?> invokeString(String method, Map<String, dynamic> args);
  Future<bool> invokeBool(String method, Map<String, dynamic> args);
}

/// Default implementation using Flutter's [MethodChannel].
class _DefaultVaultKitChannel implements _VaultKitChannel {
  const _DefaultVaultKitChannel();
  static const _channel = MethodChannel('vault_kit_channel');

  @override
  Future<void> invokeVoid(String method, Map<String, dynamic> args) async {
    try {
      await _channel.invokeMethod(method, args);
    } on PlatformException catch (e) {
      throw _VaultKitException(code: e.code, message: e.message);
    }
  }

  @override
  Future<String?> invokeString(String method, Map<String, dynamic> args) async {
    try {
      return await _channel.invokeMethod<String>(method, args);
    } on PlatformException catch (e) {
      throw _VaultKitException(code: e.code, message: e.message);
    }
  }

  @override
  Future<bool> invokeBool(String method, Map<String, dynamic> args) async {
    try {
      return await _channel.invokeMethod<bool>(method, args) ?? false;
    } on PlatformException catch (e) {
      throw _VaultKitException(code: e.code, message: e.message);
    }
  }
}

// -------------------------------------------------------
// ❌ Exceptions
// -------------------------------------------------------

/// Base exception thrown by [VaultKit] when a native operation fails.
///
/// Contains a [code] from the native layer and an optional [message].
///
/// ```dart
/// try {
///   await vault.save(key: 'token', value: 'abc');
/// } on VaultKitException catch (e) {
///   print(e.code);    // e.g. ENCRYPT_FAILED
///   print(e.message); // e.g. Encryption failed: ...
/// }
/// ```
class _VaultKitException implements Exception {
  /// Native error code returned from Android or iOS.
  ///
  /// Possible values:
  /// - `INVALID_ARGUMENT` — key or value is null or empty
  /// - `ENCRYPT_FAILED`   — encryption or Keychain save failed
  /// - `DECRYPT_FAILED`   — decryption or Keychain load failed
  /// - `DELETE_FAILED`    — failed to delete a specific key
  /// - `CLEAR_FAILED`     — failed to clear all keys
  final String code;

  /// Human-readable error message from the native layer.
  final String? message;

  /// Creates a [VaultKitException] with the given [code] and [message].
  const _VaultKitException({required this.code, this.message});

  @override
  String toString() => 'VaultKitException($code): $message';
}

/// Thrown by [VaultKit.fetch] when [fromJson] fails to parse
/// the stored value into the expected type [T].
///
/// ```dart
/// try {
///   final user = await vault.fetch(
///     key: 'user',
///     fromJson: UserModel.fromJson,
///   );
/// } on VaultKitParseException catch (e) {
///   print(e.key);   // 'user'
///   print(e.cause); // underlying parse error
/// }
/// ```
class _VaultKitParseException implements Exception {
  /// The key whose value failed to parse.
  final String key;

  /// The underlying error that caused the parse failure.
  final String cause;

  /// Creates a [_VaultKitParseException] for the given [key] and [cause].
  const _VaultKitParseException({required this.key, required this.cause});

  @override
  String toString() =>
      'VaultKitParseException: Failed to parse value for key "$key". Cause: $cause';
}

/// {@template vault_kit_adapter}
/// A generic high-level adapter over [VaultKit] that handles
/// JSON encoding/decoding automatically.
///
/// [VaultKit] is the recommended way to interact with [VaultKit]
/// in your application. It wraps all operations with proper error handling
/// and returns [Either<Failure, T>] for clean functional error propagation.
///
/// ## Setup
///
/// Instantiate once and inject via your DI container:
///
/// ```dart
/// final adapter = VaultKitAdapter();
///
/// or inject a custom VaultKit instance
/// final adapter = VaultKitAdapter(vault: VaultKit(channel: myMockChannel));
/// ```
///
/// ## Usage
///
/// ```dart
/// Save a string
/// await adapter.save(key: 'auth_token', value: 'eyJhbGci...');
///
/// Save a model
/// await adapter.save(key: 'user', value: userModel.toJson());
///
/// Fetch a string
/// final result = await adapter.fetch<String>(key: 'auth_token');
/// result.fold(
///   (failure) => print(failure.message),
///   (token)   => print(token),
/// );
///
/// Fetch a model
/// final userResult = await adapter.fetch(
///   key: 'user',
///   fromJson: UserModel.fromJson,
/// );
///
/// Delete one key
/// await adapter.delete('auth_token');
///
/// Clear all — on logout
/// await adapter.clearAll();
/// ```
/// {@endtemplate}
class VaultKit {
  /// {@macro vault_kit_adapter}
  VaultKit({_VaultKitInitializer? vault})
      : _vault = vault ?? _VaultKitInitializer();

  final _VaultKitInitializer _vault;

  // -------------------------------------------------------
  // 🔒 Private Helpers
  // -------------------------------------------------------

  /// Encodes [object] to a JSON string using [encode] and stores it
  /// under [key] in the vault.
  ///
  /// Throws a [VaultKitException] if the native save operation fails.
  Future<void> _setObject<T>(
    String key,
    T object,
    String Function(T) encode,
  ) async {
    final jsonString = encode(object);
    await _vault.save(key: key, value: jsonString);
  }

  /// Retrieves the JSON string stored under [key] and decodes it
  /// using [decode].
  ///
  /// Returns `null` if no value is stored for [key].
  /// Throws a [VaultKitParseException] if [decode] fails.
  Future<T?> _getObject<T>(
    String key,
    T Function(dynamic) decode,
  ) async {
    final jsonString = await _vault.fetch<String>(key: key);
    if (jsonString == null) return null;
    final jsonMap = jsonDecode(jsonString);
    return decode(jsonMap);
  }

  // -------------------------------------------------------
  // 💾 Save
  // -------------------------------------------------------

  /// Encrypts and stores [value] under [key].
  ///
  /// [value] can be any JSON-encodable type:
  /// - Primitives: `String`, `int`, `double`, `bool`
  /// - Collections: `Map<String, dynamic>`, `List`
  /// - Models: any object with a `toJson()` method
  ///
  /// If a value already exists for [key], it will be **overwritten**.
  ///
  /// Returns [Right(null)] on success.
  /// Returns [Left(Failure)] if:
  /// - The native encryption fails → `[ENCRYPT_FAILED]`
  /// - The value cannot be JSON-encoded → `Unexpected error`
  ///
  /// ```dart
  /// Save a token
  /// final result = await adapter.save(
  ///   key: 'auth_token',
  ///   value: 'eyJhbGci...',
  /// );
  ///
  /// Save a model
  /// final result = await adapter.save(
  ///   key: 'user',
  ///   value: userModel.toJson(),
  /// );
  ///
  /// result.fold(
  ///   (failure) => print('Save failed: ${failure.message}'),
  ///   (_)       => print('Saved successfully'),
  /// );
  /// ```
  Future<Either<Failure, void>> save<T>({
    required String key,
    required T value,
  }) async {
    try {
      await _setObject<T>(key, value, (p) => jsonEncode(p));
      return const Right(null);
    } on _VaultKitException catch (e) {
      return Left(
          Failure(message: '[${e.code}] ${e.message ?? 'Encryption failed'}'));
    } catch (e) {
      return Left(Failure(message: 'Unexpected error while saving "$key": $e'));
    }
  }

  // -------------------------------------------------------
  // 📦 Fetch
  // -------------------------------------------------------

  /// Decrypts and returns the value stored under [key], or `null`
  /// if no value exists for that key.
  ///
  /// Use [fromJson] to deserialize into a specific model type [T].
  /// If [fromJson] is not provided, the raw decoded value is returned.
  ///
  /// Returns [Right(T?)] on success — value is `null` if key not found.
  /// Returns [Left(Failure)] if:
  /// - The native decryption fails → `[DECRYPT_FAILED]`
  /// - [fromJson] fails to parse the stored value → `Parse error`
  /// - Any unexpected error occurs
  ///
  /// ```dart
  /// Fetch a string
  /// final result = await adapter.fetch<String>(key: 'auth_token');
  /// result.fold(
  ///   (failure) => print(failure.message),
  ///   (token)   => print(token),
  /// );
  ///
  /// Fetch a model
  /// final result = await adapter.fetch(
  ///   key: 'user',
  ///   fromJson: UserModel.fromJson,
  /// );
  /// result.fold(
  ///   (failure) => print(failure.message),
  ///   (user)    => print(user?.name),
  /// );
  /// ```
  Future<Either<Failure, T?>> fetch<T>({
    required String key,
    T Function(dynamic)? fromJson,
  }) async {
    try {
      final result = await _getObject<T>(key, fromJson ?? (p) => p as T);
      return Right(result);
    } on _VaultKitParseException catch (e) {
      return Left(
        Failure(message: 'Parse error for key "${e.key}": ${e.cause}'),
      );
    } on _VaultKitException catch (e) {
      return Left(
        Failure(message: '[${e.code}] ${e.message ?? 'Decryption failed'}'),
      );
    } catch (e) {
      return Left(
          Failure(message: 'Unexpected error while fetching "$key": $e'));
    }
  }

  // -------------------------------------------------------
  // 🗑 Delete
  // -------------------------------------------------------

  /// Deletes the value stored under [key].
  ///
  /// If no value exists for [key], this is a no-op — no error is returned.
  ///
  /// Returns [Right(null)] on success.
  /// Returns [Left(Failure)] if the native delete operation fails.
  ///
  /// ```dart
  /// Delete only the token — other keys remain untouched
  /// final result = await adapter.delete('auth_token');
  /// result.fold(
  ///   (failure) => print('Delete failed: ${failure.message}'),
  ///   (_)       => print('Token deleted'),
  /// );
  /// ```
  Future<Either<Failure, void>> delete(String key) async {
    try {
      await _vault.delete(key);
      return const Right(null);
    } on _VaultKitException catch (e) {
      return Left(
        Failure(message: '[${e.code}] ${e.message ?? 'Delete failed'}'),
      );
    } catch (e) {
      return Left(
          Failure(message: 'Unexpected error while deleting "$key": $e'));
    }
  }

  // -------------------------------------------------------
  // 🧹 Clear All
  // -------------------------------------------------------

  /// Deletes **all** values stored by VaultKit.
  ///
  /// Typically called during logout to wipe all cached credentials,
  /// tokens, and user data in a single atomic operation.
  ///
  /// Returns [Right(null)] on success.
  /// Returns [Left(Failure)] if the native clear operation fails.
  ///
  /// ```dart
  /// On logout — wipe everything
  /// final result = await adapter.clearAll();
  /// result.fold(
  ///   (failure) => print('Clear failed: ${failure.message}'),
  ///   (_)       => print('All credentials cleared'),
  /// );
  /// ```
  Future<Either<Failure, void>> clearAll() async {
    try {
      await _vault.clearAll();
      return const Right(null);
    } on _VaultKitException catch (e) {
      return Left(
        Failure(message: '[${e.code}] ${e.message ?? 'Clear failed'}'),
      );
    } catch (e) {
      return Left(Failure(message: 'Unexpected error during clearAll: $e'));
    }
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
  /// if (await adapter.has('auth_token')) {
  ///   // Token exists — proceed with auto-login
  /// }
  /// ```
  Future<bool> has(String key) async {
    try {
      return await _vault.has(key);
    } catch (e) {
      debugPrint('VaultKitAdapter.has() failed for key "$key": $e');
      return false;
    }
  }
}

// -------------------------------------------------------
// 🔴 Failure
// -------------------------------------------------------

/// Represents a failure returned by [VaultKit] operations.
///
/// Contains a human-readable [message] describing what went wrong,
/// including the native error code when available.
///
/// ```dart
/// result.fold(
///   (failure) => print(failure.message), // e.g. [DECRYPT_FAILED] Decryption failed
///   (value)   => print(value),
/// );
/// ```
class Failure {
  /// Human-readable error message.
  ///
  /// Format for native errors: `[ERROR_CODE] description`
  /// Format for parse errors: `Parse error for key "key": cause`
  /// Format for unexpected errors: `Unexpected error: description`
  final String message;

  /// Creates a [Failure] with the given [message].
  const Failure({required this.message});

  @override
  String toString() => 'Failure: $message';
}

// -------------------------------------------------------
// 🔀 Either
// -------------------------------------------------------

/// Represents a value of one of two possible types.
///
/// An [Either] is either a [Left] containing a [Failure],
/// or a [Right] containing a success value.
///
/// ```dart
/// final result = await adapter.fetch<String>(key: 'token');
/// result.fold(
///   (failure) => print(failure.message),  // Left — error
///   (token)   => print(token),            // Right — success
/// );
/// ```
sealed class Either<L, R> {
  const Either();

  /// Returns `true` if this is a [Right] value.
  bool get isRight => this is Right<L, R>;

  /// Returns `true` if this is a [Left] value.
  bool get isLeft => this is Left<L, R>;

  /// Applies [onLeft] if this is [Left], or [onRight] if this is [Right].
  T fold<T>(T Function(L) onLeft, T Function(R) onRight);
}

/// Represents the failure case of [Either].
final class Left<L, R> extends Either<L, R> {
  /// The failure value.
  final L value;

  /// Creates a [Left] with the given [value].
  const Left(this.value);

  @override
  T fold<T>(T Function(L) onLeft, T Function(R) onRight) => onLeft(value);

  @override
  String toString() => 'Left($value)';
}

/// Represents the success case of [Either].
final class Right<L, R> extends Either<L, R> {
  /// The success value.
  final R value;

  /// Creates a [Right] with the given [value].
  const Right(this.value);

  @override
  T fold<T>(T Function(L) onLeft, T Function(R) onRight) => onRight(value);

  @override
  String toString() => 'Right($value)';
}
