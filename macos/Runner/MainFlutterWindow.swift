import Carbon.HIToolbox
import Cocoa
import FlutterMacOS
import Quartz
import ServiceManagement

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    // Flutter inside a container that takes files dropped from Finder.
    self.contentViewController = FileDropViewController(flutter: flutterViewController)
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    DesktopShell.shared.attach(
      messenger: flutterViewController.engine.binaryMessenger, window: self,
      flutterView: flutterViewController.view)

    super.awakeFromNib()
  }

  // Quick Look (space on an attachment): this window hands the panel its files.
  override func acceptsPreviewPanelControl(_ panel: QLPreviewPanel!) -> Bool {
    return true
  }

  override func beginPreviewPanelControl(_ panel: QLPreviewPanel!) {
    panel.dataSource = DesktopShell.shared
  }

  override func endPreviewPanelControl(_ panel: QLPreviewPanel!) {
    panel.dataSource = nil
  }
}

/// Hosts the Flutter view and accepts files dropped anywhere on the window;
/// DesktopShell hands them to Dart with the drop point.
final class FileDropViewController: NSViewController {
  private let flutter: FlutterViewController

  init(flutter: FlutterViewController) {
    self.flutter = flutter
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) is not used")
  }

  override func loadView() {
    let container = FileDropView()
    container.registerForDraggedTypes([.fileURL])
    view = container
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    addChild(flutter)
    flutter.view.frame = view.bounds
    flutter.view.autoresizingMask = [.width, .height]
    view.addSubview(flutter.view)
  }
}

final class FileDropView: NSView {
  private func fileURLs(_ info: NSDraggingInfo) -> [URL] {
    // Our own attachments dragged out of the window are not dropped back in.
    if info.draggingSource as? DesktopShell != nil { return [] }
    let urls = info.draggingPasteboard.readObjects(
      forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true])
    return (urls as? [URL]) ?? []
  }

  override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
    return fileURLs(sender).isEmpty ? [] : .copy
  }

  override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
    return fileURLs(sender).isEmpty ? [] : .copy
  }

  override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
    let urls = fileURLs(sender)
    if urls.isEmpty { return false }
    // Window coordinates (origin bottom left) → top-left physical pixels,
    // as the Windows runner reports them; Dart divides by the pixel ratio.
    let point = convert(sender.draggingLocation, from: nil)
    let y = isFlipped ? point.y : bounds.height - point.y
    let scale = window?.backingScaleFactor ?? 1
    DesktopShell.shared.drop(paths: urls.map { $0.path }, x: point.x * scale, y: y * scale)
    return true
  }
}

/// The "xatbox/desktop" channel on macOS (lib/core/platform/desktop_shell.dart
/// is the Dart side, windows/runner/windows_shell.cpp the Windows one): the
/// Dock badge and bounce, the Dock menu, files dropped and copied in Finder,
/// XatBox as the app for mailto: links, «Запускать при входе», global
/// hotkeys, attachments dragged to Finder, Quick Look, spelling, idle and
/// screen lock, the Services menu and files opened with XatBox.
///
/// Dart -> native: ready, setBadge, flash, setJumpList, readClipboardFiles,
/// setDefaultMailApp, getLaunchAtLogin, setLaunchAtLogin, setGlobalHotkeys,
/// startFileDrag, quickLook, spellCheck, idleSeconds.
/// Native -> Dart: arguments (Dock menu, hotkeys, Services, opened files),
/// drop, session.
final class DesktopShell: NSObject, NSDraggingSource, QLPreviewPanelDataSource {
  static let shared = DesktopShell()

  private var channel: FlutterMethodChannel?
  private var dartReady = false
  private var pending: [[String]] = []
  private var dockTasks: [(title: String, arguments: String)] = []
  private weak var window: NSWindow?
  private weak var flutterView: NSView?
  private var hotKeys: [EventHotKeyRef] = []
  private var hotKeyHandler: EventHandlerRef?
  private var previewItems: [URL] = []

