#include "file_operations_plugin.h"

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <shlobj.h>
#include <shobjidl.h>
#include <windows.h>
#include <wrl/client.h>

#include <memory>
#include <string>
#include <vector>

#pragma comment(lib, "ole32.lib")
#pragma comment(lib, "shell32.lib")

namespace file_operations_plugin
{

    namespace
    {

        std::wstring Utf8ToWide(const std::string &utf8)
        {
            if (utf8.empty())
            {
                return std::wstring();
            }
            int size_needed = MultiByteToWideChar(CP_UTF8, 0, utf8.data(),
                                                  static_cast<int>(utf8.size()),
                                                  nullptr, 0);
            if (size_needed <= 0)
            {
                return std::wstring();
            }
            std::wstring wide(static_cast<size_t>(size_needed), L'\0');
            MultiByteToWideChar(CP_UTF8, 0, utf8.data(),
                                static_cast<int>(utf8.size()),
                                wide.data(), size_needed);
            return wide;
        }

        // Perform file operation using IFileOperation with progress dialog
        bool PerformFileOperation(
            HWND hwnd,
            const std::vector<std::wstring> &source_paths,
            const std::wstring &destination_path,
            bool is_move)
        {

            Microsoft::WRL::ComPtr<IFileOperation> pfo;
            HRESULT hr = CoCreateInstance(
                CLSID_FileOperation,
                nullptr,
                CLSCTX_ALL,
                IID_PPV_ARGS(&pfo));

            if (FAILED(hr))
            {
                return false;
            }

            // Set operation flags - show UI, allow undo, show progress
            DWORD flags = FOF_ALLOWUNDO | FOFX_ADDUNDORECORD | FOFX_SHOWELEVATIONPROMPT;
            hr = pfo->SetOperationFlags(flags);
            if (FAILED(hr))
            {
                return false;
            }

            // Set the owner window for the progress dialog
            if (hwnd)
            {
                pfo->SetOwnerWindow(hwnd);
            }

            // Get the destination folder
            Microsoft::WRL::ComPtr<IShellItem> psiDest;
            hr = SHCreateItemFromParsingName(
                destination_path.c_str(),
                nullptr,
                IID_PPV_ARGS(&psiDest));

            if (FAILED(hr))
            {
                return false;
            }

            // Add each source item to the operation
            for (const auto &source : source_paths)
            {
                Microsoft::WRL::ComPtr<IShellItem> psiSource;
                hr = SHCreateItemFromParsingName(
                    source.c_str(),
                    nullptr,
                    IID_PPV_ARGS(&psiSource));

                if (FAILED(hr))
                {
                    continue; // Skip invalid paths
                }

                if (is_move)
                {
                    hr = pfo->MoveItem(psiSource.Get(), psiDest.Get(), nullptr, nullptr);
                }
                else
                {
                    hr = pfo->CopyItem(psiSource.Get(), psiDest.Get(), nullptr, nullptr);
                }

                if (FAILED(hr))
                {
                    return false;
                }
            }

            // Perform the operation (this shows the native progress dialog)
            hr = pfo->PerformOperations();

            if (FAILED(hr))
            {
                return false;
            }

            // Check if operation was aborted by user
            BOOL aborted = FALSE;
            pfo->GetAnyOperationsAborted(&aborted);

            return !aborted;
        }

        class FileOperationsPlugin : public flutter::Plugin
        {
        public:
            static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

            explicit FileOperationsPlugin(flutter::PluginRegistrarWindows *registrar);
            virtual ~FileOperationsPlugin();

        private:
            void HandleMethodCall(
                const flutter::MethodCall<flutter::EncodableValue> &method_call,
                std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

            flutter::PluginRegistrarWindows *registrar_;
        };

        void FileOperationsPlugin::RegisterWithRegistrar(
            flutter::PluginRegistrarWindows *registrar)
        {
            auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
                registrar->messenger(),
                "cb_file_manager/file_operations",
                &flutter::StandardMethodCodec::GetInstance());

            auto plugin = std::make_unique<FileOperationsPlugin>(registrar);

            channel->SetMethodCallHandler(
                [plugin_pointer = plugin.get()](const auto &call, auto result)
                {
                    plugin_pointer->HandleMethodCall(call, std::move(result));
                });

            registrar->AddPlugin(std::move(plugin));
        }

        FileOperationsPlugin::FileOperationsPlugin(
            flutter::PluginRegistrarWindows *registrar)
            : registrar_(registrar) {}

        FileOperationsPlugin::~FileOperationsPlugin() {}

        void FileOperationsPlugin::HandleMethodCall(
            const flutter::MethodCall<flutter::EncodableValue> &method_call,
            std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
        {

            const std::string &method = method_call.method_name();

            if (method == "copyItems" || method == "moveItems")
            {
                const auto *arguments = std::get_if<flutter::EncodableMap>(method_call.arguments());
                if (!arguments)
                {
                    result->Error("INVALID_ARGUMENTS", "Arguments must be a map.");
                    return;
                }

                // Get source paths
                auto sources_it = arguments->find(flutter::EncodableValue("sources"));
                if (sources_it == arguments->end())
                {
                    result->Error("INVALID_ARGUMENTS", "Missing 'sources' argument.");
                    return;
                }

                const auto *sources_list = std::get_if<flutter::EncodableList>(&sources_it->second);
                if (!sources_list || sources_list->empty())
                {
                    result->Error("INVALID_ARGUMENTS", "'sources' must be a non-empty list.");
                    return;
                }

                std::vector<std::wstring> source_paths;
                for (const auto &source : *sources_list)
                {
                    if (const auto *path = std::get_if<std::string>(&source))
                    {
                        source_paths.push_back(Utf8ToWide(*path));
                    }
                }

                if (source_paths.empty())
                {
                    result->Error("INVALID_ARGUMENTS", "No valid source paths provided.");
                    return;
                }

                // Get destination path
                auto dest_it = arguments->find(flutter::EncodableValue("destination"));
                if (dest_it == arguments->end())
                {
                    result->Error("INVALID_ARGUMENTS", "Missing 'destination' argument.");
                    return;
                }

                const auto *dest_path = std::get_if<std::string>(&dest_it->second);
                if (!dest_path || dest_path->empty())
                {
                    result->Error("INVALID_ARGUMENTS", "'destination' must be a non-empty string.");
                    return;
                }

                std::wstring destination = Utf8ToWide(*dest_path);
                bool is_move = (method == "moveItems");

                // Get the Flutter window handle
                HWND hwnd = registrar_->GetView()->GetNativeWindow();

                // Perform the file operation
                bool success = PerformFileOperation(hwnd, source_paths, destination, is_move);

                result->Success(flutter::EncodableValue(success));
                return;
            }

            result->NotImplemented();
        }

    } // namespace

    void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar)
    {
        FileOperationsPlugin::RegisterWithRegistrar(registrar);
    }

} // namespace file_operations_plugin
