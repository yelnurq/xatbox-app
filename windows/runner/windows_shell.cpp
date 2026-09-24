#include "windows_shell.h"

#include <flutter/standard_method_codec.h>
#include <shellapi.h>
#include <shlobj.h>
#include <shobjidl.h>
#include <wincodec.h>
#include <wrl/client.h>
#include <wtsapi32.h>

#include <chrono>
#include <cstring>
#include <utility>

#include "preview_window.h"
#include "spell_check.h"
#include "utils.h"

using flutter::EncodableList;
using flutter::EncodableMap;
using flutter::EncodableValue;
using Microsoft::WRL::ComPtr;

namespace {

// PKEY_Title ({F29F85E0-4FF9-1068-AB91-08002B27B3D9}, 2): the text of a jump
// list task. Defined here so no import library is needed for it.
const PROPERTYKEY kTitleKey = {
    {0xF29F85E0, 0x4FF9, 0x1068, {0xAB, 0x91, 0x08, 0x00, 0x2B, 0x27, 0xB3, 0xD9}},
    2};

std::wstring Utf16FromUtf8(const std::string& utf8) {
  if (utf8.empty()) return std::wstring();
  const int size = static_cast<int>(utf8.size());
  const int length = ::MultiByteToWideChar(CP_UTF8, 0, utf8.data(), size, nullptr, 0);
  if (length <= 0) return std::wstring();
  std::wstring utf16(length, L'\0');
  ::MultiByteToWideChar(CP_UTF8, 0, utf8.data(), size, utf16.data(), length);
  return utf16;
}

// The arguments of a command line without the program name, as UTF-8.
std::vector<std::string> ArgumentsOf(const wchar_t* command_line) {
  std::vector<std::string> arguments;
  int count = 0;
  wchar_t** argv = ::CommandLineToArgvW(command_line, &count);
  if (argv == nullptr) return arguments;
  for (int i = 1; i < count; i++) arguments.push_back(Utf8FromUtf16(argv[i]));
  ::LocalFree(argv);
  return arguments;
}

// The files of a drop or of a copy in Explorer (CF_HDROP).
std::vector<std::string> PathsOf(HDROP drop) {
  std::vector<std::string> paths;
  const UINT count = ::DragQueryFileW(drop, 0xFFFFFFFF, nullptr, 0);
  for (UINT i = 0; i < count; i++) {
    const UINT length = ::DragQueryFileW(drop, i, nullptr, 0);
    if (length == 0) continue;
    std::wstring path(length + 1, L'\0');
    ::DragQueryFileW(drop, i, path.data(), length + 1);
    path.resize(length);
    paths.push_back(Utf8FromUtf16(path.c_str()));
  }
  return paths;
}

constexpr wchar_t kRunKey[] = L"Software\\Microsoft\\Windows\\CurrentVersion\\Run";
constexpr int kHotkeyCompose = 1;
constexpr int kHotkeyShow = 2;

bool RunValueExists(HKEY root) {
  DWORD size = 0;
  return ::RegGetValueW(root, kRunKey, L"XatBox", RRF_RT_REG_SZ, nullptr, nullptr, &size) ==
         ERROR_SUCCESS;
}

// «Запускать при входе»: the user's Run value starts XatBox in the tray.
bool SetLaunchAtLogin(bool enabled) {
  if (!enabled) {
    const LSTATUS status = ::RegDeleteKeyValueW(HKEY_CURRENT_USER, kRunKey, L"XatBox");
    return status == ERROR_SUCCESS || status == ERROR_FILE_NOT_FOUND;
  }
  wchar_t exe[MAX_PATH];
  const DWORD length = ::GetModuleFileNameW(nullptr, exe, MAX_PATH);
  if (length == 0 || length >= MAX_PATH) return false;
  const std::wstring value = L"\"" + std::wstring(exe) + L"\" --hidden";
  return ::RegSetKeyValueW(HKEY_CURRENT_USER, kRunKey, L"XatBox", REG_SZ, value.c_str(),
                           static_cast<DWORD>((value.size() + 1) * sizeof(wchar_t))) ==
         ERROR_SUCCESS;
}

std::string Utf8Of(const std::wstring& value) { return Utf8FromUtf16(value.c_str()); }

EncodableValue ListOf(const std::vector<std::string>& values) {
  EncodableList list;
  for (const auto& value : values) list.push_back(EncodableValue(value));
  return EncodableValue(list);
}

const EncodableValue* Field(const EncodableMap& map, const char* key) {
  const auto it = map.find(EncodableValue(key));
  return it == map.end() ? nullptr : &it->second;
}

std::wstring StringField(const EncodableMap& map, const char* key) {
  const auto* value = Field(map, key);
  const auto* text = value == nullptr ? nullptr : std::get_if<std::string>(value);
  return text == nullptr ? std::wstring() : Utf16FromUtf8(*text);
}

int IntField(const EncodableMap& map, const char* key) {
  const auto* value = Field(map, key);
  if (value == nullptr) return 0;
  if (const auto* narrow = std::get_if<int32_t>(value)) return *narrow;
  if (const auto* wide = std::get_if<int64_t>(value)) return static_cast<int>(*wide);
  return 0;
}

// An icon from top-down, straight-alpha BGRA pixels.
HICON IconFromBgra(const std::vector<uint8_t>& bgra, int width, int height) {
  BITMAPV5HEADER header = {};
  header.bV5Size = sizeof(header);
  header.bV5Width = width;
  header.bV5Height = -height;  // top-down
  header.bV5Planes = 1;
  header.bV5BitCount = 32;
  header.bV5Compression = BI_BITFIELDS;
  header.bV5RedMask = 0x00FF0000;
  header.bV5GreenMask = 0x0000FF00;
  header.bV5BlueMask = 0x000000FF;
  header.bV5AlphaMask = 0xFF000000;
  void* bits = nullptr;
  HDC screen = ::GetDC(nullptr);
  HBITMAP color = ::CreateDIBSection(screen, reinterpret_cast<BITMAPINFO*>(&header),
                                     DIB_RGB_COLORS, &bits, nullptr, 0);
  ::ReleaseDC(nullptr, screen);
  if (color == nullptr || bits == nullptr) return nullptr;
  std::memcpy(bits, bgra.data(), bgra.size());
  // Monochrome rows are WORD aligned; an all-zero mask lets alpha decide.
  std::vector<uint8_t> mask_bits(static_cast<size_t>((width + 15) / 16) * 2 * height, 0);
  HBITMAP mask = ::CreateBitmap(width, height, 1, 1, mask_bits.data());
  ICONINFO info = {};
  info.fIcon = TRUE;
  info.hbmColor = color;
  info.hbmMask = mask;
  HICON icon = ::CreateIconIndirect(&info);
  ::DeleteObject(color);
  if (mask != nullptr) ::DeleteObject(mask);
  return icon;
}

// A clipboard picture (a screenshot) as a PNG file.
bool WritePng(HBITMAP bitmap, const std::wstring& path) {
  ComPtr<IWICImagingFactory> factory;
  if (FAILED(::CoCreateInstance(CLSID_WICImagingFactory, nullptr, CLSCTX_INPROC_SERVER,
                                IID_PPV_ARGS(&factory)))) {
    return false;
  }
  ComPtr<IWICBitmap> source;
  if (FAILED(factory->CreateBitmapFromHBITMAP(bitmap, nullptr, WICBitmapIgnoreAlpha, &source))) {
    return false;
  }
  UINT width = 0;
  UINT height = 0;
  if (FAILED(source->GetSize(&width, &height)) || width == 0 || height == 0) return false;
  ComPtr<IWICStream> stream;
  if (FAILED(factory->CreateStream(&stream)) ||
      FAILED(stream->InitializeFromFilename(path.c_str(), GENERIC_WRITE))) {
    return false;
  }
  ComPtr<IWICBitmapEncoder> encoder;
  if (FAILED(factory->CreateEncoder(GUID_ContainerFormatPng, nullptr, &encoder)) ||
      FAILED(encoder->Initialize(stream.Get(), WICBitmapEncoderNoCache))) {
    return false;
  }
  ComPtr<IWICBitmapFrameEncode> frame;
  if (FAILED(encoder->CreateNewFrame(&frame, nullptr)) || FAILED(frame->Initialize(nullptr))) {
    return false;
  }
  WICPixelFormatGUID format = GUID_WICPixelFormat32bppBGRA;
  return SUCCEEDED(frame->SetSize(width, height)) && SUCCEEDED(frame->SetPixelFormat(&format)) &&
         SUCCEEDED(frame->WriteSource(source.Get(), nullptr)) && SUCCEEDED(frame->Commit()) &&
         SUCCEEDED(encoder->Commit());
}

}  // namespace

