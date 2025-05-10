#include "app_icon_plugin.h"
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>
#include <commctrl.h>
#include <shlwapi.h>
#include <shlobj.h>
#include <shellapi.h>
#include <map>
#include <memory>
#include <sstream>
#include <string>
#include <vector>

#pragma comment(lib, "shell32.lib")
#pragma comment(lib, "comctl32.lib")
#pragma comment(lib, "shlwapi.lib")

// static
void AppIconPlugin::RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar) {
  auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      registrar->messenger(), "cb_file_manager/app_icon",
      &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<AppIconPlugin>(registrar);

  channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto& call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  registrar->AddPlugin(std::move(plugin));
}

AppIconPlugin::AppIconPlugin(flutter::PluginRegistrarWindows* registrar) 
    : registrar_(registrar) {}

AppIconPlugin::~AppIconPlugin() {}

void AppIconPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  
  if (method_call.method_name().compare("extractIconFromFile") == 0) {
    const auto* arguments = std::get_if<flutter::EncodableMap>(method_call.arguments());
    
    if (arguments) {
      auto exePath_it = arguments->find(flutter::EncodableValue("exePath"));
      
      if (exePath_it != arguments->end()) {
        std::string exePath = std::get<std::string>(exePath_it->second);
        
        std::vector<uint8_t> iconData;
        int iconWidth = 0;
        int iconHeight = 0;
        
        if (ExtractIconFromFile(exePath, iconData, iconWidth, iconHeight)) {
          flutter::EncodableMap response;
          response[flutter::EncodableValue("iconData")] = flutter::EncodableValue(iconData);
          response[flutter::EncodableValue("width")] = flutter::EncodableValue(iconWidth);
          response[flutter::EncodableValue("height")] = flutter::EncodableValue(iconHeight);
          
          result->Success(flutter::EncodableValue(response));
          return;
        } else {
          result->Error("ICON_EXTRACTION_FAILED", "Failed to extract icon from file: " + exePath);
          return;
        }
      }
    }
    
    result->Error("INVALID_ARGUMENTS", "Invalid or missing arguments");
    return;
  } else if (method_call.method_name().compare("getAssociatedAppPath") == 0) {
    const auto* arguments = std::get_if<flutter::EncodableMap>(method_call.arguments());
    
    if (arguments) {
      auto extension_it = arguments->find(flutter::EncodableValue("extension"));
      
      if (extension_it != arguments->end()) {
        std::string extension = std::get<std::string>(extension_it->second);
        
        std::string appPath = GetAssociatedAppPath(extension);
        
        if (!appPath.empty()) {
          result->Success(flutter::EncodableValue(appPath));
          return;
        } else {
          result->Error("NO_ASSOCIATED_APP", "No associated application found for extension: " + extension);
          return;
        }
      }
    }
    
    result->Error("INVALID_ARGUMENTS", "Invalid or missing arguments");
    return;
  } else {
    result->NotImplemented();
  }
}

