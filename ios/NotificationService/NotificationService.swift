import CryptoKit
import Foundation
import Security
import UserNotifications

/// Notification Service Extension for encrypted XatBox pushes (wire format v1,
/// backend/platform/push/crypto.go and apns.go).
///
/// The server sends alert pushes with `mutable-content: 1`, a generic alert
/// ("XatBox" / "Новое сообщение") and the custom keys
/// `{"v": "1", "t": "chat"|"call"|"calendar"|"other", "enc": base64(nonce || ciphertext || tag)}`.
/// `enc` is AES-256-GCM (12-byte nonce, 16-byte tag, AAD "xatbox-push-v1") over
/// a JSON object of strings: type, title, body, conversation_id, message_id,
/// sender_name, conversation_title, tag, badge…
///
/// This extension reads the install's push key from the shared keychain
/// (written by the Flutter app, lib/features/chat/data/push_crypto.dart):
///   kSecClass       = kSecClassGenericPassword
///   kSecAttrService = "flutter_secure_storage_service"
///   kSecAttrAccount = "xatbox.push_key"
///   kSecAttrAccessGroup = "group.kz.xatbox.xatboxMobile" (App Group; both the
///   Runner and this extension must have it in "App Groups" AND the keychain
///   may use it because App Group ids are valid keychain access groups)
/// and replaces title/body, sets the thread identifier per conversation and
/// leaves only non-sensitive ids in userInfo, so a tap is routed by the app
/// exactly like an unencrypted push (conversation_id → chat).
///
/// Any failure (no key after sign-out, rotated key, tampering, time budget
/// exceeded) delivers the generic alert: never an error, never plaintext from
/// the wire.
final class NotificationService: UNNotificationServiceExtension {
  static let accessGroup = "group.kz.xatbox.xatboxMobile"
  static let keychainService = "flutter_secure_storage_service"
  static let keychainAccount = "xatbox.push_key"
  static let aad = Data("xatbox-push-v1".utf8)

  /// Ids the app needs to route a tap; names and text never go to userInfo.
  static let routingKeys: Set<String> = [
    "type", "conversation_id", "message_id", "chat_type", "call_id", "call_type",
    "event_id", "occurrence_start", "kind", "link", "deep_link", "mode",
  ]

  private var contentHandler: ((UNNotificationContent) -> Void)?
  private var bestAttempt: UNMutableNotificationContent?

  override func didReceive(
    _ request: UNNotificationRequest,
    withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
  ) {
    self.contentHandler = contentHandler
    guard let content = request.content.mutableCopy() as? UNMutableNotificationContent else {
      contentHandler(request.content)
      return
    }
    bestAttempt = content
    let info = content.userInfo
    guard (info["v"] as? String) == "1", let enc = info["enc"] as? String else {
      contentHandler(content)
      return
    }
    // Whatever happens below, the ciphertext is not kept in the delivered notification.
    var routed: [AnyHashable: Any] = [:]
    if let aps = info["aps"] { routed["aps"] = aps }
    if let t = info["t"] as? String { routed["t"] = t }

    if let key = Self.readPushKey(), let payload = Self.decrypt(enc: enc, key: key) {
      Self.apply(payload, to: content)
      for (k, v) in payload where Self.routingKeys.contains(k) {
        routed[k] = v
      }
    }
    content.userInfo = routed
    contentHandler(content)
  }

  /// iOS is about to kill the extension (≈30 s budget): deliver the generic alert.
  override func serviceExtensionTimeWillExpire() {
    if let handler = contentHandler, let content = bestAttempt {
      if content.userInfo["enc"] != nil {
        var info = content.userInfo
        info.removeValue(forKey: "enc")
        content.userInfo = info
      }
      handler(content)
    }
  }

  // MARK: - Content

  static func apply(_ p: [String: String], to content: UNMutableNotificationContent) {
    if p["silent"] == "1" { return }
    if let title = p["title"], !title.isEmpty {
      content.title = title
    }
    if let body = p["body"], !body.isEmpty {
      content.body = body
    }
    // One thread per conversation (the server also sets aps.thread-id; the
    // decrypted tag wins so older servers group correctly too).
    if let thread = p["conversation_id"] ?? p["tag"], !thread.isEmpty {
      content.threadIdentifier = thread
    }
    // Group chats: `title` is already "Группа · Имя" (server side).
    if let badge = p["badge"], let n = Int(badge) {
      content.badge = NSNumber(value: n)
    }
  }

  // MARK: - Crypto

  static func decrypt(enc: String, key: Data) -> [String: String]? {
    guard key.count == 32, let raw = Data(base64Encoded: enc), raw.count > 12 + 16 else { return nil }
    do {
      let nonce = try AES.GCM.Nonce(data: raw.prefix(12))
      let box = try AES.GCM.SealedBox(
        nonce: nonce,
        ciphertext: raw.dropFirst(12).dropLast(16),
        tag: raw.suffix(16)
      )
      let plain = try AES.GCM.open(box, using: SymmetricKey(data: key), authenticating: aad)
      guard let object = try JSONSerialization.jsonObject(with: plain) as? [String: Any] else { return nil }
      var out: [String: String] = [:]
      for (k, v) in object {
        if let s = v as? String { out[k] = s }
      }
      return out
    } catch {
      return nil
    }
  }

  /// The push key as raw bytes (the keychain item holds its base64 text).
  static func readPushKey() -> Data? {
    for group in [accessGroup, nil] as [String?] {
      var query: [CFString: Any] = [
        kSecClass: kSecClassGenericPassword,
        kSecAttrService: keychainService,
        kSecAttrAccount: keychainAccount,
        kSecReturnData: true,
        kSecMatchLimit: kSecMatchLimitOne,
      ]
      if let group = group { query[kSecAttrAccessGroup] = group }
      var item: CFTypeRef?
      let status = SecItemCopyMatching(query as CFDictionary, &item)
      guard status == errSecSuccess, let data = item as? Data,
        let text = String(data: data, encoding: .utf8),
        let key = Data(base64Encoded: text.trimmingCharacters(in: .whitespacesAndNewlines)),
        key.count == 32
      else { continue }
      return key
    }
    return nil
  }
}
