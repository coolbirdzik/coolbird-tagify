#ifndef SMB_CLIENT_H
#define SMB_CLIENT_H

#include <string>
#include <vector>
#include <memory>
#include <libsmbclient.h>

struct FileInfo
{
    std::string name;
    std::string path;
    uint64_t size;
    uint64_t modified_time;
    bool is_directory;
};

class SmbFileHandleImpl
{
public:
    SmbFileHandleImpl(SMBCFILE *file, SMBCCTX *context);
    ~SmbFileHandleImpl();

    size_t read(uint8_t *buffer, size_t size);
    void seek(uint64_t offset);
    uint64_t getSize();

private:
    SMBCFILE *file_;
    SMBCCTX *context_;
    uint64_t file_size_;
};

class SmbClient
{
public:
    SmbClient();
    ~SmbClient();

    bool connect(const std::string &server, const std::string &share,
                 const std::string &username, const std::string &password,
                 const std::string &domain = "");
    void disconnect();
    bool isConnected() const;

    SmbFileHandleImpl *openFile(const std::string &path);
    void closeFile(SmbFileHandleImpl *handle);
    size_t readFile(SmbFileHandleImpl *handle, uint8_t *buffer, size_t size);
    void seekFile(SmbFileHandleImpl *handle, uint64_t offset);
    uint64_t getFileSize(SmbFileHandleImpl *handle);

    std::vector<FileInfo> listDirectory(const std::string &path);

    bool fileExists(const std::string &path);
    bool isDirectory(const std::string &path);

    // Get SMB2 context for direct access if needed
    smb2_context *getContext() const;

    // SMB version and connection info
    std::string getSmbVersion() const;
    std::string getConnectionInfo() const;

    // Optimized streaming operations
    smb2fh *openFileForStreaming(const std::string &path);
    size_t readFileOptimized(smb2fh *handle, uint8_t *buffer, size_t size, uint64_t offset);
    bool setReadAhead(smb2fh *handle, size_t read_ahead_size);

private:
    class Impl;
    std::unique_ptr<Impl> pImpl;
};

#endif // SMB_CLIENT_H