bool AppIconPlugin::ExtractIconFromFile(
    const std::string& exePath,
    std::vector<uint8_t>& outputBuffer,
    int& iconWidth,
    int& iconHeight) {
    
  if (exePath.empty()) {
    return false;
  }

  // Convert UTF-8 path to wide string
  int widePathSize = MultiByteToWideChar(CP_UTF8, 0, exePath.c_str(), -1, nullptr, 0);
  if (widePathSize == 0) {
    return false;
  }
  
  std::vector<wchar_t> wExePath(widePathSize);
  if (MultiByteToWideChar(CP_UTF8, 0, exePath.c_str(), -1, wExePath.data(), widePathSize) == 0) {
    return false;
  }

  // Get the associated icon
  SHFILEINFOW fileInfo = { 0 };
  DWORD_PTR result = SHGetFileInfoW(
      wExePath.data(),
      0,
      &fileInfo,
      sizeof(fileInfo),
      SHGFI_ICON | SHGFI_LARGEICON
  );

  if (result == 0 || !fileInfo.hIcon) {
    return false;
  }

  // Extract the icon dimensions and bitmap data
  ICONINFO iconInfo;
  if (!GetIconInfo(fileInfo.hIcon, &iconInfo)) {
    DestroyIcon(fileInfo.hIcon);
    return false;
  }

  BITMAP bmp;
  if (!GetObject(iconInfo.hbmColor, sizeof(BITMAP), &bmp)) {
    DeleteObject(iconInfo.hbmMask);
    DeleteObject(iconInfo.hbmColor);
    DestroyIcon(fileInfo.hIcon);
    return false;
  }

  iconWidth = bmp.bmWidth;
  iconHeight = bmp.bmHeight;

  // Create a memory DC compatible with the screen
  HDC screenDC = GetDC(NULL);
  HDC memDC = CreateCompatibleDC(screenDC);

  // Create a compatible bitmap to hold the icon
  HBITMAP hBitmap = CreateCompatibleBitmap(screenDC, iconWidth, iconHeight);
  HBITMAP oldBitmap = (HBITMAP)SelectObject(memDC, hBitmap);

  // Fill with transparent background
  HBRUSH hBrush = CreateSolidBrush(RGB(0, 0, 0));
  RECT rect = { 0, 0, iconWidth, iconHeight };
  FillRect(memDC, &rect, hBrush);
  DeleteObject(hBrush);

  // Draw the icon on the memory DC
  DrawIconEx(memDC, 0, 0, fileInfo.hIcon, iconWidth, iconHeight, 0, NULL, DI_NORMAL);

  // Get the bitmap bits
  BITMAPINFOHEADER bmi = { 0 };
  bmi.biSize = sizeof(BITMAPINFOHEADER);
  bmi.biWidth = iconWidth;
  bmi.biHeight = -iconHeight; // Negative height for top-down
  bmi.biPlanes = 1;
  bmi.biBitCount = 32;
  bmi.biCompression = BI_RGB;

  int stride = ((iconWidth * 32 + 31) / 32) * 4;
  int imageSize = stride * iconHeight;
  
  // Resize the output buffer
  outputBuffer.resize(imageSize);

  // Get the bitmap data
  bool success = (GetDIBits(memDC, hBitmap, 0, iconHeight, outputBuffer.data(), (BITMAPINFO*)&bmi, DIB_RGB_COLORS) != 0);

  // Cleanup
  SelectObject(memDC, oldBitmap);
  DeleteObject(hBitmap);
  DeleteDC(memDC);
  ReleaseDC(NULL, screenDC);
  DeleteObject(iconInfo.hbmMask);
  DeleteObject(iconInfo.hbmColor);
  DestroyIcon(fileInfo.hIcon);

  return success;
}

std::string AppIconPlugin::GetAssociatedAppPath(const std::string& extension) {
  // Ensure extension starts with dot
  std::string ext = extension;
  if (!ext.empty() && ext[0] != '.') {
    ext = "." + ext;
  }

  // Convert extension to wide string
  int wideExtSize = MultiByteToWideChar(CP_UTF8, 0, ext.c_str(), -1, nullptr, 0);
  if (wideExtSize == 0) {
    return "";
  }
  
  std::vector<wchar_t> wExtension(wideExtSize);
  if (MultiByteToWideChar(CP_UTF8, 0, ext.c_str(), -1, wExtension.data(), wideExtSize) == 0) {
    return "";
  }

  // Get executable path for this file extension
  wchar_t execPath[MAX_PATH] = { 0 };
  DWORD execPathSize = MAX_PATH;

  HRESULT hr = AssocQueryStringW(
      ASSOCF_NONE,
      ASSOCSTR_EXECUTABLE,
      wExtension.data(),
      NULL,
      execPath,
      &execPathSize
  );

  if (FAILED(hr)) {
    return "";
  }

  // Convert result to UTF-8
  int utf8Size = WideCharToMultiByte(CP_UTF8, 0, execPath, -1, nullptr, 0, NULL, NULL);
  if (utf8Size == 0) {
    return "";
  }
  
  std::vector<char> utf8Path(utf8Size);
  if (WideCharToMultiByte(CP_UTF8, 0, execPath, -1, utf8Path.data(), utf8Size, NULL, NULL) == 0) {
    return "";
  }
  
  return std::string(utf8Path.data());
} 