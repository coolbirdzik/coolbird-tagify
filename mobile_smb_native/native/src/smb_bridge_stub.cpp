#include <cstdint>
#include <cstring>
#include <cstdlib>

// Error codes
#define SMB_SUCCESS 0
#define SMB_ERROR_GENERIC -1

// Struct definitions matching Dart FFI
struct SmbFileInfo {
    char* name;
    char* path;
    uint64_t size;
    uint64_t modifiedTime;
    int32_t isDirectory;
};

struct SmbDirectoryResult {
    SmbFileInfo* files;
    uint64_t count;
    int32_t errorCode;
};

struct ThumbnailResult {
    uint8_t* data;
    uint64_t size;
    int32_t width;
    int32_t height;
    int32_t errorCode;
};

extern "C" {

// Connection functions
void* smb_connect(const char* server, const char* share, const char* username, const char* password) {
    // Return a dummy pointer to simulate successful connection
    return (void*)0x12345678;
}

void smb_disconnect(void* context) {
    // Stub implementation - do nothing
}

int32_t smb_is_connected(void* context) {
    // Always return connected for stub
    return 1;
}

// File operations
void* smb_open_file(void* context, const char* path) {
    // Return a dummy file handle
    return (void*)0x87654321;
}

void smb_close_file(void* fileHandle) {
    // Stub implementation - do nothing
}

int32_t smb_read_chunk(void* fileHandle, uint8_t* buffer, uint64_t bufferSize, uint64_t* bytesRead) {
    // Stub implementation - return 0 bytes read
    *bytesRead = 0;
    return SMB_SUCCESS;
}

int32_t smb_seek_file(void* fileHandle, uint64_t offset) {
    // Stub implementation - always succeed
    return SMB_SUCCESS;
}

uint64_t smb_get_file_size(void* fileHandle) {
    // Return dummy file size
    return 1024;
}

// Directory operations
SmbDirectoryResult smb_list_directory(void* context, const char* path) {
    SmbDirectoryResult result;
    result.files = nullptr;
    result.count = 0;
    result.errorCode = SMB_SUCCESS;
    return result;
}

void smb_free_directory_result(SmbDirectoryResult* result) {
    // Stub implementation - do nothing since we don't allocate anything
}

// Thumbnail generation
ThumbnailResult smb_generate_thumbnail(void* context, const char* path, int32_t width, int32_t height) {
    ThumbnailResult result;
    result.data = nullptr;
    result.size = 0;
    result.width = width;
    result.height = height;
    result.errorCode = SMB_ERROR_GENERIC; // Not supported in stub
    return result;
}

void smb_free_thumbnail_result(ThumbnailResult* result) {
    // Stub implementation - do nothing since we don't allocate anything
}

// Utility functions
char* smb_get_error_message(int32_t errorCode) {
    const char* message = "Stub implementation - no real error handling";
    char* result = (char*)malloc(strlen(message) + 1);
    strcpy(result, message);
    return result;
}

void smb_free_string(char* str) {
    if (str) {
        free(str);
    }
}

} // extern "C"