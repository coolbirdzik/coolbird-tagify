#ifndef FILE_OPERATIONS_PLUGIN_H_
#define FILE_OPERATIONS_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

namespace file_operations_plugin
{

    void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

} // namespace file_operations_plugin

#endif // FILE_OPERATIONS_PLUGIN_H_
