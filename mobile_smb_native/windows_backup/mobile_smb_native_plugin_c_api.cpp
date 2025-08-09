#include "include/mobile_smb_native/mobile_smb_native_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "mobile_smb_native_plugin.h"

void MobileSmbNativePluginRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  mobile_smb_native::MobileSmbNativePlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
