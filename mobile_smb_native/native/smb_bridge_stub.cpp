#include <cstdint>
#include <cstring>
#include <cstdlib>
#include <cstddef> // for size_t

extern "C" {

// SMB connection functions
void* smb_connect(const char* server, const char* share, const char* username, const char* password) {
    return (void*)0x1; // Return dummy pointer
}

void smb_disconnect(void* context) {
    // Do nothing
}

int32_t smb_is_connected(void* context) {
    return 1; // Connected
}

// File operations
void* smb_open_file(void* context, const char* path) {
    return (void*)0x1; // Return dummy file handle
}

void smb_close_file(void* fileHandle) {
    // Do nothing
}

int32_t smb_read_chunk(void* fileHandle, uint8_t* buffer, size_t bufferSize, size_t* bytesRead) {
    if (bytesRead) {
        *bytesRead = 0;
    }
    return 0; // Success - no data read in stub
}

int32_t smb_seek_file(void* fileHandle, uint64_t offset) {
    return 0; // Success
}

uint64_t smb_get_file_size(void* fileHandle) {
    return 0; // File size
}

// Directory operations
struct SmbFileInfo {
    char* name;
    char* path;
    uint64_t size;
    uint64_t modifiedTime;
    int32_t isDirectory;
    int32_t errorCode;
};

struct SmbDirectoryResult {
    SmbFileInfo* files;
    uint64_t count;
    int32_t errorCode;
};

SmbDirectoryResult smb_list_directory(void* context, const char* path) {
    SmbDirectoryResult result;
    result.files = nullptr;
    result.count = 0;
    result.errorCode = 0;
    return result;
}

void smb_free_directory_result(SmbDirectoryResult* result) {
    // Do nothing for stub
}

// Thumbnail generation
struct ThumbnailResult {
    uint8_t* data;
    uint64_t size;
    int32_t width;
    int32_t height;
    int32_t errorCode;
};

ThumbnailResult smb_generate_thumbnail(void* context, const char* path, int32_t width, int32_t height) {
    ThumbnailResult result;
    result.data = nullptr;
    result.size = 0;
    result.width = 0;
    result.height = 0;
    result.errorCode = 0;
    return result;
}

void smb_free_thumbnail_result(ThumbnailResult* result) {
    // Do nothing for stub
}

// Error handling
const char* smb_get_error_message(int32_t errorCode) {
    return "No error";
}

void smb_free_string(const char* str) {
    // Do nothing for stub
}

}