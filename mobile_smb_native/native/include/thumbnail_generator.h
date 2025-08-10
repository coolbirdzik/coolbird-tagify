#ifndef THUMBNAIL_GENERATOR_H
#define THUMBNAIL_GENERATOR_H

#include <string>
#include <memory>
#include <cstdint>

class Smb2ClientWrapper;
using SmbClient = Smb2ClientWrapper;

struct ThumbnailData
{
    uint8_t *data;
    size_t size;
    int width;
    int height;

    ThumbnailData() : data(nullptr), size(0), width(0), height(0) {}

    ~ThumbnailData()
    {
        if (data)
        {
            free(data);
            data = nullptr;
        }
    }

    // Move constructor
    ThumbnailData(ThumbnailData &&other) noexcept
        : data(other.data), size(other.size), width(other.width), height(other.height)
    {
        other.data = nullptr;
        other.size = 0;
        other.width = 0;
        other.height = 0;
    }

    // Move assignment
    ThumbnailData &operator=(ThumbnailData &&other) noexcept
    {
        if (this != &other)
        {
            if (data)
            {
                free(data);
            }
            data = other.data;
            size = other.size;
            width = other.width;
            height = other.height;

            other.data = nullptr;
            other.size = 0;
            other.width = 0;
            other.height = 0;
        }
        return *this;
    }

    // Delete copy constructor and assignment
    ThumbnailData(const ThumbnailData &) = delete;
    ThumbnailData &operator=(const ThumbnailData &) = delete;
};

class ThumbnailGenerator
{
public:
    ThumbnailGenerator();
    ~ThumbnailGenerator();

    // Generate thumbnail from SMB file
    ThumbnailData generateFromSmbFile(SmbClient *client, const std::string &path,
                                      int target_width = 200, int target_height = 200);

    // Generate thumbnail from local file (for testing)
    ThumbnailData generateFromLocalFile(const std::string &path,
                                        int target_width = 200, int target_height = 200);

    // Check if file type is supported for thumbnail generation
    bool isSupported(const std::string &file_extension);

private:
    class Impl;
    std::unique_ptr<Impl> pImpl;
};

#endif // THUMBNAIL_GENERATOR_H