#ifndef FLUTTER_PLUGIN_MOBILE_SMB_NATIVE_PLUGIN_H_
#define FLUTTER_PLUGIN_MOBILE_SMB_NATIVE_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

namespace mobile_smb_native {

class MobileSmbNativePlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  MobileSmbNativePlugin();

  virtual ~MobileSmbNativePlugin();

  // Disallow copy and assign.
  MobileSmbNativePlugin(const MobileSmbNativePlugin&) = delete;
  MobileSmbNativePlugin& operator=(const MobileSmbNativePlugin&) = delete;

  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}  // namespace mobile_smb_native

#endif  // FLUTTER_PLUGIN_MOBILE_SMB_NATIVE_PLUGIN_H_
