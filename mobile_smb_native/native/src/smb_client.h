#pragma once

#include <string>
#include <vector>
#include <memory>
#include <cstdint>

// Forward declarations for libsmb2
struct smb2_context;
struct smb2fh;

// File information structure
struct FileInfo
{
    std::string name;
    std::string path;
    uint64_t size;
    uint64_t modified_time;
    bool is_directory;
};

// PIMPL pattern for libsmb2 client
class Smb2ClientWrapper
{
public:
    Smb2ClientWrapper();
    ~Smb2ClientWrapper();

    // Connection management
    bool connect(const std::string &server, const std::string &share,
                 const std::string &username, const std::string &password,
                 const std::string &domain = "");
    void disconnect();
    bool isConnected() const;

    // File operations
    smb2fh *openFile(const std::string &path);
    smb2fh *openFileForStreaming(const std::string &path);
    void closeFile(smb2fh *handle);
    size_t readFile(smb2fh *handle, uint8_t *buffer, size_t size);
    bool seekFile(smb2fh *handle, uint64_t offset);
    uint64_t getFileSize(smb2fh *handle);
    bool fileExists(const std::string &path);
    bool isDirectory(const std::string &path);

    // Directory operations
    std::vector<FileInfo> listDirectory(const std::string &path);

    // Optimized streaming operations
    size_t readFileOptimized(smb2fh *handle, uint8_t *buffer, size_t size, uint64_t offset);
    bool setReadAhead(smb2fh *handle, size_t read_ahead_size);

    // NEW: Enhanced read-range operations for VLC-style streaming
    size_t readRange(smb2fh *handle, uint8_t *buffer, size_t buffer_size,
                     uint64_t start_offset, uint64_t end_offset);
    size_t readRangeAsync(smb2fh *handle, uint8_t *buffer, size_t buffer_size,
                          uint64_t start_offset, uint64_t end_offset);
    bool prefetchRange(smb2fh *handle, uint64_t start_offset, uint64_t end_offset);
    bool setStreamingOptions(smb2fh *handle, size_t chunk_size, size_t buffer_size, bool enable_caching);

    // NEW: SMB URL generation for direct VLC streaming
    std::string generateDirectUrl(const std::string &path);
    std::string generateUrlWithCredentials(const std::string &path,
                                           const std::string &username, const std::string &password);
    std::string getConnectionUrl();

    // Information
    std::string getSmbVersion() const;
    std::string getConnectionInfo() const;

private:
    class Impl;
    std::unique_ptr<Impl> pImpl;
};