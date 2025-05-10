#ifndef APP_ICON_PLUGIN_H_
#define APP_ICON_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <windows.h>
#include <memory>
#include <string>

class AppIconPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar);

  AppIconPlugin(flutter::PluginRegistrarWindows* registrar);

  virtual ~AppIconPlugin();

  // Disallow copy and assign.
  AppIconPlugin(const AppIconPlugin&) = delete;
  AppIconPlugin& operator=(const AppIconPlugin&) = delete;

 private:
  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  // Extract icon from an executable file
  bool ExtractIconFromFile(
      const std::string& exePath,
      std::vector<uint8_t>& outputBuffer,
      int& iconWidth,
      int& iconHeight);
      
  // Get the associated application executable path for a file extension
  std::string GetAssociatedAppPath(const std::string& extension);

  // Plugin registrar
  flutter::PluginRegistrarWindows* registrar_;
};

#endif  // APP_ICON_PLUGIN_H_ 