  func attach(messenger: FlutterBinaryMessenger, window: NSWindow, flutterView: NSView) {
    self.window = window
    self.flutterView = flutterView
    let channel = FlutterMethodChannel(name: "xatbox/desktop", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
    self.channel = channel
    let center = DistributedNotificationCenter.default()
    center.addObserver(
      self, selector: #selector(screenLocked),
      name: NSNotification.Name("com.apple.screenIsLocked"), object: nil)
    center.addObserver(
      self, selector: #selector(screenUnlocked),
      name: NSNotification.Name("com.apple.screenIsUnlocked"), object: nil)
  }

  /// Arguments for Dart (jump list switches, files), queued until Dart is ready.
  func deliver(_ arguments: [String]) {
    if arguments.isEmpty { return }
    guard dartReady, let channel = channel else {
      pending.append(arguments)
      return
    }
    channel.invokeMethod("arguments", arguments: arguments)
  }

  func drop(paths: [String], x: CGFloat, y: CGFloat) {
    channel?.invokeMethod("drop", arguments: ["paths": paths, "x": Double(x), "y": Double(y)])
  }

  /// Right click on the Dock icon: «Новое письмо», «Почта»…
  var dockMenu: NSMenu? {
    if dockTasks.isEmpty { return nil }
    let menu = NSMenu()
    for task in dockTasks {
      let item = NSMenuItem(title: task.title, action: #selector(runDockTask(_:)), keyEquivalent: "")
      item.target = self
      item.representedObject = task.arguments
      menu.addItem(item)
    }
    return menu
  }

  @objc private func runDockTask(_ item: NSMenuItem) {
    showWindow()
    if let arguments = item.representedObject as? String { deliver([arguments]) }
  }

  /// Back from the tray or the Dock: the window hidden with «close».
  func showWindow() {
    NSApp.activate(ignoringOtherApps: true)
    window?.makeKeyAndOrderFront(nil)
  }

  @objc private func screenLocked() {
    channel?.invokeMethod("session", arguments: ["locked": true])
  }

  @objc private func screenUnlocked() {
    channel?.invokeMethod("session", arguments: ["locked": false])
  }

  // MARK: Services menu (Finder → Службы → «Новое письмо XatBox»)

  @objc func sendFiles(
    _ pboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString>
  ) {
    let urls = pboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true])
    let paths = ((urls as? [URL]) ?? []).map { $0.path }
    if paths.isEmpty { return }
    showWindow()
    deliver(["--attach"] + paths)
  }

