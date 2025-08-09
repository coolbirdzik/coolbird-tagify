#include "include/mobile_smb_native/mobile_smb_native_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "mobile_smb_native_plugin.h"

// Define FLUTTER_PLUGIN_IMPL to get the export macro
#ifndef FLUTTER_PLUGIN_IMPL
#define FLUTTER_PLUGIN_IMPL
#endif

FLUTTER_PLUGIN_EXPORT void MobileSmbNativePluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  mobile_smb_native::MobileSmbNativePlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}

// Alias for compatibility with generated_plugin_registrant.cc
FLUTTER_PLUGIN_EXPORT void MobileSmbNativePluginRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  MobileSmbNativePluginCApiRegisterWithRegistrar(registrar);
}
