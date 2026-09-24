import CallKit
import CryptoKit
import Flutter
import PushKit
import Security
import UIKit
import UserNotifications
import flutter_callkit_incoming

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, PKPushRegistryDelegate {
  private var voipRegistry: PKPushRegistry?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Incoming calls when the app is closed: VoIP push (PushKit) → CallKit.
    let registry = PKPushRegistry(queue: DispatchQueue.main)
    registry.delegate = self
    registry.desiredPushTypes = [.voIP]
    voipRegistry = registry
    // Receive notification responses first (flutter_local_notifications and
    // firebase_messaging forward the ones they do not own back here).
    UNUserNotificationCenter.current().delegate = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // MARK: Chat notification actions

  /// «Ответить» / «Прочитано» under a chat banner (APNs category
  /// XATBOX_CHAT_MESSAGE, registered from Dart in local_notification_hub.dart).
  /// Answered here, without starting Flutter: the session token and the Chat
  /// Service URL come from the keychain (token_storage.dart,
  /// ios_native_config.dart). Everything else goes to the plugins as before.
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let action = response.actionIdentifier
    guard response.notification.request.content.categoryIdentifier == Self.chatCategory,
      action == Self.chatReplyAction || action == Self.chatMarkReadAction
    else {
      super.userNotificationCenter(center, didReceive: response, withCompletionHandler: completionHandler)
      return
    }
    guard let request = Self.chatActionRequest(response) else {
      completionHandler()
      return
    }
    let app = UIApplication.shared
    var task = UIBackgroundTaskIdentifier.invalid
    task = app.beginBackgroundTask {
      app.endBackgroundTask(task)
      task = .invalid
    }
    URLSession.shared.dataTask(with: request) { _, urlResponse, _ in
      let status = (urlResponse as? HTTPURLResponse)?.statusCode ?? 0
      let ok = (200..<300).contains(status)
      DispatchQueue.main.async {
        if ok && action == Self.chatMarkReadAction {
          center.removeDeliveredNotifications(withIdentifiers: [response.notification.request.identifier])
        }
        if !ok && action == Self.chatReplyAction {
          Self.showReplyFailed(center, threadId: response.notification.request.content.threadIdentifier)
        }
        completionHandler()
        if task != .invalid {
          app.endBackgroundTask(task)
          task = .invalid
        }
      }
    }.resume()
  }

  static let chatCategory = "XATBOX_CHAT_MESSAGE"
  static let chatReplyAction = "chat_reply"
  static let chatMarkReadAction = "chat_mark_read"

  /// POST /chats/{id}/messages or POST /messages/{id}/read; nil when signed
  /// out, not configured or the notification lacks the ids.
  static func chatActionRequest(_ response: UNNotificationResponse) -> URLRequest? {
    let info = response.notification.request.content.userInfo
    guard var base = keychainString("xatbox.chat_base_url"),
      let token = keychainString("xatbox.session_token"), !token.isEmpty
    else { return nil }
    while base.hasSuffix("/") { base.removeLast() }
    func segment(_ key: String) -> String? {
      guard let v = info[key] as? String, !v.isEmpty else { return nil }
      return v.addingPercentEncoding(withAllowedCharacters: .alphanumerics.union(CharacterSet(charactersIn: "-_.")))
    }
    var request: URLRequest
    if response.actionIdentifier == chatReplyAction {
      let text = (response as? UNTextInputNotificationResponse)?.userText
        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
      guard !text.isEmpty, let conversation = segment("conversation_id"),
        let url = URL(string: "\(base)/chats/\(conversation)/messages"),
        let body = try? JSONSerialization.data(withJSONObject: [
          "client_message_id": UUID().uuidString.lowercased(),
          "type": "text",
          "body": text,
        ])
      else { return nil }
      request = URLRequest(url: url)
      request.httpBody = body
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    } else {
      guard let message = segment("message_id"),
        let url = URL(string: "\(base)/messages/\(message)/read")
      else { return nil }
      request = URLRequest(url: url)
    }
    request.httpMethod = "POST"
    request.timeoutInterval = 15
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    return request
  }

  private static func showReplyFailed(_ center: UNUserNotificationCenter, threadId: String) {
    let content = UNMutableNotificationContent()
    content.title = "XatBox"
    content.body = "Ответ не отправлен"
    content.threadIdentifier = threadId
    center.add(UNNotificationRequest(identifier: "reply-failed-\(threadId)", content: content, trigger: nil))
  }

  /// A flutter_secure_storage item of this app's private keychain.
  static func keychainString(_ account: String) -> String? {
    let query: [CFString: Any] = [
      kSecClass: kSecClassGenericPassword,
      kSecAttrService: "flutter_secure_storage_service",
      kSecAttrAccount: account,
      kSecReturnData: true,
      kSecMatchLimit: kSecMatchLimitOne,
    ]
    var item: CFTypeRef?
    guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
      let stored = item as? Foundation.Data
    else { return nil }
    return String(data: stored, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  // MARK: PushKit

  func pushRegistry(_ registry: PKPushRegistry, didUpdate credentials: PKPushCredentials, for type: PKPushType) {
    let token = credentials.token.map { String(format: "%02x", $0) }.joined()
    // Picked up by Dart (getDevicePushTokenVoIP) and registered as kind=voip.
    SwiftFlutterCallkitIncomingPlugin.sharedInstance?.setDevicePushTokenVoIP(token)
  }

  func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
    SwiftFlutterCallkitIncomingPlugin.sharedInstance?.setDevicePushTokenVoIP("")
  }

  /// iOS requires reporting a VoIP push to CallKit immediately, otherwise it
  /// terminates the app and stops delivering VoIP pushes. The call id is the
  /// CallKit UUID, so a call already shown from the WebSocket is not doubled.
  func pushRegistry(
    _ registry: PKPushRegistry,
    didReceiveIncomingPushWith payload: PKPushPayload,
    for type: PKPushType,
    completion: @escaping () -> Void
  ) {
    guard type == .voIP else {
      completion()
      return
    }
    var dict = payload.dictionaryPayload
    if let nested = dict["data"] as? [AnyHashable: Any] {
      dict.merge(nested) { _, new in new }
    }
    let callId = dict["call_id"] as? String ?? UUID().uuidString
    // Encrypted VoIP push (wire format v1, backend/platform/push/apns.go):
    // only call_id / call_type and caller_name "XatBox" travel in clear. The
    // real name is decrypted here, in the app process, synchronously (PushKit
    // allows no network before reporting the call). Failure keeps "XatBox".
    var callerName = dict["caller_name"] as? String ?? "XatBox"
    if let enc = dict["enc"] as? String, let clear = Self.decryptPush(enc) {
      if let name = clear["title"] ?? clear["caller_name"], !name.isEmpty {
        callerName = name
      }
    }
    let isVideo = (dict["call_type"] as? String) == "video"
    let data = flutter_callkit_incoming.Data(id: callId, nameCaller: callerName, handle: callerName, type: isVideo ? 1 : 0)
    data.appName = "XatBox"
    data.duration = 45000
    data.supportsVideo = true
    data.extra = ["call_id": callId]
    guard let plugin = SwiftFlutterCallkitIncomingPlugin.sharedInstance else {
      // Plugin not registered yet: still report to CallKit (required), the
      // Dart side recovers the call through GET /calls/active on start.
      let provider = CXProvider(configuration: CXProviderConfiguration())
      let update = CXCallUpdate()
      update.remoteHandle = CXHandle(type: .generic, value: callerName)
      update.hasVideo = isVideo
      provider.reportNewIncomingCall(with: UUID(uuidString: callId) ?? UUID(), update: update) { _ in completion() }
      return
    }
    plugin.showCallkitIncoming(data, fromPushKit: true) {
      completion()
    }
  }

  // MARK: Encrypted push payloads

  /// AES-256-GCM, nonce(12) || ciphertext || tag(16), AAD "xatbox-push-v1";
  /// the key is this install's push key written by push_crypto.dart. No
  /// access group in the query: the app can read its own and the App Group
  /// keychain (ios/NotificationService/NotificationService.swift has the
  /// same code for the extension).
  static func decryptPush(_ enc: String) -> [String: String]? {
    guard let text = keychainString("xatbox.push_key"),
      let key = Foundation.Data(base64Encoded: text),
      key.count == 32,
      let raw = Foundation.Data(base64Encoded: enc), raw.count > 28
    else { return nil }
    do {
      let box = try AES.GCM.SealedBox(
        nonce: try AES.GCM.Nonce(data: raw.prefix(12)),
        ciphertext: raw.dropFirst(12).dropLast(16),
        tag: raw.suffix(16)
      )
      let plain = try AES.GCM.open(box, using: SymmetricKey(data: key), authenticating: Foundation.Data("xatbox-push-v1".utf8))
      guard let object = try JSONSerialization.jsonObject(with: plain) as? [String: Any] else { return nil }
      return object.compactMapValues { $0 as? String }
    } catch {
      return nil
    }
  }
}