  // MARK: Channel

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "ready":
      dartReady = true
      result(pending)
      pending.removeAll()
    case "setBadge":
      let label = args["label"] as? String
      NSApp.dockTile.badgeLabel = (label?.isEmpty ?? true) ? nil : label
      result(nil)
    case "flash":
      if !NSApp.isActive { _ = NSApp.requestUserAttention(.informationalRequest) }
      result(nil)
    case "setJumpList":
      let tasks = args["tasks"] as? [[String: Any]] ?? []
      dockTasks = tasks.compactMap { task in
        guard let title = task["title"] as? String, let arguments = task["arguments"] as? String else {
          return nil
        }
        return (title: title, arguments: arguments)
      }
      result(true)
    case "readClipboardFiles":
      result(readClipboardFiles(directory: args["directory"] as? String ?? ""))
    case "setDefaultMailApp":
      NSWorkspace.shared.setDefaultApplication(
        at: Bundle.main.bundleURL, toOpenURLsWithScheme: "mailto"
      ) { error in
        DispatchQueue.main.async { result(error == nil) }
      }
    case "getLaunchAtLogin":
      if #available(macOS 13.0, *) {
        result(["enabled": SMAppService.mainApp.status == .enabled, "managed": false])
      } else {
        result(["enabled": false, "managed": true])
      }
    case "setLaunchAtLogin":
      result(setLaunchAtLogin(args["enabled"] as? Bool ?? false))
    case "setGlobalHotkeys":
      result(setGlobalHotkeys(args["enabled"] as? Bool ?? false))
    case "startFileDrag":
      result(startFileDrag(paths: args["paths"] as? [String] ?? []))
    case "quickLook":
      result(quickLook(paths: args["paths"] as? [String] ?? []))
    case "spellCheck":
      result(checkSpelling(args["text"] as? String ?? ""))
    case "idleSeconds":
      let anyInput = CGEventType(rawValue: ~0)!
      result(CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: anyInput))
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// Files copied in Finder, or a picture without text (a screenshot) as PNG.
  private func readClipboardFiles(directory: String) -> [String] {
    let board = NSPasteboard.general
    let urls = board.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true])
    if let files = urls as? [URL], !files.isEmpty { return files.map { $0.path } }
    guard !directory.isEmpty, board.string(forType: .string) == nil,
      let image = NSImage(pasteboard: board), let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:])
    else { return [] }
    let stamp = Int(Date().timeIntervalSince1970 * 1000)
    let path = (directory as NSString).appendingPathComponent("clipboard-\(stamp).png")
    do {
      try png.write(to: URL(fileURLWithPath: path))
      return [path]
    } catch {
      return []
    }
  }

  // MARK: «Запускать при входе» (macOS 13+)

  private func setLaunchAtLogin(_ enabled: Bool) -> Bool {
    guard #available(macOS 13.0, *) else { return false }
    do {
      if enabled {
        try SMAppService.mainApp.register()
      } else {
        try SMAppService.mainApp.unregister()
      }
      return true
    } catch {
      return false
    }
  }

  // MARK: Global hotkeys: ⌃⌥M new message, ⌃⌥X XatBox in front

  private func setGlobalHotkeys(_ enabled: Bool) -> Bool {
    for ref in hotKeys { UnregisterEventHotKey(ref) }
    hotKeys.removeAll()
    if !enabled { return true }
    if hotKeyHandler == nil {
      var spec = EventTypeSpec(
        eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
      InstallEventHandler(
        GetApplicationEventTarget(),
        { _, event, _ -> OSStatus in
          var id = EventHotKeyID()
          GetEventParameter(
            event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil,
            MemoryLayout<EventHotKeyID>.size, nil, &id)
          let hotKey = Int(id.id)
          DispatchQueue.main.async { DesktopShell.shared.hotKeyPressed(hotKey) }
          return noErr
        }, 1, &spec, nil, &hotKeyHandler)
    }
    let modifiers = UInt32(controlKey | optionKey)
    var all = true
    for (key, id) in [(kVK_ANSI_M, 1), (kVK_ANSI_X, 2)] {
      var ref: EventHotKeyRef?
      let hotKeyID = EventHotKeyID(signature: OSType(0x5841_5442), id: UInt32(id))
      let status = RegisterEventHotKey(
        UInt32(key), modifiers, hotKeyID, GetApplicationEventTarget(), 0, &ref)
      if status == noErr, let ref = ref {
        hotKeys.append(ref)
      } else {
        all = false
      }
    }
    return all
  }

  private func hotKeyPressed(_ id: Int) {
    showWindow()
    if id == 1 { deliver(["--compose"]) }
  }

  // MARK: Attachments dragged to Finder

  private func startFileDrag(paths: [String]) -> Bool {
    guard let view = flutterView, let event = NSApp.currentEvent, !paths.isEmpty else { return false }
    let location = view.convert(event.locationInWindow, from: nil)
    let items: [NSDraggingItem] = paths.map { path in
      let url = URL(fileURLWithPath: path)
      let item = NSDraggingItem(pasteboardWriter: url as NSURL)
      let icon = NSWorkspace.shared.icon(forFile: path)
      item.setDraggingFrame(
        NSRect(x: location.x - 16, y: location.y - 16, width: 32, height: 32), contents: icon)
      return item
    }
    view.beginDraggingSession(with: items, event: event, source: self)
    return true
  }

  func draggingSession(
    _ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext
  ) -> NSDragOperation {
    return context == .outsideApplication ? .copy : []
  }

  func draggingSession(
    _ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation
  ) {
    // The drag took the button release: tell Flutter the button is up.
    guard let window = window, let view = flutterView else { return }
    let point = window.convertPoint(fromScreen: screenPoint)
    if let up = NSEvent.mouseEvent(
      with: .leftMouseUp, location: point, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
      windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 0)
    {
      view.mouseUp(with: up)
    }
  }

  // MARK: Quick Look

  private func quickLook(paths: [String]) -> Bool {
    guard !paths.isEmpty, let panel = QLPreviewPanel.shared() else { return false }
    let urls = paths.map { URL(fileURLWithPath: $0) }
    if QLPreviewPanel.sharedPreviewPanelExists() && panel.isVisible && urls == previewItems {
      panel.orderOut(nil)
      return true
    }
    previewItems = urls
    panel.reloadData()
    panel.makeKeyAndOrderFront(nil)
    return true
  }

  func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
    return previewItems.count
  }

  func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
    return previewItems[index] as NSURL
  }

  // MARK: Spelling (the system dictionaries; Kazakh words are left alone)

  private func checkSpelling(_ text: String) -> [[String: Any]] {
    let checker = NSSpellChecker.shared
    checker.automaticallyIdentifiesLanguages = true
    let ns = text as NSString
    var out: [[String: Any]] = []
    var start = 0
    let kazakh = CharacterSet(charactersIn: "әғқңөұүһіӘҒҚҢӨҰҮҺІ")
    while start < ns.length {
      let range = checker.checkSpelling(
        of: text, startingAt: start, language: nil, wrap: false, inSpellDocumentWithTag: 0,
        wordCount: nil)
      if range.location == NSNotFound || range.length == 0 { break }
      let word = ns.substring(with: range)
      if word.rangeOfCharacter(from: kazakh) == nil {
        let guesses =
          checker.guesses(
            forWordRange: range, in: text, language: nil, inSpellDocumentWithTag: 0) ?? []
        out.append([
          "start": range.location, "length": range.length,
          "suggestions": Array(guesses.prefix(5)),
        ])
      }
      start = range.location + range.length
    }
    return out
  }
}
