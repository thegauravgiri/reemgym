import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Holds the user's own Gemini API key. It stays on this device only: it is
/// never written to Firestore or sent anywhere except to Google with requests.
abstract class KeyStore {
  /// Lets the UI react when a key is added or removed.
  ValueListenable<bool> get hasKey;
  Future<String?> read();
  Future<void> write(String key);
  Future<void> clear();
}

/// Keychain (iOS) / Keystore-encrypted (Android) storage.
class SecureKeyStore implements KeyStore {
  static const _name = 'gemini_api_key';
  final _storage = const FlutterSecureStorage();
  final _hasKey = ValueNotifier(false);
  String? _cached;
  bool _loaded = false;

  @override
  ValueListenable<bool> get hasKey => _hasKey;

  @override
  Future<String?> read() async {
    if (!_loaded) {
      try {
        _cached = await _storage.read(key: _name);
      } catch (e) {
        debugPrint('Reading the saved key failed: $e');
      }
      _loaded = true;
      _hasKey.value = _cached != null;
    }
    return _cached;
  }

  @override
  Future<void> write(String key) async {
    await _storage.write(key: _name, value: key);
    _cached = key;
    _loaded = true;
    _hasKey.value = true;
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _name);
    _cached = null;
    _loaded = true;
    _hasKey.value = false;
  }
}

/// Keeps the key for the current run only; used in tests.
class MemoryKeyStore implements KeyStore {
  final _hasKey = ValueNotifier(false);
  String? _key;

  @override
  ValueListenable<bool> get hasKey => _hasKey;

  @override
  Future<String?> read() async => _key;

  @override
  Future<void> write(String key) async {
    _key = key;
    _hasKey.value = true;
  }

  @override
  Future<void> clear() async {
    _key = null;
    _hasKey.value = false;
  }
}
