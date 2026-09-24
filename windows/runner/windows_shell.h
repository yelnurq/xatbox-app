#ifndef RUNNER_WINDOWS_SHELL_H_
#define RUNNER_WINDOWS_SHELL_H_

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <windows.h>

#include <memory>
#include <optional>
#include <string>
#include <vector>

// WM_COPYDATA tag of a second XatBox.exe handing its command line (a mailto:
// link, a jump list task) to the running window before it exits.
constexpr ULONG_PTR kXatBoxArgumentsMessage = 0x58415442;  // 'XATB'

// Explicit AppUserModelID of the process. It matches the Start menu shortcut
// (windows/installer/xatbox.iss) and LocalNotificationHub.windowsAppUserModelId,
// so the taskbar button, the pinned icon, the jump list and the toasts are one app.
constexpr wchar_t kXatBoxAppUserModelId[] = L"Xatbox.XatBox.Desktop";

// The "xatbox/desktop" channel: the Windows shell integrations the plugins do
// not cover (lib/core/platform/desktop_shell.dart is the Dart side;
// macos/Runner/MainFlutterWindow.swift is the macOS one).
//
// Dart -> native: ready, setBadge, flash, setJumpList, readClipboardFiles,
// getLaunchAtLogin, setLaunchAtLogin, setGlobalHotkeys, startFileDrag,
// quickLook, spellCheck, idleSeconds.
// Native -> Dart: arguments (a second launch, a global hotkey), drop (files
// from Explorer), session (the screen was locked or unlocked).
class WindowsShell {
 public:
  WindowsShell(flutter::BinaryMessenger* messenger, HWND window);
  ~WindowsShell();

  // Started with --hidden (sign-in to Windows): the window stays in the tray.
  static bool LaunchedHidden();

  WindowsShell(const WindowsShell&) = delete;
  WindowsShell& operator=(const WindowsShell&) = delete;

  // Top-level window messages; a value when the message was handled.
  std::optional<LRESULT> HandleMessage(HWND hwnd, UINT message, WPARAM wparam,
                                       LPARAM lparam);

 private:
  using Channel = flutter::MethodChannel<flutter::EncodableValue>;
  using Result = flutter::MethodResult<flutter::EncodableValue>;

  void HandleMethodCall(const flutter::MethodCall<flutter::EncodableValue>& call,
                        std::unique_ptr<Result> result);

  // Arguments of this launch or of a later one (WM_COPYDATA). Queued until
  // Dart says it is ready, so none is lost while the app starts.
  void DeliverArguments(std::vector<std::string> arguments);

  void SetBadge(const std::vector<uint8_t>& bgra, int width, int height,
                const std::wstring& description);
  void ClearBadge();
  void ApplyBadge();
  void Flash();
  bool SetJumpList(const std::vector<std::pair<std::wstring, std::wstring>>& tasks);
  std::vector<std::string> ReadClipboardFiles(const std::wstring& directory);
  bool SetGlobalHotkeys(bool enabled);
  bool StartFileDrag(const std::vector<std::wstring>& paths);
  void ShowWindowFromHotkey();

  std::unique_ptr<Channel> channel_;
  HWND window_;
  UINT taskbar_created_message_;
  bool dart_ready_ = false;
  std::vector<std::vector<std::string>> pending_arguments_;
  HICON badge_ = nullptr;
  std::wstring badge_description_;
  bool hotkeys_ = false;
};

#endif  // RUNNER_WINDOWS_SHELL_H_
