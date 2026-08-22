import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Abstraction over secure credential storage (e.g. the TMDB API key).
abstract class SecureStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// Backed by the platform keychain/keystore via `flutter_secure_storage`.
class KeychainSecureStorage implements SecureStorage {
  KeychainSecureStorage([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) => _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}
