import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  override func applicationWillFinishLaunching(_ notification: Notification) {
    super.applicationWillFinishLaunching(notification)
    // Started as a login item («Запускать при входе»): the window waits in
    // the menu bar, like the Windows app started with --hidden.
    let event = NSAppleEventManager.shared().currentAppleEvent
    if event?.eventID == AEEventID(kAEOpenApplication),
      event?.paramDescriptor(forKeyword: AEKeyword(keyAEPropData))?.enumCodeValue
        == OSType(keyAELaunchedAsLogInItem)
    {
      DesktopShell.shared.deliver(["--hidden"])
      mainFlutterWindow?.orderOut(nil)
    }
  }

  override func applicationDidFinishLaunching(_ notification: Notification) {
    // Finder → Службы → «Новое письмо XatBox» (NSServices in Info.plist).
    NSApp.servicesProvider = DesktopShell.shared
  }

  /// Files opened with XatBox (.eml, .ics) come here; mailto: and xatbox://
  /// links go to app_links, which takes the URL events itself.
  override func application(_ application: NSApplication, open urls: [URL]) {
    super.application(application, open: urls)
    let files = urls.filter { $0.isFileURL }.map { $0.path }
    if !files.isEmpty {
      DesktopShell.shared.showWindow()
      DesktopShell.shared.deliver(files)
    }
  }

  /// Right click on the Dock icon: the tasks the app set (DesktopShell).
  override func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
    return DesktopShell.shared.dockMenu
  }

  /// A click on the Dock icon brings back the window hidden to the menu bar.
  override func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    if !flag { DesktopShell.shared.showWindow() }
    return true
  }
}
