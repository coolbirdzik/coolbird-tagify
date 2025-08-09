#include "include/mobile_smb_native_temp/mobile_smb_native_temp_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "mobile_smb_native_temp_plugin.h"

void MobileSmbNativeTempPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  mobile_smb_native_temp::MobileSmbNativeTempPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
