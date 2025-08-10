// SMB Bridge implementation using libsmb2
// This file provides C interface for Dart FFI using libsmb2

#include "smb_bridge.h"
#include "smb_client.h"
#include "thumbnail_generator.h"
#include <memory>
#include <map>
#include <string>
#include <cstring>
#include <cstdlib>
#include <iostream>

// Global context and file handle management
static std::map<void *, std::unique_ptr<Smb2ClientWrapper>> g_contexts;
static std::map<void *, smb2fh *> g_file_handles;
static int g_next_context_id = 1;
static int g_next_handle_id = 1;

// Helper function to allocate and copy string
char *allocate_string(const std::string &str)
{
    char *result = static_cast<char *>(malloc(str.length() + 1));
    if (result)
    {
        strcpy(result, str.c_str());
    }
    return result;
}

extern "C"
{

    // Connection functions
    SmbContext *smb_connect(const char *server, const char *share, const char *username, const char *password)
    {
        if (!server || !share || !username || !password)
        {
            return nullptr;
        }

        try
        {
            auto client = std::make_unique<Smb2ClientWrapper>();

            // Attempt to connect
            bool success = client->connect(server, share, username, password);
            if (!success)
            {
                return nullptr;
            }

            // Create context ID
            void *context_id = reinterpret_cast<void *>(g_next_context_id++);
            g_contexts[context_id] = std::move(client);

            return reinterpret_cast<SmbContext *>(context_id);
        }
        catch (const std::exception &e)
        {
            std::cerr << "SMB connect error: " << e.what() << std::endl;
            return nullptr;
        }
    }

    void smb_disconnect(SmbContext *context)
    {
        if (!context)
            return;

        void *context_id = reinterpret_cast<void *>(context);
        auto it = g_contexts.find(context_id);
        if (it != g_contexts.end())
        {
            it->second->disconnect();
            g_contexts.erase(it);
        }
    }

    int smb_is_connected(SmbContext *context)
    {
        if (!context)
            return 0;

        void *context_id = reinterpret_cast<void *>(context);
        auto it = g_contexts.find(context_id);
        if (it != g_contexts.end())
        {
            return it->second->isConnected() ? 1 : 0;
        }
        return 0;
    }

    // File operations
    SmbFileHandle *smb_open_file(SmbContext *context, const char *path)
    {
        if (!context || !path)
        {
            return nullptr;
        }

        void *context_id = reinterpret_cast<void *>(context);
        auto it = g_contexts.find(context_id);
        if (it == g_contexts.end())
        {
            return nullptr;
        }

        smb2fh *file_handle = it->second->openFile(path);
        if (!file_handle)
        {
            return nullptr;
        }

        // Store file handle
        void *handle_id = reinterpret_cast<void *>(g_next_handle_id++);
        g_file_handles[handle_id] = file_handle;

        return reinterpret_cast<SmbFileHandle *>(handle_id);
    }

    void smb_close_file(SmbFileHandle *file_handle)
    {
        if (!file_handle)
            return;

        void *handle_id = reinterpret_cast<void *>(file_handle);
        auto it = g_file_handles.find(handle_id);
        if (it != g_file_handles.end())
        {
            // Find the context that owns this file handle
            for (auto &ctx_pair : g_contexts)
            {
                ctx_pair.second->closeFile(it->second);
                break;
            }
            g_file_handles.erase(it);
        }
    }

    int smb_read_chunk(SmbFileHandle *file_handle, uint8_t *buffer, size_t buffer_size, size_t *bytes_read)
    {
        if (!file_handle || !buffer || !bytes_read)
        {
            return SMB_ERROR_INVALID_PARAMETER;
        }

        void *handle_id = reinterpret_cast<void *>(file_handle);
        auto it = g_file_handles.find(handle_id);
        if (it == g_file_handles.end())
        {
            return SMB_ERROR_FILE_NOT_FOUND;
        }

        // Find the context that owns this file handle
        for (auto &ctx_pair : g_contexts)
        {
            size_t read_bytes = ctx_pair.second->readFile(it->second, buffer, buffer_size);
            *bytes_read = read_bytes;
            return SMB_SUCCESS;
        }

        return SMB_ERROR_UNKNOWN;
    }

    int smb_seek_file(SmbFileHandle *file_handle, uint64_t offset)
    {
        if (!file_handle)
        {
            return SMB_ERROR_INVALID_PARAMETER;
        }

        void *handle_id = reinterpret_cast<void *>(file_handle);
        auto it = g_file_handles.find(handle_id);
        if (it == g_file_handles.end())
        {
            return SMB_ERROR_FILE_NOT_FOUND;
        }

        // Find the context that owns this file handle
        for (auto &ctx_pair : g_contexts)
        {
            bool success = ctx_pair.second->seekFile(it->second, offset);
            return success ? SMB_SUCCESS : SMB_ERROR_UNKNOWN;
        }

        return SMB_ERROR_UNKNOWN;
    }

    uint64_t smb_get_file_size(SmbFileHandle *file_handle)
    {
        if (!file_handle)
        {
            return 0;
        }

        void *handle_id = reinterpret_cast<void *>(file_handle);
        auto it = g_file_handles.find(handle_id);
        if (it == g_file_handles.end())
        {
            return 0;
        }

        // Find the context that owns this file handle
        for (auto &ctx_pair : g_contexts)
        {
            return ctx_pair.second->getFileSize(it->second);
        }

        return 0;
    }

    // Optimized streaming operations
    SmbFileHandle *smb_open_file_for_streaming(SmbContext *context, const char *path)
    {
        if (!context || !path)
        {
            return nullptr;
        }

        void *context_id = reinterpret_cast<void *>(context);
        auto it = g_contexts.find(context_id);
        if (it == g_contexts.end())
        {
            return nullptr;
        }

        smb2fh *file_handle = it->second->openFileForStreaming(path);
        if (!file_handle)
        {
            return nullptr;
        }

        // Store file handle
        void *handle_id = reinterpret_cast<void *>(g_next_handle_id++);
        g_file_handles[handle_id] = file_handle;

        return reinterpret_cast<SmbFileHandle *>(handle_id);
    }

    int smb_read_chunk_optimized(SmbFileHandle *file_handle, uint8_t *buffer, size_t buffer_size, size_t *bytes_read, uint64_t offset)
    {
        if (!file_handle || !buffer || !bytes_read)
        {
            return SMB_ERROR_INVALID_PARAMETER;
        }

        void *handle_id = reinterpret_cast<void *>(file_handle);
        auto it = g_file_handles.find(handle_id);
        if (it == g_file_handles.end())
        {
            return SMB_ERROR_FILE_NOT_FOUND;
        }

        // Find the context that owns this file handle
        for (auto &ctx_pair : g_contexts)
        {
            size_t read_bytes = ctx_pair.second->readFileOptimized(it->second, buffer, buffer_size, offset);
            *bytes_read = read_bytes;
            return SMB_SUCCESS;
        }

        return SMB_ERROR_UNKNOWN;
    }

    int smb_set_read_ahead(SmbFileHandle *file_handle, size_t read_ahead_size)
    {
        if (!file_handle)
        {
            return SMB_ERROR_INVALID_PARAMETER;
        }

        void *handle_id = reinterpret_cast<void *>(file_handle);
        auto it = g_file_handles.find(handle_id);
        if (it == g_file_handles.end())
        {
            return SMB_ERROR_FILE_NOT_FOUND;
        }

        // Find the context that owns this file handle
        for (auto &ctx_pair : g_contexts)
        {
            bool success = ctx_pair.second->setReadAhead(it->second, read_ahead_size);
            return success ? SMB_SUCCESS : SMB_ERROR_UNKNOWN;
        }

        return SMB_ERROR_UNKNOWN;
    }

    // NEW: Enhanced read-range operations for VLC-style streaming
    int smb_read_range(SmbFileHandle *file_handle, uint8_t *buffer, size_t buffer_size,
                       uint64_t start_offset, uint64_t end_offset, size_t *bytes_read)
    {
        if (!file_handle || !buffer || !bytes_read)
        {
            return SMB_ERROR_INVALID_PARAMETER;
        }

        void *handle_id = reinterpret_cast<void *>(file_handle);
        auto it = g_file_handles.find(handle_id);
        if (it == g_file_handles.end())
        {
            return SMB_ERROR_FILE_NOT_FOUND;
        }

        // Find the context that owns this file handle
        for (auto &ctx_pair : g_contexts)
        {
            size_t read_bytes = ctx_pair.second->readRange(it->second, buffer, buffer_size, start_offset, end_offset);
            *bytes_read = read_bytes;
            return SMB_SUCCESS;
        }

        return SMB_ERROR_UNKNOWN;
    }

    int smb_read_range_async(SmbFileHandle *file_handle, uint8_t *buffer, size_t buffer_size,
                             uint64_t start_offset, uint64_t end_offset, size_t *bytes_read)
    {
        if (!file_handle || !buffer || !bytes_read)
        {
            return SMB_ERROR_INVALID_PARAMETER;
        }

        void *handle_id = reinterpret_cast<void *>(file_handle);
        auto it = g_file_handles.find(handle_id);
        if (it == g_file_handles.end())
        {
            return SMB_ERROR_FILE_NOT_FOUND;
        }

        // Find the context that owns this file handle
        for (auto &ctx_pair : g_contexts)
        {
            size_t read_bytes = ctx_pair.second->readRangeAsync(it->second, buffer, buffer_size, start_offset, end_offset);
            *bytes_read = read_bytes;
            return SMB_SUCCESS;
        }

        return SMB_ERROR_UNKNOWN;
    }

    int smb_prefetch_range(SmbFileHandle *file_handle, uint64_t start_offset, uint64_t end_offset)
    {
        if (!file_handle)
        {
            return SMB_ERROR_INVALID_PARAMETER;
        }

        void *handle_id = reinterpret_cast<void *>(file_handle);
        auto it = g_file_handles.find(handle_id);
        if (it == g_file_handles.end())
        {
            return SMB_ERROR_FILE_NOT_FOUND;
        }

        // Find the context that owns this file handle
        for (auto &ctx_pair : g_contexts)
        {
            bool success = ctx_pair.second->prefetchRange(it->second, start_offset, end_offset);
            return success ? SMB_SUCCESS : SMB_ERROR_UNKNOWN;
        }

        return SMB_ERROR_UNKNOWN;
    }

    int smb_set_streaming_options(SmbFileHandle *file_handle, size_t chunk_size, size_t buffer_size, int enable_caching)
    {
        if (!file_handle)
        {
            return SMB_ERROR_INVALID_PARAMETER;
        }

        void *handle_id = reinterpret_cast<void *>(file_handle);
        auto it = g_file_handles.find(handle_id);
        if (it == g_file_handles.end())
        {
            return SMB_ERROR_FILE_NOT_FOUND;
        }

        // Find the context that owns this file handle
        for (auto &ctx_pair : g_contexts)
        {
            bool success = ctx_pair.second->setStreamingOptions(it->second, chunk_size, buffer_size, enable_caching != 0);
            return success ? SMB_SUCCESS : SMB_ERROR_UNKNOWN;
        }

        return SMB_ERROR_UNKNOWN;
    }

    // NEW: SMB URL generation for direct VLC streaming
    char *smb_generate_direct_url(SmbContext *context, const char *path)
    {
        if (!context || !path)
        {
            return nullptr;
        }

        void *context_id = reinterpret_cast<void *>(context);
        auto it = g_contexts.find(context_id);
        if (it == g_contexts.end())
        {
            return nullptr;
        }

        std::string url = it->second->generateDirectUrl(path);
        return allocate_string(url);
    }

    char *smb_generate_url_with_credentials(SmbContext *context, const char *path,
                                            const char *username, const char *password)
    {
        if (!context || !path || !username || !password)
        {
            return nullptr;
        }

        void *context_id = reinterpret_cast<void *>(context);
        auto it = g_contexts.find(context_id);
        if (it == g_contexts.end())
        {
            return nullptr;
        }

        std::string url = it->second->generateUrlWithCredentials(path, username, password);
        return allocate_string(url);
    }

    char *smb_get_connection_url(SmbContext *context)
    {
        if (!context)
        {
            return nullptr;
        }

        void *context_id = reinterpret_cast<void *>(context);
        auto it = g_contexts.find(context_id);
        if (it == g_contexts.end())
        {
            return nullptr;
        }

        std::string url = it->second->getConnectionUrl();
        return allocate_string(url);
    }

    // Directory operations
    SmbDirectoryResult smb_list_directory(SmbContext *context, const char *path)
    {
        SmbDirectoryResult result = {nullptr, 0, SMB_ERROR_INVALID_PARAMETER};

        if (!context || !path)
        {
            return result;
        }

        void *context_id = reinterpret_cast<void *>(context);
        auto it = g_contexts.find(context_id);
        if (it == g_contexts.end())
        {
            result.error_code = SMB_ERROR_CONNECTION;
            return result;
        }

        try
        {
            std::vector<FileInfo> files = it->second->listDirectory(path);

            if (files.empty())
            {
                result.error_code = SMB_SUCCESS;
                return result;
            }

            // Allocate array for file info
            SmbFileInfo *file_array = static_cast<SmbFileInfo *>(malloc(sizeof(SmbFileInfo) * files.size()));
            if (!file_array)
            {
                result.error_code = SMB_ERROR_MEMORY_ALLOCATION;
                return result;
            }

            // Copy file information
            for (size_t i = 0; i < files.size(); ++i)
            {
                file_array[i].name = allocate_string(files[i].name);
                file_array[i].path = allocate_string(files[i].path);
                file_array[i].size = files[i].size;
                file_array[i].modified_time = files[i].modified_time;
                file_array[i].is_directory = files[i].is_directory ? 1 : 0;
                file_array[i].error_code = SMB_SUCCESS;
            }

            result.files = file_array;
            result.count = files.size();
            result.error_code = SMB_SUCCESS;
        }
        catch (const std::exception &e)
        {
            std::cerr << "Directory listing error: " << e.what() << std::endl;
            result.error_code = SMB_ERROR_UNKNOWN;
        }

        return result;
    }

    void smb_free_directory_result(SmbDirectoryResult *result)
    {
        if (!result || !result->files)
        {
            return;
        }

        for (size_t i = 0; i < result->count; ++i)
        {
            smb_free_string(result->files[i].name);
            smb_free_string(result->files[i].path);
        }

        free(result->files);
        result->files = nullptr;
        result->count = 0;
    }

    // Thumbnail generation
    ThumbnailResult smb_generate_thumbnail(SmbContext *context, const char *path, int width, int height)
    {
        ThumbnailResult result = {nullptr, 0, 0, 0, SMB_ERROR_INVALID_PARAMETER};

        if (!context || !path)
        {
            return result;
        }

        // For now, return stub result
        // TODO: Implement actual thumbnail generation
        result.error_code = SMB_ERROR_THUMBNAIL_GENERATION;
        return result;
    }

    void smb_free_thumbnail_result(ThumbnailResult *result)
    {
        if (!result)
        {
            return;
        }

        if (result->data)
        {
            free(result->data);
            result->data = nullptr;
        }

        result->size = 0;
        result->width = 0;
        result->height = 0;
    }

    // Utility functions
    const char *smb_get_error_message(int error_code)
    {
        switch (error_code)
        {
        case SMB_SUCCESS:
            return "Success";
        case SMB_ERROR_CONNECTION:
            return "Connection failed";
        case SMB_ERROR_AUTHENTICATION:
            return "Authentication failed";
        case SMB_ERROR_FILE_NOT_FOUND:
            return "File not found";
        case SMB_ERROR_PERMISSION_DENIED:
            return "Permission denied";
        case SMB_ERROR_INVALID_PARAMETER:
            return "Invalid parameter";
        case SMB_ERROR_MEMORY_ALLOCATION:
            return "Memory allocation failed";
        case SMB_ERROR_THUMBNAIL_GENERATION:
            return "Thumbnail generation failed";
        default:
            return "Unknown error";
        }
    }

    void smb_free_string(char *str)
    {
        if (str)
        {
            free(str);
        }
    }

    // Native context access for media streaming
    void *smb_get_native_context(SmbContext *context)
    {
        if (!context)
        {
            return nullptr;
        }

        void *context_id = reinterpret_cast<void *>(context);
        auto it = g_contexts.find(context_id);
        if (it != g_contexts.end())
        {
            // Return the native context pointer
            return it->second.get();
        }

        return nullptr;
    }
}