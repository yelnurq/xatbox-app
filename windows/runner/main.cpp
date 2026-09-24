#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>
#include <shobjidl.h>

#include <cwchar>

#include "flutter_window.h"
#include "utils.h"
#include "windows_shell.h"

namespace {

constexpr const wchar_t kWindowTitle[] = L"XatBox";

// One XatBox per user session: a second launch (Start menu, desktop
// shortcut, a mailto: link, a jump list task) hands its command line to the
// running window and brings it back, also from the tray, instead of opening
// a second client with its own socket and notifications.
bool FocusRunningInstance() {
  HWND existing = ::FindWindow(L"FLUTTER_RUNNER_WIN32_WINDOW", kWindowTitle);
  if (existing == nullptr) return false;
  const wchar_t* command_line = ::GetCommandLineW();
  COPYDATASTRUCT data = {};
  data.dwData = kXatBoxArgumentsMessage;
  data.cbData = static_cast<DWORD>((std::wcslen(command_line) + 1) * sizeof(wchar_t));
  data.lpData = const_cast<wchar_t*>(command_line);
  DWORD_PTR ignored = 0;
  ::SendMessageTimeoutW(existing, WM_COPYDATA, 0, reinterpret_cast<LPARAM>(&data),
                        SMTO_ABORTIFHUNG, 3000, &ignored);
  ::ShowWindow(existing, ::IsIconic(existing) ? SW_RESTORE : SW_SHOW);
  ::SetForegroundWindow(existing);
  return true;
}

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  ::SetCurrentProcessExplicitAppUserModelID(kXatBoxAppUserModelId);
  HANDLE instance_mutex =
      ::CreateMutex(nullptr, TRUE, L"Local\\XatBoxDesktopSingleInstance");
  if (::GetLastError() == ERROR_ALREADY_EXISTS) {
    FocusRunningInstance();
    return EXIT_SUCCESS;
  }

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins. OLE (a superset) for dragging attachments out of the window.
  ::OleInitialize(nullptr);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(kWindowTitle, origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::OleUninitialize();
  if (instance_mutex != nullptr) ::CloseHandle(instance_mutex);
  return EXIT_SUCCESS;
}