WindowsShell::WindowsShell(flutter::BinaryMessenger* messenger, HWND window)
    : channel_(std::make_unique<Channel>(messenger, "xatbox/desktop",
                                         &flutter::StandardMethodCodec::GetInstance())),
      window_(window),
      taskbar_created_message_(::RegisterWindowMessageW(L"TaskbarButtonCreated")) {
  channel_->SetMethodCallHandler([this](const auto& call, auto result) {
    HandleMethodCall(call, std::move(result));
  });
  // Files dropped from Explorer anywhere on the window (WM_DROPFILES).
  ::DragAcceptFiles(window_, TRUE);
  // Lock / unlock of the session: «Отошёл» in chat.
  ::WTSRegisterSessionNotification(window_, NOTIFY_FOR_THIS_SESSION);
  DeliverArguments(ArgumentsOf(::GetCommandLineW()));
}

WindowsShell::~WindowsShell() {
  channel_->SetMethodCallHandler(nullptr);
  ::DragAcceptFiles(window_, FALSE);
  ::WTSUnRegisterSessionNotification(window_);
  SetGlobalHotkeys(false);
  if (badge_ != nullptr) ::DestroyIcon(badge_);
}

bool WindowsShell::LaunchedHidden() {
  for (const auto& argument : ArgumentsOf(::GetCommandLineW())) {
    if (argument == "--hidden") return true;
  }
  return false;
}

