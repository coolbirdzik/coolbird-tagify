#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"
#include "fc_native_video_thumbnail_plugin.h"

// Function to get the primary monitor work area dimensions
// This ensures we respect the taskbar and title bar areas
void GetPrimaryMonitorWorkArea(int *width, int *height)
{
  HMONITOR primaryMonitor = MonitorFromPoint({0, 0}, MONITOR_DEFAULTTOPRIMARY);
  MONITORINFO monitorInfo = {0};
  monitorInfo.cbSize = sizeof(MONITORINFO);

  if (GetMonitorInfo(primaryMonitor, &monitorInfo))
  {
    // Use work area (excludes taskbar) instead of full monitor area
    *width = monitorInfo.rcWork.right - monitorInfo.rcWork.left;
    *height = monitorInfo.rcWork.bottom - monitorInfo.rcWork.top;
  }
  else
  {
    // Fallback to system metrics for work area if GetMonitorInfo fails
    *width = GetSystemMetrics(SM_CXMAXIMIZED);
    *height = GetSystemMetrics(SM_CYMAXIMIZED);
  }
}

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command)
{
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent())
  {
    CreateAndAttachConsole();
  } // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);

  // Detect PiP mode via environment variable set by Dart side
  bool pip_mode = false;
  wchar_t pipBuf[8];
  DWORD pipLen = GetEnvironmentVariableW(L"CB_PIP_MODE", pipBuf, 8);
  if (pipLen > 0 && pipBuf[0] == L'1')
  {
    pip_mode = true;
  }

  // Prepare origin and size
  Win32Window::Point origin(0, 0);
  Win32Window::Size size(0, 0);

  if (pip_mode)
  {
    // Small initial window for PiP; will be adjusted by window_manager later
    size = Win32Window::Size(384, 216);
  }
  else
  {
    // Get work area dimensions (respects taskbar and title bar)
    int screenWidth = 0;
    int screenHeight = 0;
    GetPrimaryMonitorWorkArea(&screenWidth, &screenHeight);
    size = Win32Window::Size(screenWidth, screenHeight);
  }

  if (!window.Create(L"CoolBird Tagify - File Manager", origin, size))
  {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  if (pip_mode)
  {
    // Show the window immediately in PiP mode (non-maximized).
    // Background is forced black in Win32 to avoid white flash.
    window.Show();
  }
  else
  {
    // Use ShowMaximized to properly maximize the window for the main app
    window.ShowMaximized();
  }

  // Get the window handle
  HWND hwnd = window.GetHandle();
  if (hwnd != nullptr)
  {
    // Ensure the window is the topmost window
    SetForegroundWindow(hwnd);
  }

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0))
  {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
