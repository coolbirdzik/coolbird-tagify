// libsmb2 implementation for SMB client
// This file provides SMB functionality using libsmb2 library

#include "smb_client.h"
#include <smb2/libsmb2.h>
#include <smb2/smb2.h>
#include <cstring>
#include <cstdlib>
#include <iostream>
#include <vector>
#include <memory>
#include <stdexcept>
#include <sstream>
#include <thread>
#include <future>

// PIMPL implementation for libsmb2
class Smb2ClientWrapper::Impl
{
public:
    smb2_context *context;
    std::string server;
    std::string share;
    std::string username;
    std::string password;
    std::string domain;
    bool connected;
    std::string share_url;

    // Streaming options
    size_t chunk_size;
    size_t buffer_size;
    bool enable_caching;

    Impl() : context(nullptr), connected(false), chunk_size(64 * 1024), buffer_size(2 * 1024 * 1024), enable_caching(true)
    {
        // Initialize libsmb2 context
        context = smb2_init_context();
        if (!context)
        {
            throw std::runtime_error("Failed to create SMB2 context");
        }
    }

    ~Impl()
    {
        disconnect();
    }

    void disconnect()
    {
        if (context && connected)
        {
            smb2_disconnect_share(context);
            connected = false;
        }
        if (context)
        {
            smb2_destroy_context(context);
            context = nullptr;
        }
    }

    bool connect(const std::string &server, const std::string &share,
                 const std::string &username, const std::string &password,
                 const std::string &domain)
    {
        if (!context)
        {
            return false;
        }

        // Store connection parameters
        this->server = server;
        this->share = share;
        this->username = username;
        this->password = password;
        this->domain = domain;

        // Set authentication credentials
        smb2_set_user(context, username.c_str());
        smb2_set_password(context, password.c_str());
        if (!domain.empty())
        {
            smb2_set_domain(context, domain.c_str());
        }

        // Build share URL: smb://server/share
        std::ostringstream url_stream;
        url_stream << "smb://" << server << "/" << share;
        share_url = url_stream.str();

        // Connect to the share
        int result = smb2_connect_share(context, share_url.c_str(), nullptr);
        if (result < 0)
        {
            std::cerr << "Failed to connect to SMB share: " << smb2_get_error(context) << std::endl;
            return false;
        }

        connected = true;
        return true;
    }
};

// Constructor and Destructor
Smb2ClientWrapper::Smb2ClientWrapper() : pImpl(std::make_unique<Impl>()) {}

Smb2ClientWrapper::~Smb2ClientWrapper() = default;

// Connection management
bool Smb2ClientWrapper::connect(const std::string &server, const std::string &share,
                                const std::string &username, const std::string &password,
                                const std::string &domain)
{
    return pImpl->connect(server, share, username, password, domain);
}

void Smb2ClientWrapper::disconnect()
{
    pImpl->disconnect();
}

bool Smb2ClientWrapper::isConnected() const
{
    return pImpl->connected;
}

// File operations
smb2fh *Smb2ClientWrapper::openFile(const std::string &path)
{
    if (!pImpl->context || !pImpl->connected)
    {
        return nullptr;
    }

    smb2fh *file_handle = smb2_open(pImpl->context, path.c_str(), O_RDONLY);
    if (!file_handle)
    {
        std::cerr << "Failed to open file: " << path << " - " << smb2_get_error(pImpl->context) << std::endl;
    }
    return file_handle;
}

void Smb2ClientWrapper::closeFile(smb2fh *handle)
{
    if (handle && pImpl->context)
    {
        smb2_close(pImpl->context, handle);
    }
}

size_t Smb2ClientWrapper::readFile(smb2fh *handle, uint8_t *buffer, size_t size)
{
    if (!handle || !buffer || !pImpl->context)
    {
        return 0;
    }

    int bytes_read = smb2_read(pImpl->context, handle, buffer, size);
    return bytes_read > 0 ? static_cast<size_t>(bytes_read) : 0;
}

