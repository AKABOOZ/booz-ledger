import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ledger_app/models/webdav_sync_models.dart';

/// Stores WebDAV credentials in platform encrypted storage and keeps only
/// non-sensitive endpoint preferences in SharedPreferences.
class WebDavConfigStore {
  WebDavConfigStore({FlutterSecureStorage? secureStorage})
    : _secureStorage =
          secureStorage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
          );

  static const _localUrlKey = 'webdav_local_url_v2';
  static const _externalUrlKey = 'webdav_external_url_v2';
  static const _autoSelectKey = 'webdav_auto_select_endpoint_v2';
  static const _usernameKey = 'webdav_username_v2';
  static const _passwordKey = 'webdav_password_v2';

  static const _legacyUrlKey = 'webdav_url';
  static const _legacyUsernameKey = 'webdav_username';
  static const _legacyPasswordKey = 'webdav_password';

  final FlutterSecureStorage _secureStorage;

  Future<WebDavConfig> load(SharedPreferences prefs) async {
    final localUrl =
        prefs.getString(_localUrlKey) ?? prefs.getString(_legacyUrlKey) ?? '';
    final externalUrl = prefs.getString(_externalUrlKey) ?? '';
    var username = await _secureStorage.read(key: _usernameKey) ?? '';
    var password = await _secureStorage.read(key: _passwordKey) ?? '';

    // One-time migration from the old plaintext settings. Do not remove old
    // values until both credential writes completed successfully.
    final legacyUsername = prefs.getString(_legacyUsernameKey) ?? '';
    final legacyPassword = prefs.getString(_legacyPasswordKey) ?? '';
    final migratedUrl = !prefs.containsKey(_localUrlKey) && localUrl.isNotEmpty;
    final needsCredentialMigration =
        (username.isEmpty && legacyUsername.isNotEmpty) ||
        (password.isEmpty && legacyPassword.isNotEmpty);
    if (migratedUrl || needsCredentialMigration) {
      if (migratedUrl) {
        await prefs.setString(_localUrlKey, localUrl);
      }
      if (username.isEmpty && legacyUsername.isNotEmpty) {
        await _secureStorage.write(key: _usernameKey, value: legacyUsername);
        username = legacyUsername;
      }
      if (password.isEmpty && legacyPassword.isNotEmpty) {
        await _secureStorage.write(key: _passwordKey, value: legacyPassword);
        password = legacyPassword;
      }
      if (needsCredentialMigration) {
        await prefs.remove(_legacyUsernameKey);
        await prefs.remove(_legacyPasswordKey);
      }
      if (migratedUrl) {
        await prefs.remove(_legacyUrlKey);
      }
    }

    return WebDavConfig(
      localUrl: localUrl,
      externalUrl: externalUrl,
      username: username,
      password: password,
      autoSelectEndpoint: prefs.getBool(_autoSelectKey) ?? true,
    );
  }

  Future<void> save(SharedPreferences prefs, WebDavConfig config) async {
    final localUrl = config.localUrl.trim();
    final externalUrl = config.externalUrl.trim();
    await _secureStorage.write(
      key: _usernameKey,
      value: config.username.trim(),
    );
    await _secureStorage.write(key: _passwordKey, value: config.password);
    if (localUrl.isEmpty) {
      await prefs.remove(_localUrlKey);
    } else {
      await prefs.setString(_localUrlKey, localUrl);
    }
    if (externalUrl.isEmpty) {
      await prefs.remove(_externalUrlKey);
    } else {
      await prefs.setString(_externalUrlKey, externalUrl);
    }
    await prefs.setBool(_autoSelectKey, config.autoSelectEndpoint);
    await prefs.remove(_legacyUrlKey);
    await prefs.remove(_legacyUsernameKey);
    await prefs.remove(_legacyPasswordKey);
  }
}
