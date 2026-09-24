import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Where the session token lives. The only implementation used on devices is
/// [SecureTokenStorage] (Android Keystore / iOS Keychain). Never persist the
/// token anywhere else (ТЗ п.24.4, п.24.24).
abstract class TokenStorage {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> clear();
}

class SecureTokenStorage implements TokenStorage {
  SecureTokenStorage({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(),
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock_this_device,
            ),
            // macOS: the login keychain. The data protection keychain needs a
            // keychain-access-groups entitlement, i.e. a build signed with a team id.
            mOptions: MacOsOptions(usesDataProtectionKeychain: false),
          );

  static const _key = 'xatbox.session_token';
  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() async {
    final value = await _storage.read(key: _key);
    if (value == null || value.isEmpty) return null;
    return value;
  }

  @override
  Future<void> write(String token) => _storage.write(key: _key, value: token);

  @override
  Future<void> clear() => _storage.delete(key: _key);
}

/// Test double; never used in production builds.
class InMemoryTokenStorage implements TokenStorage {
  InMemoryTokenStorage([this._token]);
  String? _token;

  @override
  Future<String?> read() async => _token;

  @override
  Future<void> write(String token) async => _token = token;

  @override
  Future<void> clear() async => _token = null;
}
