#ifndef SMB_BRIDGE_H
#define SMB_BRIDGE_H

#ifdef __cplusplus
extern "C"
{
#endif

#include <stdint.h>
#include <stddef.h>

// Error codes
#define SMB_SUCCESS 0
#define SMB_ERROR_CONNECTION -1
#define SMB_ERROR_AUTHENTICATION -2
#define SMB_ERROR_FILE_NOT_FOUND -3
#define SMB_ERROR_PERMISSION_DENIED -4
#define SMB_ERROR_INVALID_PARAMETER -5
#define SMB_ERROR_MEMORY_ALLOCATION -6
#define SMB_ERROR_THUMBNAIL_GENERATION -7
#define SMB_ERROR_UNKNOWN -999

    // Forward declarations
    typedef struct SmbContext SmbContext;
    typedef struct SmbFileHandle SmbFileHandle;

    // Thumbnail result structure
    typedef struct
    {
        uint8_t *data;
        size_t size;
        int width;
        int height;
        int error_code;
    } ThumbnailResult;

    // File info structure
    typedef struct
    {
        char *name;
        char *path;
        uint64_t size;
        uint64_t modified_time;
        int is_directory;
        int error_code;
    } SmbFileInfo;

    // Directory listing result
    typedef struct
    {
        SmbFileInfo *files;
        size_t count;
        int error_code;
    } SmbDirectoryResult;

    // Connection functions
    SmbContext *smb_connect(const char *server, const char *share, const char *username, const char *password);
    void smb_disconnect(SmbContext *context);
    int smb_is_connected(SmbContext *context);

    // SMB version and connection info
    char *smb_get_version(SmbContext *context);
    char *smb_get_connection_info(SmbContext *context);

    // File operations
    SmbFileHandle *smb_open_file(SmbContext *context, const char *path);
    void smb_close_file(SmbFileHandle *file_handle);
    int smb_read_chunk(SmbFileHandle *file_handle, uint8_t *buffer, size_t buffer_size, size_t *bytes_read);
    int smb_seek_file(SmbFileHandle *file_handle, uint64_t offset);
    uint64_t smb_get_file_size(SmbFileHandle *file_handle);

    // Optimized video streaming operations
    SmbFileHandle *smb_open_file_for_streaming(SmbContext *context, const char *path);
    int smb_read_chunk_optimized(SmbFileHandle *file_handle, uint8_t *buffer, size_t buffer_size, size_t *bytes_read, uint64_t offset);
    int smb_set_read_ahead(SmbFileHandle *file_handle, size_t read_ahead_size);

    // NEW: Enhanced read-range operations for VLC-style streaming
    int smb_read_range(SmbFileHandle *file_handle, uint8_t *buffer, size_t buffer_size,
                       uint64_t start_offset, uint64_t end_offset, size_t *bytes_read);
    int smb_read_range_async(SmbFileHandle *file_handle, uint8_t *buffer, size_t buffer_size,
                             uint64_t start_offset, uint64_t end_offset, size_t *bytes_read);
    int smb_prefetch_range(SmbFileHandle *file_handle, uint64_t start_offset, uint64_t end_offset);
    int smb_set_streaming_options(SmbFileHandle *file_handle, size_t chunk_size, size_t buffer_size, int enable_caching);

    // NEW: SMB URL generation for direct VLC streaming
    char *smb_generate_direct_url(SmbContext *context, const char *path);
    char *smb_generate_url_with_credentials(SmbContext *context, const char *path,
                                            const char *username, const char *password);
    char *smb_get_connection_url(SmbContext *context);

    // Directory operations
    SmbDirectoryResult smb_list_directory(SmbContext *context, const char *path);
    void smb_free_directory_result(SmbDirectoryResult *result);

    // Thumbnail generation
    ThumbnailResult smb_generate_thumbnail(SmbContext *context, const char *path, int width, int height);
    void smb_free_thumbnail_result(ThumbnailResult *result);

    // Utility functions
    const char *smb_get_error_message(int error_code);
    void smb_free_string(char *str);

    // Native context access for media streaming
    void *smb_get_native_context(SmbContext *context);

#ifdef __cplusplus
}
#endif

#endif // SMB_BRIDGE_H