import SwiftUI
import WidgetKit

// Home screen widget «XatBox» for iOS: the same snapshot as the Android widget
// (lib/features/home_widget/home_widget_snapshot.dart, format v1), written by
// home_widget into the App Group's UserDefaults under "xatbox.widget".
// The widget never goes to the network; taps open xatbox:// links that the
// app routes after its usual sign-in / PIN checks.

private let appGroup = "group.kz.xatbox.xatboxMobile"
private let dataKey = "xatbox.widget"
private let maxChats = 3

struct Snapshot {
  struct Chat: Identifiable {
    let id: String
    let title: String
    let initial: String
    let preview: String
    let unread: Int
    let color: Color?
  }

  struct Event {
    let title: String
    let time: String
    let end: Date
  }

  var signedIn = false
  var hidden = false
  var unread = 0
  var headline = ""
  var accent: Color?
  var accentDark: Color?
  var dayEnd: Date?
  var chats: [Chat] = []
  var events: [Event] = []
  var signInLabel = "Войдите в XatBox"
  var noEventsLabel = "Сегодня событий больше нет"

  static func load() -> Snapshot {
    guard let raw = UserDefaults(suiteName: appGroup)?.string(forKey: dataKey),
      let data = raw.data(using: .utf8),
      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else { return Snapshot() }
    var s = Snapshot()
    let labels = json["labels"] as? [String: Any] ?? [:]
    if let v = labels["signIn"] as? String, !v.isEmpty { s.signInLabel = v }
    if let v = labels["noEvents"] as? String, !v.isEmpty { s.noEventsLabel = v }
    s.signedIn = json["signedIn"] as? Bool ?? false
    guard s.signedIn else { return s }
    s.hidden = json["hidden"] as? Bool ?? false
    s.unread = json["unread"] as? Int ?? 0
    s.headline = json["headline"] as? String ?? ""
    s.accent = Color(hex: json["accent"] as? String)
    s.accentDark = Color(hex: json["accentDark"] as? String)
    if let ms = json["dayEnd"] as? Double, ms > 0 { s.dayEnd = Date(timeIntervalSince1970: ms / 1000) }
    // Hidden content (PIN lock, «Скрывать содержимое»): only the count.
    guard !s.hidden else { return s }
    for c in (json["chats"] as? [[String: Any]] ?? []).prefix(maxChats) {
      s.chats.append(
        Chat(
          id: c["id"] as? String ?? "",
          title: c["title"] as? String ?? "",
          initial: c["initial"] as? String ?? "",
          preview: c["preview"] as? String ?? "",
          unread: c["unread"] as? Int ?? 0,
          color: Color(hex: c["color"] as? String)
        ))
    }
    for e in json["events"] as? [[String: Any]] ?? [] {
      guard let end = e["end"] as? Double else { continue }
      s.events.append(
        Event(
          title: e["title"] as? String ?? "",
          time: e["time"] as? String ?? "",
          end: Date(timeIntervalSince1970: end / 1000)
        ))
    }
    return s
  }

  /// First event of the snapshot's day that has not ended at [now].
  func nextEvent(at now: Date) -> Event? {
    if let dayEnd, dayEnd <= now { return nil }
    return events.first { $0.end > now }
  }
}

struct XatBoxEntry: TimelineEntry {
  let date: Date
  let snapshot: Snapshot
}

struct XatBoxProvider: TimelineProvider {
  func placeholder(in context: Context) -> XatBoxEntry {
    XatBoxEntry(date: Date(), snapshot: Snapshot())
  }

  func getSnapshot(in context: Context, completion: @escaping (XatBoxEntry) -> Void) {
    completion(XatBoxEntry(date: Date(), snapshot: Snapshot.load()))
  }

  /// One entry now and one at every event end / the end of the day, so the
  /// «next meeting» line moves on without the app; the app reloads the
  /// timeline whenever its snapshot changes.
  func getTimeline(in context: Context, completion: @escaping (Timeline<XatBoxEntry>) -> Void) {
    let now = Date()
    let snapshot = Snapshot.load()
    var dates = [now]
    dates += snapshot.events.map(\.end).filter { $0 > now }
    if let dayEnd = snapshot.dayEnd, dayEnd > now { dates.append(dayEnd) }
    let entries = Set(dates).sorted().map { XatBoxEntry(date: $0, snapshot: snapshot) }
    completion(Timeline(entries: entries, policy: .after(now.addingTimeInterval(30 * 60))))
  }
}

