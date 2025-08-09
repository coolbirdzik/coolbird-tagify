#ifndef SMB_CLIENT_H
#define SMB_CLIENT_H

#include <string>
#include <vector>
#include <memory>
#include <cstdint>

// Forward declarations for libsmb2
struct smb2_context;
struct smb2fh;

struct FileInfo {
    std::string name;
    std::string path;
    uint64_t size;
    uint64_t modified_time;
    bool is_directory;
};

class Smb2ClientWrapper {
public:
    Smb2ClientWrapper();
    ~Smb2ClientWrapper();
    
    // Connection management
    bool connect(const std::string& server, const std::string& share,
                const std::string& username, const std::string& password,
                const std::string& domain = "");
    void disconnect();
    bool isConnected() const;
    
    // File operations
    smb2fh* openFile(const std::string& path);
    void closeFile(smb2fh* handle);
    size_t readFile(smb2fh* handle, uint8_t* buffer, size_t size);
    bool seekFile(smb2fh* handle, uint64_t offset);
    uint64_t getFileSize(smb2fh* handle);
    
    // Directory operations
    std::vector<FileInfo> listDirectory(const std::string& path);
    
    // Utility functions
    bool fileExists(const std::string& path);
    bool directoryExists(const std::string& path);
    
    // Get SMB2 context for direct access if needed
    smb2_context* getContext() const;
    
private:
    class Impl;
    std::unique_ptr<Impl> pImpl;
};

// Alias for backward compatibility
using SmbClient = Smb2ClientWrapper;

#endif // SMB_CLIENT_H