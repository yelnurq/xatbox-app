import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../api/app_env.dart';

/// Keychain entry with the Chat Service URL for native iOS code: «Ответить» /
/// «Прочитано» under a chat banner are answered by AppDelegate.swift without
/// starting Flutter, and dart-defines are not visible there. Not a secret
/// (the session token stays in its own entry).
const iosChatBaseUrlKey = 'xatbox.chat_base_url';

Future<void> writeIosNativeConfig(
  AppEnv env, {
  FlutterSecureStorage storage = const FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  ),
}) async {
  final url = env.chatBaseUrl.trim();
  if (url.isEmpty) {
    await storage.delete(key: iosChatBaseUrlKey);
  } else if (await storage.read(key: iosChatBaseUrlKey) != url) {
    await storage.write(key: iosChatBaseUrlKey, value: url);
  }
}