std::optional<LRESULT> WindowsShell::HandleMessage(HWND hwnd, UINT message, WPARAM wparam,
                                                   LPARAM lparam) {
  // Explorer restarted, or the button appeared again after hiding to the tray.
  if (message == taskbar_created_message_) {
    ApplyBadge();
    return std::nullopt;
  }
  switch (message) {
    case WM_DROPFILES: {
      HDROP drop = reinterpret_cast<HDROP>(wparam);
      POINT point = {0, 0};
      ::DragQueryPoint(drop, &point);
      const auto paths = PathsOf(drop);
      ::DragFinish(drop);
      if (!paths.empty()) {
        channel_->InvokeMethod(
            "drop", std::make_unique<EncodableValue>(EncodableMap{
                        {EncodableValue("paths"), ListOf(paths)},
                        {EncodableValue("x"), EncodableValue(static_cast<double>(point.x))},
                        {EncodableValue("y"), EncodableValue(static_cast<double>(point.y))},
                    }));
      }
      return 0;
    }
    case WM_HOTKEY:
      if (wparam == kHotkeyCompose || wparam == kHotkeyShow) {
        ShowWindowFromHotkey();
        if (wparam == kHotkeyCompose) DeliverArguments({"--compose"});
        return 0;
      }
      break;
    case WM_WTSSESSION_CHANGE:
      if (wparam == WTS_SESSION_LOCK || wparam == WTS_SESSION_UNLOCK) {
        channel_->InvokeMethod("session", std::make_unique<EncodableValue>(EncodableMap{
                                              {EncodableValue("locked"),
                                               EncodableValue(wparam == WTS_SESSION_LOCK)},
                                          }));
      }
      return 0;
    case WM_COPYDATA: {
      const auto* data = reinterpret_cast<const COPYDATASTRUCT*>(lparam);
      if (data == nullptr || data->dwData != kXatBoxArgumentsMessage || data->lpData == nullptr) {
        break;
      }
      std::wstring command_line(static_cast<const wchar_t*>(data->lpData),
                                data->cbData / sizeof(wchar_t));
      DeliverArguments(ArgumentsOf(command_line.c_str()));
      return TRUE;
    }
  }
  return std::nullopt;
}