struct XatBoxWidgetView: View {
  let entry: XatBoxEntry
  @Environment(\.colorScheme) private var scheme
  @Environment(\.widgetFamily) private var family

  private var s: Snapshot { entry.snapshot }
  private var accent: Color {
    (scheme == .dark ? s.accentDark : s.accent) ?? Color(red: 0.13, green: 0.55, blue: 0.33)
  }

  var body: some View {
    content
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      .widgetURL(URL(string: "xatbox://chat"))
      .containerBackground(for: .widget) { Color(.systemBackground) }
  }

  @ViewBuilder private var content: some View {
    if !s.signedIn {
      VStack(alignment: .leading, spacing: 6) {
        header
        Spacer()
        Text(s.signInLabel).font(.subheadline).foregroundStyle(.secondary)
      }
    } else {
      VStack(alignment: .leading, spacing: 6) {
        header
        Text(s.headline)
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(s.unread > 0 ? accent : .secondary)
          .lineLimit(1)
        if family != .systemSmall {
          ForEach(s.chats.prefix(family == .systemLarge ? maxChats : 2)) { chat in
            chatRow(chat)
          }
        }
        Spacer(minLength: 0)
        if !s.hidden { eventLine }
      }
    }
  }

  private var header: some View {
    HStack(spacing: 6) {
      Image(systemName: "bubble.left.and.bubble.right.fill").foregroundStyle(accent)
      Text("XatBox").font(.headline)
      Spacer()
      if s.unread > 0 && family == .systemSmall {
        badge(s.unread)
      }
    }
  }

  private func chatRow(_ chat: Snapshot.Chat) -> some View {
    Link(destination: URL(string: "xatbox://chat/\(chat.id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? "")")!) {
      HStack(spacing: 8) {
        Circle()
          .fill(chat.color ?? accent)
          .frame(width: 26, height: 26)
          .overlay(Text(chat.initial.isEmpty ? "•" : chat.initial).font(.caption.bold()).foregroundStyle(.white))
        VStack(alignment: .leading, spacing: 0) {
          Text(chat.title).font(.footnote.weight(.medium)).lineLimit(1)
          if !chat.preview.isEmpty {
            Text(chat.preview).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
          }
        }
        Spacer(minLength: 4)
        if chat.unread > 0 { badge(chat.unread) }
      }
    }
  }

  private var eventLine: some View {
    Link(destination: URL(string: "xatbox://calendar")!) {
      HStack(spacing: 6) {
        Image(systemName: "calendar").foregroundStyle(accent)
        if let next = s.nextEvent(at: entry.date) {
          Text(next.time).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
          Text(next.title).font(.caption).lineLimit(1)
        } else {
          Text(s.noEventsLabel).font(.caption).foregroundStyle(.secondary).lineLimit(1)
        }
      }
    }
  }

  private func badge(_ count: Int) -> some View {
    Text(count > 99 ? "99+" : "\(count)")
      .font(.caption2.bold())
      .foregroundStyle(.white)
      .padding(.horizontal, 6)
      .padding(.vertical, 2)
      .background(Capsule().fill(accent))
  }
}

@main
struct XatBoxWidget: Widget {
  /// Must match PluginHomeWidgetBridge.iosWidgetKind (home_widget_service.dart).
  let kind = "XatBoxWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: XatBoxProvider()) { entry in
      XatBoxWidgetView(entry: entry)
    }
    .configurationDisplayName("XatBox")
    .description("Непрочитанные чаты и ближайшая встреча")
    .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
  }
}

extension Color {
  /// "#RRGGBB" from the snapshot; nil when absent or malformed.
  init?(hex: String?) {
    guard var h = hex?.trimmingCharacters(in: .whitespaces), !h.isEmpty else { return nil }
    if h.hasPrefix("#") { h.removeFirst() }
    guard h.count == 6, let v = UInt32(h, radix: 16) else { return nil }
    self.init(
      red: Double((v >> 16) & 0xFF) / 255,
      green: Double((v >> 8) & 0xFF) / 255,
      blue: Double(v & 0xFF) / 255
    )
  }
}
