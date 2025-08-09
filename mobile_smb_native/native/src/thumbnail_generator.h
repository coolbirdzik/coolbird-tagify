#ifndef THUMBNAIL_GENERATOR_H
#define THUMBNAIL_GENERATOR_H

#include <string>
#include <vector>
#include <memory>

extern "C" {
#include <libavformat/avformat.h>
#include <libavcodec/avcodec.h>
#include <libavutil/avutil.h>
#include <libavutil/imgutils.h>
#include <libswscale/swscale.h>
}

class SmbClient;

struct ThumbnailData {
    uint8_t* data;
    size_t size;
    int width;
    int height;
    
    ThumbnailData() : data(nullptr), size(0), width(0), height(0) {}
    ~ThumbnailData() {
        if (data) {
            delete[] data;
        }
    }
    
    // Move constructor
    ThumbnailData(ThumbnailData&& other) noexcept
        : data(other.data), size(other.size), width(other.width), height(other.height) {
        other.data = nullptr;
        other.size = 0;
        other.width = 0;
        other.height = 0;
    }
    
    // Move assignment
    ThumbnailData& operator=(ThumbnailData&& other) noexcept {
        if (this != &other) {
            if (data) {
                delete[] data;
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
    ThumbnailData(const ThumbnailData&) = delete;
    ThumbnailData& operator=(const ThumbnailData&) = delete;
};

class ThumbnailGenerator {
public:
    ThumbnailGenerator();
    ~ThumbnailGenerator();
    
    // Generate thumbnail from SMB file
    ThumbnailData generateFromSmbFile(SmbClient* client, const std::string& path, 
                                     int target_width, int target_height);
    
    // Generate thumbnail from image file
    ThumbnailData generateImageThumbnail(const uint8_t* data, size_t data_size,
                                        int target_width, int target_height);
    
    // Generate thumbnail from video file
    ThumbnailData generateVideoThumbnail(SmbClient* client, const std::string& path,
                                        int target_width, int target_height,
                                        double timestamp_seconds = 5.0);
    
private:
    bool initialized_;
    
    // Helper methods
    bool isImageFile(const std::string& path);
    bool isVideoFile(const std::string& path);
    std::string getFileExtension(const std::string& path);
    
    // FFmpeg helpers
    ThumbnailData extractVideoFrame(AVFormatContext* format_ctx, AVCodecContext* codec_ctx,
                                   int video_stream_index, double timestamp_seconds,
                                   int target_width, int target_height);
    
    ThumbnailData convertFrameToJpeg(AVFrame* frame, int target_width, int target_height);
    
    // Custom IO context for SMB streaming
    struct SmbIOContext {
        SmbClient* client;
        std::string path;
        void* file_handle;
        uint8_t* buffer;
        size_t buffer_size;
        uint64_t position;
        uint64_t file_size;
    };
    
    static int smbReadPacket(void* opaque, uint8_t* buf, int buf_size);
    static int64_t smbSeek(void* opaque, int64_t offset, int whence);
    
    AVIOContext* createSmbIOContext(SmbClient* client, const std::string& path);
    void freeSmbIOContext(AVIOContext* io_ctx);
};

#endif // THUMBNAIL_GENERATOR_H