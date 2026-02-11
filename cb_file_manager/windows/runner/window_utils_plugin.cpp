#include "window_utils_plugin.h"

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <windows.h>

#include <memory>
#include <string>

namespace {

static bool g_is_fullscreen = false;
static RECT g_frame_before_fullscreen = {0, 0, 0, 0};
static LONG_PTR g_style_before_fullscreen = 0;
static bool g_maximized_before_fullscreen = false;

HWND GetMainWindow(flutter::PluginRegistrarWindows* registrar) {
  if (!registrar) return nullptr;
  auto view = registrar->GetView();
  if (!view) return nullptr;
  return view->GetNativeWindow();
}

HWND GetTopLevelWindow(flutter::PluginRegistrarWindows* registrar) {
  HWND hwnd = GetMainWindow(registrar);
  if (hwnd) {
    HWND root = ::GetAncestor(hwnd, GA_ROOT);
    if (root) return root;
    return hwnd;
  }

  // Fallback for unusual hosting setups.
  return ::FindWindow(L"FLUTTER_RUNNER_WIN32_WINDOW", nullptr);
}

RECT GetCurrentMonitorRect(HWND hwnd) {
  RECT monitor_rect = {0, 0, 0, 0};
  HMONITOR monitor = MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST);
  MONITORINFO info = {0};
  info.cbSize = sizeof(MONITORINFO);
  if (GetMonitorInfo(monitor, &info)) {
    monitor_rect = info.rcMonitor;
  }
  return monitor_rect;
}

void EnterFullscreen(HWND hwnd) {
  if (!hwnd) return;

  if (!g_is_fullscreen) {
    g_maximized_before_fullscreen = ::IsZoomed(hwnd);
    g_style_before_fullscreen = ::GetWindowLongPtr(hwnd, GWL_STYLE);
    ::GetWindowRect(hwnd, &g_frame_before_fullscreen);
  }

  g_is_fullscreen = true;

  const RECT monitor_rect = GetCurrentMonitorRect(hwnd);

  ::SetWindowLongPtr(hwnd, GWL_STYLE,
                     g_style_before_fullscreen & ~WS_OVERLAPPEDWINDOW);

  ::SetWindowPos(hwnd, HWND_TOP, monitor_rect.left, monitor_rect.top,
                 monitor_rect.right - monitor_rect.left,
                 monitor_rect.bottom - monitor_rect.top,
                 SWP_NOOWNERZORDER | SWP_FRAMECHANGED);

  ::ShowWindow(hwnd, SW_SHOW);
  ::SetForegroundWindow(hwnd);
}

void ExitFullscreen(HWND hwnd) {
  if (!hwnd) return;
  if (!g_is_fullscreen) return;

  g_is_fullscreen = false;

  ::SetWindowLongPtr(hwnd, GWL_STYLE, g_style_before_fullscreen);

  // Refresh the frame.
  ::SetWindowPos(hwnd, nullptr, 0, 0, 0, 0,
                 SWP_NOACTIVATE | SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER |
                     SWP_FRAMECHANGED);

  if (g_maximized_before_fullscreen) {
    ::PostMessage(hwnd, WM_SYSCOMMAND, SC_MAXIMIZE, 0);
  } else {
    ::SetWindowPos(hwnd, nullptr, g_frame_before_fullscreen.left,
                   g_frame_before_fullscreen.top,
                   g_frame_before_fullscreen.right -
                       g_frame_before_fullscreen.left,
                   g_frame_before_fullscreen.bottom -
                       g_frame_before_fullscreen.top,
                   SWP_NOACTIVATE | SWP_NOZORDER);
  }

  ::ShowWindow(hwnd, SW_SHOW);
  ::SetForegroundWindow(hwnd);
}

}  // namespace

// static
void WindowUtilsPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows* registrar) {
  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "cb_file_manager/window_utils",
          &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<WindowUtilsPlugin>(registrar);

  channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto& call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  registrar->AddPlugin(std::move(plugin));
}

WindowUtilsPlugin::WindowUtilsPlugin(flutter::PluginRegistrarWindows* registrar)
    : registrar_(registrar) {}

WindowUtilsPlugin::~WindowUtilsPlugin() {}

void WindowUtilsPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const auto method = method_call.method_name();

  if (method == "setNativeFullScreen") {
    const auto* arguments =
        std::get_if<flutter::EncodableMap>(method_call.arguments());
    if (!arguments) {
      result->Error("INVALID_ARGUMENTS", "Missing arguments.");
      return;
    }

    const auto it =
        arguments->find(flutter::EncodableValue("isFullScreen"));
    if (it == arguments->end()) {
      result->Error("INVALID_ARGUMENTS", "Missing isFullScreen.");
      return;
    }

    const bool is_fullscreen = std::get<bool>(it->second);
    HWND hwnd = GetTopLevelWindow(registrar_);
    if (!hwnd) {
      result->Error("NO_WINDOW", "Main window handle not available.");
      return;
    }

    if (is_fullscreen) {
      EnterFullscreen(hwnd);
    } else {
      ExitFullscreen(hwnd);
    }

    result->Success(flutter::EncodableValue(true));
    return;
  }

  if (method == "isNativeFullScreen") {
    result->Success(flutter::EncodableValue(g_is_fullscreen));
    return;
  }

  result->NotImplemented();
}