bool Smb2ClientWrapper::seekFile(smb2fh *handle, uint64_t offset)
{
    if (!handle || !pImpl->context)
    {
        return false;
    }

    int result = smb2_lseek(pImpl->context, handle, offset, SEEK_SET, nullptr);
    return result >= 0;
}

uint64_t Smb2ClientWrapper::getFileSize(smb2fh *handle)
{
    if (!handle || !pImpl->context)
    {
        return 0;
    }

    struct smb2_stat_64 st;
    int result = smb2_fstat(pImpl->context, handle, &st);
    if (result < 0)
    {
        return 0;
    }

    return st.smb2_size;
}

bool Smb2ClientWrapper::fileExists(const std::string &path)
{
    if (!pImpl->context || !pImpl->connected)
    {
        return false;
    }

    struct smb2_stat_64 st;
    int result = smb2_stat(pImpl->context, path.c_str(), &st);
    return result >= 0;
}

bool Smb2ClientWrapper::isDirectory(const std::string &path)
{
    if (!pImpl->context || !pImpl->connected)
    {
        return false;
    }

    struct smb2_stat_64 st;
    int result = smb2_stat(pImpl->context, path.c_str(), &st);
    if (result < 0)
    {
        return false;
    }

    return (st.smb2_type == SMB2_TYPE_DIRECTORY);
}

// Directory operations
std::vector<FileInfo> Smb2ClientWrapper::listDirectory(const std::string &path)
{
    std::vector<FileInfo> files;

    if (!pImpl->context || !pImpl->connected)
    {
        return files;
    }

    smb2dir *dir = smb2_opendir(pImpl->context, path.c_str());
    if (!dir)
    {
        return files;
    }

    struct smb2dirent *entry;
    while ((entry = smb2_readdir(pImpl->context, dir)) != nullptr)
    {
        FileInfo file_info;
        file_info.name = entry->name;
        file_info.path = path + "/" + entry->name;
        file_info.size = entry->st.smb2_size;
        file_info.modified_time = entry->st.smb2_mtime;
        file_info.is_directory = (entry->st.smb2_type == SMB2_TYPE_DIRECTORY);
        files.push_back(file_info);
    }

    smb2_closedir(pImpl->context, dir);
    return files;
}

// Get SMB version information
std::string Smb2ClientWrapper::getSmbVersion() const
{
    if (!pImpl->context || !pImpl->connected)
    {
        return "Unknown";
    }

    // Get dialect information from libsmb2
    uint16_t dialect = smb2_which_dialect(pImpl->context);

    switch (dialect)
    {
    case SMB2_VERSION_0202:
        return "SMB2.0.2";
    case SMB2_VERSION_0210:
        return "SMB2.1";
    case SMB2_VERSION_0300:
        return "SMB3.0";
    case SMB2_VERSION_0302:
        return "SMB3.0.2";
    case SMB2_VERSION_0311:
        return "SMB3.1.1";
    default:
        return "SMB2.x";
    }
}

// Get connection information
std::string Smb2ClientWrapper::getConnectionInfo() const
{
    if (!pImpl->context || !pImpl->connected)
    {
        return "Not connected";
    }

    std::ostringstream info;
    info << "Server: " << pImpl->server;
    info << ", Share: " << pImpl->share;
    info << ", Version: " << getSmbVersion();
    info << ", User: " << pImpl->username;

    return info.str();
}

// Open file optimized for streaming
smb2fh *Smb2ClientWrapper::openFileForStreaming(const std::string &path)
{
    if (!pImpl->context || !pImpl->connected)
    {
        return nullptr;
    }

    // Open with optimized flags for streaming
    smb2fh *file_handle = smb2_open(pImpl->context, path.c_str(), O_RDONLY);
    if (!file_handle)
    {
        std::cerr << "Failed to open file for streaming: " << path << " - " << smb2_get_error(pImpl->context) << std::endl;
        return nullptr;
    }

    // Set read ahead for better streaming performance
    setReadAhead(file_handle, 2 * 1024 * 1024); // 2MB read ahead for better performance

    return file_handle;
}

