#include "flutter_window.h"

#include <optional>
#include <string>

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include "flutter/generated_plugin_registrant.h"

namespace {

std::wstring Utf8ToWide(const std::string& value) {
  if (value.empty()) return std::wstring();
  const int size = MultiByteToWideChar(CP_UTF8, 0, value.c_str(),
                                       static_cast<int>(value.size()), nullptr, 0);
  std::wstring result(size, 0);
  MultiByteToWideChar(CP_UTF8, 0, value.c_str(), static_cast<int>(value.size()),
                      result.data(), size);
  return result;
}

void SetDesktopStyle(const std::string& mode) {
  std::wstring style = L"10";
  std::wstring tile = L"0";
  if (mode == "fit") style = L"6";
  if (mode == "stretch") style = L"2";
  if (mode == "center") style = L"0";
  if (mode == "tile") {
    style = L"0";
    tile = L"1";
  }
  if (mode == "span") style = L"22";

  HKEY key;
  if (RegOpenKeyExW(HKEY_CURRENT_USER, L"Control Panel\\Desktop", 0,
                    KEY_SET_VALUE, &key) == ERROR_SUCCESS) {
    RegSetValueExW(key, L"WallpaperStyle", 0, REG_SZ,
                   reinterpret_cast<const BYTE*>(style.c_str()),
                   static_cast<DWORD>((style.size() + 1) * sizeof(wchar_t)));
    RegSetValueExW(key, L"TileWallpaper", 0, REG_SZ,
                   reinterpret_cast<const BYTE*>(tile.c_str()),
                   static_cast<DWORD>((tile.size() + 1) * sizeof(wchar_t)));
    RegCloseKey(key);
  }
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  wallpaper_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "wallpaper/native",
          &flutter::StandardMethodCodec::GetInstance());
  wallpaper_channel_->SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name() != "setWallpaper") {
          result->NotImplemented();
          return;
        }
        const auto* arguments =
            std::get_if<flutter::EncodableMap>(call.arguments());
        if (!arguments) {
          result->Error("invalid_arguments", "Expected a path and mode.");
          return;
        }
        const auto path_it = arguments->find(flutter::EncodableValue("path"));
        const auto mode_it = arguments->find(flutter::EncodableValue("mode"));
        if (path_it == arguments->end() || mode_it == arguments->end()) {
          result->Error("invalid_arguments", "Expected a path and mode.");
          return;
        }
        const auto* path = std::get_if<std::string>(&path_it->second);
        const auto* mode = std::get_if<std::string>(&mode_it->second);
        if (!path || !mode) {
          result->Error("invalid_arguments", "Path and mode must be strings.");
          return;
        }
        const std::wstring wide_path = Utf8ToWide(*path);
        if (GetFileAttributesW(wide_path.c_str()) == INVALID_FILE_ATTRIBUTES) {
          result->Error("missing_file", "The selected wallpaper file does not exist.");
          return;
        }
        SetDesktopStyle(*mode);
        if (!SystemParametersInfoW(SPI_SETDESKWALLPAPER, 0,
                                   const_cast<wchar_t*>(wide_path.c_str()),
                                   SPIF_UPDATEINIFILE | SPIF_SENDCHANGE)) {
          result->Error("windows_error", "Windows could not set the wallpaper.");
          return;
        }
        result->Success();
      });
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    wallpaper_channel_.reset();
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
