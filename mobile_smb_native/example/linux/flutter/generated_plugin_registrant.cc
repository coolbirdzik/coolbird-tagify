//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <mobile_smb_native/mobile_smb_native_plugin.h>

void fl_register_plugins(FlPluginRegistry* registry) {
  g_autoptr(FlPluginRegistrar) mobile_smb_native_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "MobileSmbNativePlugin");
  mobile_smb_native_plugin_register_with_registrar(mobile_smb_native_registrar);
}