// Read file with offset optimization
size_t Smb2ClientWrapper::readFileOptimized(smb2fh *handle, uint8_t *buffer, size_t size, uint64_t offset)
{
    if (!handle || !buffer || !pImpl->context)
    {
        return 0;
    }

    // Seek to the specified offset
    if (!seekFile(handle, offset))
    {
        return 0;
    }

    // Read the data
    int bytes_read = smb2_read(pImpl->context, handle, buffer, size);
    return bytes_read > 0 ? static_cast<size_t>(bytes_read) : 0;
}

// Set read ahead buffer size
bool Smb2ClientWrapper::setReadAhead(smb2fh *handle, size_t read_ahead_size)
{
    if (!handle || !pImpl->context)
    {
        return false;
    }

    // Note: libsmb2 doesn't have direct read-ahead control
    // This is a placeholder for future optimization
    // For now, we'll rely on the OS and network layer optimizations

    return true;
}

// NEW: Enhanced read-range operations for VLC-style streaming
size_t Smb2ClientWrapper::readRange(smb2fh *handle, uint8_t *buffer, size_t buffer_size,
                                    uint64_t start_offset, uint64_t end_offset)
{
    if (!handle || !buffer || !pImpl->context)
    {
        return 0;
    }

    // Calculate the range size
    uint64_t range_size = end_offset - start_offset;
    if (range_size > buffer_size)
    {
        range_size = buffer_size;
    }

    // Seek to start offset
    if (!seekFile(handle, start_offset))
    {
        return 0;
    }

    // Read the range
    int bytes_read = smb2_read(pImpl->context, handle, buffer, range_size);
    return bytes_read > 0 ? static_cast<size_t>(bytes_read) : 0;
}

size_t Smb2ClientWrapper::readRangeAsync(smb2fh *handle, uint8_t *buffer, size_t buffer_size,
                                         uint64_t start_offset, uint64_t end_offset)
{
    // For now, implement as synchronous read
    // In a real implementation, this would use async I/O
    return readRange(handle, buffer, buffer_size, start_offset, end_offset);
}

bool Smb2ClientWrapper::prefetchRange(smb2fh *handle, uint64_t start_offset, uint64_t end_offset)
{
    if (!handle || !pImpl->context)
    {
        return false;
    }

    // For now, just seek to the start offset to prepare for reading
    // In a real implementation, this would trigger background prefetching
    return seekFile(handle, start_offset);
}

bool Smb2ClientWrapper::setStreamingOptions(smb2fh *handle, size_t chunk_size, size_t buffer_size, bool enable_caching)
{
    if (!handle || !pImpl->context)
    {
        return false;
    }

    // Store streaming options
    pImpl->chunk_size = chunk_size;
    pImpl->buffer_size = buffer_size;
    pImpl->enable_caching = enable_caching;

    return true;
}

// NEW: SMB URL generation for direct VLC streaming
std::string Smb2ClientWrapper::generateDirectUrl(const std::string &path)
{
    if (!pImpl->connected)
    {
        return "";
    }

    std::ostringstream url;
    url << "smb://" << pImpl->server << "/" << pImpl->share;

    // Add path if provided
    if (!path.empty())
    {
        if (path[0] != '/')
        {
            url << "/";
        }
        url << path;
    }

    return url.str();
}

std::string Smb2ClientWrapper::generateUrlWithCredentials(const std::string &path,
                                                          const std::string &username, const std::string &password)
{
    if (!pImpl->connected)
    {
        return "";
    }

    std::ostringstream url;
    url << "smb://" << username << ":" << password << "@" << pImpl->server << "/" << pImpl->share;

    // Add path if provided
    if (!path.empty())
    {
        if (path[0] != '/')
        {
            url << "/";
        }
        url << path;
    }

    return url.str();
}

std::string Smb2ClientWrapper::getConnectionUrl()
{
    if (!pImpl->connected)
    {
        return "";
    }

    return pImpl->share_url;
}