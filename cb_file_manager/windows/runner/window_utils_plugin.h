#ifndef RUNNER_WINDOW_UTILS_PLUGIN_H_
#define RUNNER_WINDOW_UTILS_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

class WindowUtilsPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar);

  explicit WindowUtilsPlugin(flutter::PluginRegistrarWindows* registrar);
  virtual ~WindowUtilsPlugin();

  WindowUtilsPlugin(const WindowUtilsPlugin&) = delete;
  WindowUtilsPlugin& operator=(const WindowUtilsPlugin&) = delete;

 private:
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  flutter::PluginRegistrarWindows* registrar_;
};

#endif  // RUNNER_WINDOW_UTILS_PLUGIN_H_
