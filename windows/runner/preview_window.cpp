#include "preview_window.h"

#include <shlwapi.h>
#include <shobjidl.h>
#include <wrl/client.h>

using Microsoft::WRL::ComPtr;

namespace {

constexpr wchar_t kPreviewClass[] = L"XATBOX_PREVIEW_WINDOW";
// The shell extension key of preview handlers.
constexpr wchar_t kPreviewHandlerKey[] = L"{8895b1c6-b41f-4c1c-a562-0d564250836f}";

struct PreviewState {
  ComPtr<IPreviewHandler> handler;
};

LRESULT CALLBACK PreviewProc(HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam) {
  auto* state = reinterpret_cast<PreviewState*>(::GetWindowLongPtrW(hwnd, GWLP_USERDATA));
  switch (message) {
    case WM_SIZE:
      if (state != nullptr && state->handler) {
        RECT rect;
        ::GetClientRect(hwnd, &rect);
        state->handler->SetRect(&rect);
      }
      return 0;
    case WM_SETFOCUS:
      if (state != nullptr && state->handler) state->handler->SetFocus();
      return 0;
    case WM_KEYDOWN:
      // Space closes it again, as in Finder; Esc too.
      if (wparam == VK_ESCAPE || wparam == VK_SPACE) {
        ::DestroyWindow(hwnd);
        return 0;
      }
      break;
    case WM_DESTROY:
      if (state != nullptr) {
        if (state->handler) state->handler->Unload();
        delete state;
        ::SetWindowLongPtrW(hwnd, GWLP_USERDATA, 0);
      }
      return 0;
  }
  return ::DefWindowProcW(hwnd, message, wparam, lparam);
}

void RegisterPreviewClass() {
  static bool registered = false;
  if (registered) return;
  WNDCLASSW window_class = {};
  window_class.lpfnWndProc = PreviewProc;
  window_class.hInstance = ::GetModuleHandleW(nullptr);
  window_class.hCursor = ::LoadCursorW(nullptr, IDC_ARROW);
  window_class.hbrBackground = reinterpret_cast<HBRUSH>(COLOR_WINDOW + 1);
  window_class.lpszClassName = kPreviewClass;
  window_class.hIcon = ::LoadIconW(window_class.hInstance, MAKEINTRESOURCEW(101));
  ::RegisterClassW(&window_class);
  registered = true;
}

// The preview handler of the file's type, initialised with the file.
ComPtr<IPreviewHandler> HandlerFor(const std::wstring& path) {
  const wchar_t* extension = ::PathFindExtensionW(path.c_str());
  if (extension == nullptr || *extension == L'\0') return nullptr;
  wchar_t clsid_text[64];
  DWORD length = ARRAYSIZE(clsid_text);
  if (FAILED(::AssocQueryStringW(ASSOCF_INIT_DEFAULTTOSTAR, ASSOCSTR_SHELLEXTENSION, extension,
                                 kPreviewHandlerKey, clsid_text, &length))) {
    return nullptr;
  }
  CLSID clsid;
  if (FAILED(::CLSIDFromString(clsid_text, &clsid))) return nullptr;
  ComPtr<IPreviewHandler> handler;
  if (FAILED(::CoCreateInstance(clsid, nullptr, CLSCTX_LOCAL_SERVER | CLSCTX_INPROC_SERVER,
                                IID_PPV_ARGS(&handler)))) {
    return nullptr;
  }
  ComPtr<IInitializeWithFile> with_file;
  if (SUCCEEDED(handler.As(&with_file))) {
    if (SUCCEEDED(with_file->Initialize(path.c_str(), STGM_READ))) return handler;
  }
  ComPtr<IInitializeWithStream> with_stream;
  if (SUCCEEDED(handler.As(&with_stream))) {
    ComPtr<IStream> stream;
    if (SUCCEEDED(::SHCreateStreamOnFileEx(path.c_str(), STGM_READ | STGM_SHARE_DENY_WRITE, 0,
                                           FALSE, nullptr, &stream)) &&
        SUCCEEDED(with_stream->Initialize(stream.Get(), STGM_READ))) {
      return handler;
    }
  }
  ComPtr<IInitializeWithItem> with_item;
  if (SUCCEEDED(handler.As(&with_item))) {
    ComPtr<IShellItem> item;
    if (SUCCEEDED(::SHCreateItemFromParsingName(path.c_str(), nullptr, IID_PPV_ARGS(&item))) &&
        SUCCEEDED(with_item->Initialize(item.Get(), STGM_READ))) {
      return handler;
    }
  }
  return nullptr;
}

}  // namespace

bool ShowPreviewWindow(HWND owner, const std::wstring& path) {
  ComPtr<IPreviewHandler> handler = HandlerFor(path);
  if (!handler) return false;
  RegisterPreviewClass();

  // 70% of the owner's monitor, centred on the owner window.
  RECT owner_rect = {};
  ::GetWindowRect(owner, &owner_rect);
  MONITORINFO monitor = {};
  monitor.cbSize = sizeof(monitor);
  ::GetMonitorInfoW(::MonitorFromWindow(owner, MONITOR_DEFAULTTONEAREST), &monitor);
  const RECT& work = monitor.rcWork;
  const int width = (work.right - work.left) * 7 / 10;
  const int height = (work.bottom - work.top) * 8 / 10;
  const int x = owner_rect.left + ((owner_rect.right - owner_rect.left) - width) / 2;
  const int y = owner_rect.top + ((owner_rect.bottom - owner_rect.top) - height) / 2;

  const wchar_t* name = ::PathFindFileNameW(path.c_str());
  HWND window = ::CreateWindowExW(0, kPreviewClass, name, WS_OVERLAPPEDWINDOW, x, y, width, height,
                                  owner, nullptr, ::GetModuleHandleW(nullptr), nullptr);
  if (window == nullptr) return false;
  auto* state = new PreviewState{handler};
  ::SetWindowLongPtrW(window, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(state));
  ::ShowWindow(window, SW_SHOW);
  RECT rect;
  ::GetClientRect(window, &rect);
  if (FAILED(handler->SetWindow(window, &rect)) || FAILED(handler->DoPreview())) {
    ::DestroyWindow(window);
    return false;
  }
  ::SetForegroundWindow(window);
  return true;
}
