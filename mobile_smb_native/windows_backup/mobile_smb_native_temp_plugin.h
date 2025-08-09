#ifndef FLUTTER_PLUGIN_MOBILE_SMB_NATIVE_TEMP_PLUGIN_H_
#define FLUTTER_PLUGIN_MOBILE_SMB_NATIVE_TEMP_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

namespace mobile_smb_native_temp {

class MobileSmbNativeTempPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  MobileSmbNativeTempPlugin();

  virtual ~MobileSmbNativeTempPlugin();

  // Disallow copy and assign.
  MobileSmbNativeTempPlugin(const MobileSmbNativeTempPlugin&) = delete;
  MobileSmbNativeTempPlugin& operator=(const MobileSmbNativeTempPlugin&) = delete;

  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}  // namespace mobile_smb_native_temp

#endif  // FLUTTER_PLUGIN_MOBILE_SMB_NATIVE_TEMP_PLUGIN_H_
