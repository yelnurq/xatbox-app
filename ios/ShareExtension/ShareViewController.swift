import receive_sharing_intent

/// «Поделиться → XatBox» from other apps. The plugin copies the shared items
/// into the App Group container and opens XatBox (`ShareMedia-<bundle id>`
/// URL scheme in Runner/Info.plist); lib/features/chat/presentation/chat_share.dart
/// then asks which chat to send them to — the same flow as on Android.
class ShareViewController: RSIShareViewController {
  // No compose card: the chat picker in the app is the only step.
  override func shouldAutoRedirect() -> Bool {
    true
  }
}
