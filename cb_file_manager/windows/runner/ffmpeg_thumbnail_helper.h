#ifndef FFMPEG_THUMBNAIL_HELPER_H_
#define FFMPEG_THUMBNAIL_HELPER_H_

extern "C"
{
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libavutil/imgutils.h>
#include <libswscale/swscale.h>
}

#include <string>
#include <windows.h>
#include <gdiplus.h>

namespace fc_native_video_thumbnail
{

    class FFmpegThumbnailHelper
    {
    public:
        // Extract a thumbnail from a video at the specified timestamp
        static std::string ExtractThumbnail(
            const wchar_t *srcFile,
            const wchar_t *destFile,
            int width,
            REFGUID format,
            int timeSeconds,
            int quality = 95);

        // Extract thumbnail at a percentage of video duration (single file open)
        // This is more efficient than calling GetVideoDuration + ExtractThumbnail separately
        // percentage: 0.0 to 100.0
        static std::string ExtractThumbnailAtPercentage(
            const wchar_t *srcFile,
            const wchar_t *destFile,
            int width,
            REFGUID format,
            double percentage,
            int quality = 95);

        // Get video duration in seconds using FFmpeg
        // Returns -1 on error
        static double GetVideoDuration(const wchar_t *srcFile);

    private:
        // Convert UTF-16 to UTF-8
        static std::string WideToUtf8(const wchar_t *wide);

        // Convert image format in memory
        static bool SaveImage(
            AVFrame *frame,
            int width,
            int height,
            const wchar_t *destFile,
            REFGUID format,
            int quality = 95);
    };

} // namespace fc_native_video_thumbnail

#endif // FFMPEG_THUMBNAIL_HELPER_H_