void WindowsShell::HandleMethodCall(const flutter::MethodCall<EncodableValue>& call,
                                    std::unique_ptr<Result> result) {
  static const EncodableMap kNoArguments;
  const auto* arguments = std::get_if<EncodableMap>(call.arguments());
  const EncodableMap& map = arguments != nullptr ? *arguments : kNoArguments;
  const std::string& method = call.method_name();
  if (method == "ready") {
    dart_ready_ = true;
    EncodableList launches;
    for (const auto& launch : pending_arguments_) launches.push_back(ListOf(launch));
    pending_arguments_.clear();
    result->Success(EncodableValue(launches));
  } else if (method == "setBadge") {
    const auto* value = Field(map, "bgra");
    const auto* bgra = value == nullptr ? nullptr : std::get_if<std::vector<uint8_t>>(value);
    if (bgra == nullptr) {
      ClearBadge();
    } else {
      SetBadge(*bgra, IntField(map, "width"), IntField(map, "height"),
               StringField(map, "description"));
    }
    result->Success();
  } else if (method == "flash") {
    Flash();
    result->Success();
  } else if (method == "setJumpList") {
    std::vector<std::pair<std::wstring, std::wstring>> tasks;
    const auto* value = Field(map, "tasks");
    if (const auto* list = value == nullptr ? nullptr : std::get_if<EncodableList>(value)) {
      for (const auto& item : *list) {
        if (const auto* task = std::get_if<EncodableMap>(&item)) {
          tasks.emplace_back(StringField(*task, "title"), StringField(*task, "arguments"));
        }
      }
    }
    result->Success(EncodableValue(SetJumpList(tasks)));
  } else if (method == "readClipboardFiles") {
    result->Success(ListOf(ReadClipboardFiles(StringField(map, "directory"))));
  } else if (method == "getLaunchAtLogin") {
    result->Success(EncodableValue(EncodableMap{
        {EncodableValue("enabled"),
         EncodableValue(RunValueExists(HKEY_CURRENT_USER) || RunValueExists(HKEY_LOCAL_MACHINE))},
        // Set for all users by the administrator (/ALLUSERS): not the user's to change.
        {EncodableValue("managed"), EncodableValue(RunValueExists(HKEY_LOCAL_MACHINE))},
    }));
  } else if (method == "setLaunchAtLogin") {
    const auto* value = Field(map, "enabled");
    const auto* enabled = value == nullptr ? nullptr : std::get_if<bool>(value);
    result->Success(EncodableValue(enabled != nullptr && SetLaunchAtLogin(*enabled)));
  } else if (method == "setGlobalHotkeys") {
    const auto* value = Field(map, "enabled");
    const auto* enabled = value == nullptr ? nullptr : std::get_if<bool>(value);
    result->Success(EncodableValue(SetGlobalHotkeys(enabled != nullptr && *enabled)));
  } else if (method == "startFileDrag" || method == "quickLook") {
    std::vector<std::wstring> paths;
    const auto* value = Field(map, "paths");
    if (const auto* list = value == nullptr ? nullptr : std::get_if<EncodableList>(value)) {
      for (const auto& item : *list) {
        if (const auto* path = std::get_if<std::string>(&item)) paths.push_back(Utf16FromUtf8(*path));
      }
    }
    if (method == "startFileDrag") {
      result->Success(EncodableValue(StartFileDrag(paths)));
    } else {
      result->Success(EncodableValue(!paths.empty() && ShowPreviewWindow(window_, paths.front())));
    }
  } else if (method == "spellCheck") {
    EncodableList errors;
    for (const auto& error : CheckSpelling(StringField(map, "text"))) {
      EncodableList suggestions;
      for (const auto& s : error.suggestions) suggestions.push_back(EncodableValue(Utf8Of(s)));
      errors.push_back(EncodableValue(EncodableMap{
          {EncodableValue("start"), EncodableValue(static_cast<int32_t>(error.start))},
          {EncodableValue("length"), EncodableValue(static_cast<int32_t>(error.length))},
          {EncodableValue("suggestions"), EncodableValue(suggestions)},
      }));
    }
    result->Success(EncodableValue(errors));
  } else if (method == "idleSeconds") {
    LASTINPUTINFO input = {};
    input.cbSize = sizeof(input);
    const double idle = ::GetLastInputInfo(&input)
                            ? static_cast<double>(::GetTickCount() - input.dwTime) / 1000.0
                            : 0.0;
    result->Success(EncodableValue(idle));
  } else {
    result->NotImplemented();
  }
}

void WindowsShell::DeliverArguments(std::vector<std::string> arguments) {
  if (arguments.empty()) return;
  if (!dart_ready_) {
    pending_arguments_.push_back(std::move(arguments));
    return;
  }
  channel_->InvokeMethod("arguments", std::make_unique<EncodableValue>(ListOf(arguments)));
}

void WindowsShell::SetBadge(const std::vector<uint8_t>& bgra, int width, int height,
                            const std::wstring& description) {
  if (width <= 0 || height <= 0 || bgra.size() != static_cast<size_t>(width) * height * 4) {
    return;
  }
  HICON icon = IconFromBgra(bgra, width, height);
  if (icon == nullptr) return;
  if (badge_ != nullptr) ::DestroyIcon(badge_);
  badge_ = icon;
  badge_description_ = description;
  ApplyBadge();
}

void WindowsShell::ClearBadge() {
  if (badge_ != nullptr) ::DestroyIcon(badge_);
  badge_ = nullptr;
  badge_description_.clear();
  ApplyBadge();
}

void WindowsShell::ApplyBadge() {
  ComPtr<ITaskbarList3> taskbar;
  if (FAILED(::CoCreateInstance(CLSID_TaskbarList, nullptr, CLSCTX_INPROC_SERVER,
                                IID_PPV_ARGS(&taskbar))) ||
      FAILED(taskbar->HrInit())) {
    return;
  }
  taskbar->SetOverlayIcon(window_, badge_,
                          badge_ == nullptr ? nullptr : badge_description_.c_str());
}

void WindowsShell::Flash() {
  if (::GetForegroundWindow() == window_ || !::IsWindowVisible(window_)) return;
  FLASHWINFO info = {};
  info.cbSize = sizeof(info);
  info.hwnd = window_;
  // Until the window comes to the foreground.
  info.dwFlags = FLASHW_TRAY | FLASHW_TIMERNOFG;
  ::FlashWindowEx(&info);
}

bool WindowsShell::SetJumpList(const std::vector<std::pair<std::wstring, std::wstring>>& tasks) {
  wchar_t exe[MAX_PATH];
  const DWORD length = ::GetModuleFileNameW(nullptr, exe, MAX_PATH);
  if (length == 0 || length >= MAX_PATH) return false;
  ComPtr<ICustomDestinationList> list;
  if (FAILED(::CoCreateInstance(CLSID_DestinationList, nullptr, CLSCTX_INPROC_SERVER,
                                IID_PPV_ARGS(&list)))) {
    return false;
  }
  list->SetAppID(kXatBoxAppUserModelId);
  UINT slots = 0;
  ComPtr<IObjectArray> removed;
  if (FAILED(list->BeginList(&slots, IID_PPV_ARGS(&removed)))) return false;
  ComPtr<IObjectCollection> collection;
  if (FAILED(::CoCreateInstance(CLSID_EnumerableObjectCollection, nullptr, CLSCTX_INPROC_SERVER,
                                IID_PPV_ARGS(&collection)))) {
    list->AbortList();
    return false;
  }
  for (const auto& [title, task_arguments] : tasks) {
    ComPtr<IShellLinkW> link;
    if (FAILED(::CoCreateInstance(CLSID_ShellLink, nullptr, CLSCTX_INPROC_SERVER,
                                  IID_PPV_ARGS(&link)))) {
      continue;
    }
    link->SetPath(exe);
    link->SetArguments(task_arguments.c_str());
    link->SetIconLocation(exe, 0);
    ComPtr<IPropertyStore> store;
    if (FAILED(link.As(&store))) continue;
    PROPVARIANT value;
    ::PropVariantInit(&value);
    const size_t bytes = (title.size() + 1) * sizeof(wchar_t);
    value.pwszVal = static_cast<LPWSTR>(::CoTaskMemAlloc(bytes));
    if (value.pwszVal == nullptr) continue;
    value.vt = VT_LPWSTR;
    std::memcpy(value.pwszVal, title.c_str(), bytes);
    const bool titled = SUCCEEDED(store->SetValue(kTitleKey, value)) && SUCCEEDED(store->Commit());
    ::PropVariantClear(&value);
    if (titled) collection->AddObject(link.Get());
  }
  ComPtr<IObjectArray> array;
  if (FAILED(collection.As(&array)) || FAILED(list->AddUserTasks(array.Get()))) {
    list->AbortList();
    return false;
  }
  return SUCCEEDED(list->CommitList());
}

std::vector<std::string> WindowsShell::ReadClipboardFiles(const std::wstring& directory) {
  std::vector<std::string> files;
  if (!::OpenClipboard(window_)) return files;
  if (::IsClipboardFormatAvailable(CF_HDROP)) {
    // Files copied in Explorer.
    if (HANDLE drop = ::GetClipboardData(CF_HDROP)) files = PathsOf(static_cast<HDROP>(drop));
  } else if (!directory.empty() && !::IsClipboardFormatAvailable(CF_UNICODETEXT) &&
             ::IsClipboardFormatAvailable(CF_BITMAP)) {
    // A picture without text (a screenshot); with text Flutter pastes the text.
    HBITMAP bitmap = static_cast<HBITMAP>(::GetClipboardData(CF_BITMAP));
    const auto stamp = std::chrono::duration_cast<std::chrono::milliseconds>(
                           std::chrono::system_clock::now().time_since_epoch())
                           .count();
    const std::wstring path = directory + L"\\clipboard-" + std::to_wstring(stamp) + L".png";
    if (bitmap != nullptr && WritePng(bitmap, path)) {
      files.push_back(Utf8FromUtf16(path.c_str()));
    } else {
      ::DeleteFileW(path.c_str());
    }
  }
  ::CloseClipboard();
  return files;
}

bool WindowsShell::SetGlobalHotkeys(bool enabled) {
  if (hotkeys_) {
    ::UnregisterHotKey(window_, kHotkeyCompose);
    ::UnregisterHotKey(window_, kHotkeyShow);
    hotkeys_ = false;
  }
  if (!enabled) return true;
  // Ctrl+Alt+M: new message; Ctrl+Alt+X: XatBox in front. False when another
  // program holds one of them.
  const UINT modifiers = MOD_CONTROL | MOD_ALT | MOD_NOREPEAT;
  const bool compose = ::RegisterHotKey(window_, kHotkeyCompose, modifiers, 'M') != FALSE;
  const bool show = ::RegisterHotKey(window_, kHotkeyShow, modifiers, 'X') != FALSE;
  hotkeys_ = compose || show;
  return compose && show;
}

void WindowsShell::ShowWindowFromHotkey() {
  ::ShowWindow(window_, ::IsIconic(window_) ? SW_RESTORE : SW_SHOW);
  ::SetForegroundWindow(window_);
}

bool WindowsShell::StartFileDrag(const std::vector<std::wstring>& paths) {
  std::vector<PIDLIST_ABSOLUTE> pidls;
  for (const auto& path : paths) {
    PIDLIST_ABSOLUTE pidl = nullptr;
    if (SUCCEEDED(::SHParseDisplayName(path.c_str(), nullptr, &pidl, 0, nullptr))) {
      pidls.push_back(pidl);
    }
  }
  if (pidls.empty()) return false;
  ComPtr<IShellItemArray> items;
  const HRESULT created = ::SHCreateShellItemArrayFromIDLists(
      static_cast<UINT>(pidls.size()), const_cast<PCIDLIST_ABSOLUTE_ARRAY>(
                                           reinterpret_cast<const PCIDLIST_ABSOLUTE*>(pidls.data())),
      &items);
  for (auto pidl : pidls) ::CoTaskMemFree(pidl);
  if (FAILED(created)) return false;
  ComPtr<IDataObject> data;
  if (FAILED(items->BindToHandler(nullptr, BHID_DataObject, IID_PPV_ARGS(&data)))) return false;
  DWORD effect = DROPEFFECT_NONE;
  const HRESULT dropped = ::SHDoDragDrop(window_, data.Get(), nullptr, DROPEFFECT_COPY, &effect);
  // The drag loop took the button release: Flutter still thinks it is down.
  if (HWND view = ::FindWindowExW(window_, nullptr, L"FLUTTERVIEW", nullptr)) {
    POINT point;
    ::GetCursorPos(&point);
    ::ScreenToClient(view, &point);
    ::PostMessageW(view, WM_LBUTTONUP, 0, MAKELPARAM(point.x, point.y));
  }
  return SUCCEEDED(dropped) && effect != DROPEFFECT_NONE;
}
