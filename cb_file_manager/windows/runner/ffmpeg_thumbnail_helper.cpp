#include "ffmpeg_thumbnail_helper.h"
#include "fc_native_video_thumbnail_plugin.h"

#include <atlbase.h>
#include <atlimage.h>
#include <codecvt>
#include <locale>
#include <stdexcept>
#include <vector>

namespace fc_native_video_thumbnail
{

    // Forward declaration of GetEncoderClsid from fc_native_video_thumbnail_plugin.cpp
    extern int GetEncoderClsid(const WCHAR *format, CLSID *pClsid);

    std::string FFmpegThumbnailHelper::WideToUtf8(const wchar_t *wide)
    {
        if (!wide)
            return "";

        int size_needed = WideCharToMultiByte(CP_UTF8, 0, wide, -1, nullptr, 0, nullptr, nullptr);
        if (size_needed <= 0)
            return "";

        std::string utf8(size_needed, 0);
        WideCharToMultiByte(CP_UTF8, 0, wide, -1, &utf8[0], size_needed, nullptr, nullptr);
        utf8.resize(size_needed - 1); // Remove the null terminator
        return utf8;
    }

    std::string FFmpegThumbnailHelper::ExtractThumbnail(
        const wchar_t *srcFile,
        const wchar_t *destFile,
        int width,
        REFGUID format,
        int timeSeconds,
        int quality)
    {

        const std::string srcFileUtf8 = WideToUtf8(srcFile);
        AVFormatContext *formatContext = nullptr;

        try
        {
            // Open the input file
            if (avformat_open_input(&formatContext, srcFileUtf8.c_str(), nullptr, nullptr) != 0)
            {
                return "Failed to open input file";
            }

            // Retrieve stream information
            if (avformat_find_stream_info(formatContext, nullptr) < 0)
            {
                avformat_close_input(&formatContext);
                return "Failed to find stream info";
            }

            // Find the first video stream
            int videoStreamIndex = -1;
            for (unsigned int i = 0; i < formatContext->nb_streams; i++)
            {
                if (formatContext->streams[i]->codecpar->codec_type == AVMEDIA_TYPE_VIDEO)
                {
                    videoStreamIndex = i;
                    break;
                }
            }

            if (videoStreamIndex == -1)
            {
                avformat_close_input(&formatContext);
                return "No video stream found";
            }

            // Get the codec parameters
            AVCodecParameters *codecParams = formatContext->streams[videoStreamIndex]->codecpar;

            // Find the decoder
            const AVCodec *codec = avcodec_find_decoder(codecParams->codec_id);
            if (!codec)
            {
                avformat_close_input(&formatContext);
                return "Unsupported codec";
            }

            // Create codec context
            AVCodecContext *codecContext = avcodec_alloc_context3(codec);
            if (!codecContext)
            {
                avformat_close_input(&formatContext);
                return "Failed to allocate codec context";
            }

            // Copy parameters to context
            if (avcodec_parameters_to_context(codecContext, codecParams) < 0)
            {
                avcodec_free_context(&codecContext);
                avformat_close_input(&formatContext);
                return "Failed to copy codec parameters to context";
            }

            // Open the codec
            if (avcodec_open2(codecContext, codec, nullptr) < 0)
            {
                avcodec_free_context(&codecContext);
                avformat_close_input(&formatContext);
                return "Failed to open codec";
            }

            // Calculate the target timestamp
            int64_t duration = formatContext->duration > 0 ? formatContext->duration / AV_TIME_BASE : 0;
            if (timeSeconds < 0 || (duration > 0 && static_cast<int64_t>(timeSeconds) > duration))
            {
                // Use safe casting when converting from int64_t to int
                timeSeconds = duration > 0 ? static_cast<int>(duration / 3) : 0; // Default to 1/3 through the video
            }

            // Use explicit casting to avoid int64_t to int conversion warnings
            int64_t seekTarget = static_cast<int64_t>(timeSeconds) * AV_TIME_BASE;

            // Seek to the target timestamp
            if (av_seek_frame(formatContext, -1, seekTarget, AVSEEK_FLAG_BACKWARD) < 0)
            {
                avcodec_free_context(&codecContext);
                avformat_close_input(&formatContext);
                return "Failed to seek to timestamp";
            }

            // Read frames until we find a video frame
            AVPacket *packet = av_packet_alloc();
            AVFrame *frame = av_frame_alloc();
            bool frameFound = false;

            while (av_read_frame(formatContext, packet) >= 0)
            {
                if (packet->stream_index == videoStreamIndex)
                {
                    // Send the packet to the decoder
                    int sendResult = avcodec_send_packet(codecContext, packet);
                    if (sendResult == 0)
                    {
                        // Get decoded frame
                        int receiveResult = avcodec_receive_frame(codecContext, frame);
                        if (receiveResult == 0)
                        {
                            // We found a valid video frame
                            frameFound = true;
                            break;
                        }
                    }
                }
                av_packet_unref(packet);

                // Limit the number of frames we search to avoid infinite loop
                if (av_q2d(formatContext->streams[videoStreamIndex]->time_base) * packet->pts >
                    timeSeconds + 10)
                {
                    break;
                }
            }

            if (!frameFound)
            {
                av_frame_free(&frame);
                av_packet_free(&packet);
                avcodec_free_context(&codecContext);
                avformat_close_input(&formatContext);
                return "Failed to find video frame";
            }

            // Frame found, convert it using swscale
            int originalWidth = codecContext->width;
            int originalHeight = codecContext->height;

            // Smart resolution calculation based on original video resolution
            int outputWidth, outputHeight;

            if (width <= 0)
            {
                // Use original resolution
                outputWidth = originalWidth;
                outputHeight = originalHeight;
            }
            else if (width < 0)
            {
                // Use percentage of original (e.g., -75 = 75% of original)
                float percentage = abs(width) / 100.0f;
                outputWidth = (int)(originalWidth * percentage);
                outputHeight = (int)(originalHeight * percentage);
            }
            else
            {
                // Fixed width with intelligent scaling for high-resolution content
                if (originalWidth > 1920 && width < originalWidth / 2)
                {
                    // For 4K+ videos, ensure at least 50% of original to preserve detail
                    outputWidth = originalWidth / 2;
                    outputHeight = originalHeight / 2;
                }
                else if (originalWidth > 1280 && width < originalWidth / 3)
                {
                    // For HD videos, ensure at least 33% of original
                    outputWidth = originalWidth / 3;
                    outputHeight = originalHeight / 3;
                }
                else
                {
                    // Standard scaling - maintain aspect ratio
                    outputWidth = width;
                    outputHeight = (int)(((float)originalHeight / originalWidth) * width);
                }
            }

            // Safety checks
            if (outputWidth <= 0)
                outputWidth = originalWidth;
            if (outputHeight <= 0)
                outputHeight = originalHeight;

            // Create frame for RGB output
            AVFrame *rgbFrame = av_frame_alloc();
            if (!rgbFrame)
            {
                av_frame_free(&frame);
                av_packet_free(&packet);
                avcodec_free_context(&codecContext);
                avformat_close_input(&formatContext);
                return "Failed to allocate RGB frame";
            }

            // Allocate buffer for RGB frame
            int bufferSize = av_image_get_buffer_size(AV_PIX_FMT_RGB24, outputWidth, outputHeight, 1);
            uint8_t *buffer = (uint8_t *)av_malloc(bufferSize);
            if (!buffer)
            {
                av_frame_free(&rgbFrame);
                av_frame_free(&frame);
                av_packet_free(&packet);
                avcodec_free_context(&codecContext);
                avformat_close_input(&formatContext);
                return "Failed to allocate RGB buffer";
            }

            // Set up RGB frame
            av_image_fill_arrays(rgbFrame->data, rgbFrame->linesize, buffer,
                                 AV_PIX_FMT_RGB24, outputWidth, outputHeight, 1);

            // Set up swscale context for color conversion and scaling with high quality Lanczos algorithm
            SwsContext *swsContext = sws_getContext(
                originalWidth, originalHeight, codecContext->pix_fmt,
                outputWidth, outputHeight, AV_PIX_FMT_RGB24,
                SWS_LANCZOS, nullptr, nullptr, nullptr);

            if (!swsContext)
            {
                av_free(buffer);
                av_frame_free(&rgbFrame);
                av_frame_free(&frame);
                av_packet_free(&packet);
                avcodec_free_context(&codecContext);
                avformat_close_input(&formatContext);
                return "Failed to create scaling context";
            }

            // Perform the conversion
            sws_scale(swsContext, frame->data, frame->linesize, 0, originalHeight,
                      rgbFrame->data, rgbFrame->linesize);

            // Save the image
            bool saveResult = SaveImage(rgbFrame, outputWidth, outputHeight, destFile, format, quality);

            // Clean up
            sws_freeContext(swsContext);
            av_free(buffer);
            av_frame_free(&rgbFrame);
            av_frame_free(&frame);
            av_packet_free(&packet);
            avcodec_free_context(&codecContext);
            avformat_close_input(&formatContext);

            if (!saveResult)
            {
                return "Failed to save image";
            }

            return ""; // Success
        }
        catch (const std::exception &e)
        {
            if (formatContext)
            {
                avformat_close_input(&formatContext);
            }
            return std::string("Exception: ") + e.what();
        }
        catch (...)
        {
            if (formatContext)
            {
                avformat_close_input(&formatContext);
            }
            return "Unknown exception occurred";
        }
    }

    std::string FFmpegThumbnailHelper::ExtractThumbnailAtPercentage(
        const wchar_t *srcFile,
        const wchar_t *destFile,
        int width,
        REFGUID format,
        double percentage,
        int quality)
    {
        const std::string srcFileUtf8 = WideToUtf8(srcFile);
        AVFormatContext *formatContext = nullptr;
        AVCodecContext *codecContext = nullptr;
        AVPacket *packet = nullptr;
        AVFrame *frame = nullptr;
        AVFrame *rgbFrame = nullptr;
        uint8_t *buffer = nullptr;
        SwsContext *swsContext = nullptr;

        try
        {
            // Optimized format open options for faster probing
            AVDictionary *opts = nullptr;
            av_dict_set(&opts, "analyzeduration", "1000000", 0); // 1 second max analyze
            av_dict_set(&opts, "probesize", "1000000", 0);       // 1MB max probe size

            // Open the input file
            if (avformat_open_input(&formatContext, srcFileUtf8.c_str(), nullptr, &opts) != 0)
            {
                av_dict_free(&opts);
                return "Failed to open input file";
            }
            av_dict_free(&opts);

            // Retrieve stream information with optimized settings
            AVDictionary *streamOpts = nullptr;
            av_dict_set(&streamOpts, "max_analyze_duration", "1000000", 0);
            if (avformat_find_stream_info(formatContext, nullptr) < 0)
            {
                av_dict_free(&streamOpts);
                avformat_close_input(&formatContext);
                return "Failed to find stream info";
            }
            av_dict_free(&streamOpts);

            // Find the first video stream
            int videoStreamIndex = -1;
            for (unsigned int i = 0; i < formatContext->nb_streams; i++)
            {
                if (formatContext->streams[i]->codecpar->codec_type == AVMEDIA_TYPE_VIDEO)
                {
                    videoStreamIndex = i;
                    break;
                }
            }

            if (videoStreamIndex == -1)
            {
                avformat_close_input(&formatContext);
                return "No video stream found";
            }

            // Get duration directly from format context (no second file open!)
            double durationSeconds = -1.0;
            if (formatContext->duration != AV_NOPTS_VALUE)
            {
                durationSeconds = static_cast<double>(formatContext->duration) / AV_TIME_BASE;
            }
            else
            {
                // Try to get duration from video stream
                AVStream *stream = formatContext->streams[videoStreamIndex];
                if (stream->duration != AV_NOPTS_VALUE)
                {
                    durationSeconds = static_cast<double>(stream->duration) * av_q2d(stream->time_base);
                }
            }

            // Calculate target timestamp from percentage
            int timeSeconds = 5; // default fallback
            if (durationSeconds > 0)
            {
                double validPercentage = percentage;
                if (validPercentage < 0.0)
                    validPercentage = 0.0;
                if (validPercentage > 100.0)
                    validPercentage = 100.0;

                // Clamp to safe range (10% to 90% of video to avoid black frames)
                if (validPercentage < 10.0)
                    validPercentage = 10.0;
                if (validPercentage > 90.0)
                    validPercentage = 90.0;

                timeSeconds = static_cast<int>((validPercentage / 100.0) * durationSeconds);

                // Ensure within safe bounds
                int minTime = 5;
                int maxTime = static_cast<int>(durationSeconds) - 5;
                if (maxTime < minTime)
                    maxTime = static_cast<int>(durationSeconds / 2);
                if (timeSeconds < minTime)
                    timeSeconds = minTime;
                if (timeSeconds > maxTime)
                    timeSeconds = maxTime;
            }

            // Get the codec parameters
            AVCodecParameters *codecParams = formatContext->streams[videoStreamIndex]->codecpar;

            // Find the decoder
            const AVCodec *codec = avcodec_find_decoder(codecParams->codec_id);
            if (!codec)
            {
                avformat_close_input(&formatContext);
                return "Unsupported codec";
            }

            // Create codec context
            codecContext = avcodec_alloc_context3(codec);
            if (!codecContext)
            {
                avformat_close_input(&formatContext);
                return "Failed to allocate codec context";
            }

            // Copy parameters to context
            if (avcodec_parameters_to_context(codecContext, codecParams) < 0)
            {
                avcodec_free_context(&codecContext);
                avformat_close_input(&formatContext);
                return "Failed to copy codec parameters to context";
            }

            // Enable multi-threaded decoding for faster extraction
            codecContext->thread_count = 4;
            codecContext->thread_type = FF_THREAD_FRAME | FF_THREAD_SLICE;

            // Open the codec
            if (avcodec_open2(codecContext, codec, nullptr) < 0)
            {
                avcodec_free_context(&codecContext);
                avformat_close_input(&formatContext);
                return "Failed to open codec";
            }

            // Seek to the target timestamp
            int64_t seekTarget = static_cast<int64_t>(timeSeconds) * AV_TIME_BASE;
            if (av_seek_frame(formatContext, -1, seekTarget, AVSEEK_FLAG_BACKWARD) < 0)
            {
                avcodec_free_context(&codecContext);
                avformat_close_input(&formatContext);
                return "Failed to seek to timestamp";
            }

            // Flush decoder buffers after seek
            avcodec_flush_buffers(codecContext);

            // Read frames until we find a video frame
            packet = av_packet_alloc();
            frame = av_frame_alloc();
            bool frameFound = false;

            while (av_read_frame(formatContext, packet) >= 0)
            {
                if (packet->stream_index == videoStreamIndex)
                {
                    int sendResult = avcodec_send_packet(codecContext, packet);
                    if (sendResult == 0)
                    {
                        int receiveResult = avcodec_receive_frame(codecContext, frame);
                        if (receiveResult == 0)
                        {
                            frameFound = true;
                            break;
                        }
                    }
                }
                av_packet_unref(packet);

                // Limit search to avoid infinite loop
                if (av_q2d(formatContext->streams[videoStreamIndex]->time_base) * packet->pts >
                    timeSeconds + 10)
                {
                    break;
                }
            }

            if (!frameFound)
            {
                av_frame_free(&frame);
                av_packet_free(&packet);
                avcodec_free_context(&codecContext);
                avformat_close_input(&formatContext);
                return "Failed to find video frame";
            }

            // Frame found, convert it using swscale
            int originalWidth = codecContext->width;
            int originalHeight = codecContext->height;

            // Calculate output dimensions
            int outputWidth, outputHeight;

            if (width <= 0)
            {
                outputWidth = originalWidth;
                outputHeight = originalHeight;
            }
            else
            {
                if (originalWidth > 1920 && width < originalWidth / 2)
                {
                    outputWidth = originalWidth / 2;
                    outputHeight = originalHeight / 2;
                }
                else if (originalWidth > 1280 && width < originalWidth / 3)
                {
                    outputWidth = originalWidth / 3;
                    outputHeight = originalHeight / 3;
                }
                else
                {
                    outputWidth = width;
                    outputHeight = (int)(((float)originalHeight / originalWidth) * width);
                }
            }

            if (outputWidth <= 0)
                outputWidth = originalWidth;
            if (outputHeight <= 0)
                outputHeight = originalHeight;

            // Create frame for RGB output
            rgbFrame = av_frame_alloc();
            if (!rgbFrame)
            {
                av_frame_free(&frame);
                av_packet_free(&packet);
                avcodec_free_context(&codecContext);
                avformat_close_input(&formatContext);
                return "Failed to allocate RGB frame";
            }

            // Allocate buffer for RGB frame
            int bufferSize = av_image_get_buffer_size(AV_PIX_FMT_RGB24, outputWidth, outputHeight, 1);
            buffer = (uint8_t *)av_malloc(bufferSize);
            if (!buffer)
            {
                av_frame_free(&rgbFrame);
                av_frame_free(&frame);
                av_packet_free(&packet);
                avcodec_free_context(&codecContext);
                avformat_close_input(&formatContext);
                return "Failed to allocate RGB buffer";
            }

            av_image_fill_arrays(rgbFrame->data, rgbFrame->linesize, buffer,
                                 AV_PIX_FMT_RGB24, outputWidth, outputHeight, 1);

            // Use fast bilinear scaling for better performance
            swsContext = sws_getContext(
                originalWidth, originalHeight, codecContext->pix_fmt,
                outputWidth, outputHeight, AV_PIX_FMT_RGB24,
                SWS_FAST_BILINEAR, nullptr, nullptr, nullptr);

            if (!swsContext)
            {
                av_free(buffer);
                av_frame_free(&rgbFrame);
                av_frame_free(&frame);
                av_packet_free(&packet);
                avcodec_free_context(&codecContext);
                avformat_close_input(&formatContext);
                return "Failed to create scaling context";
            }

            // Perform the conversion
            sws_scale(swsContext, frame->data, frame->linesize, 0, originalHeight,
                      rgbFrame->data, rgbFrame->linesize);

            // Save the image
            bool saveResult = SaveImage(rgbFrame, outputWidth, outputHeight, destFile, format, quality);

            // Clean up
            sws_freeContext(swsContext);
            av_free(buffer);
            av_frame_free(&rgbFrame);
            av_frame_free(&frame);
            av_packet_free(&packet);
            avcodec_free_context(&codecContext);
            avformat_close_input(&formatContext);

            if (!saveResult)
            {
                return "Failed to save image";
            }

            return ""; // Success
        }
        catch (const std::exception &e)
        {
            if (swsContext)
                sws_freeContext(swsContext);
            if (buffer)
                av_free(buffer);
            if (rgbFrame)
                av_frame_free(&rgbFrame);
            if (frame)
                av_frame_free(&frame);
            if (packet)
                av_packet_free(&packet);
            if (codecContext)
                avcodec_free_context(&codecContext);
            if (formatContext)
                avformat_close_input(&formatContext);
            return std::string("Exception: ") + e.what();
        }
        catch (...)
        {
            if (swsContext)
                sws_freeContext(swsContext);
            if (buffer)
                av_free(buffer);
            if (rgbFrame)
                av_frame_free(&rgbFrame);
            if (frame)
                av_frame_free(&frame);
            if (packet)
                av_packet_free(&packet);
            if (codecContext)
                avcodec_free_context(&codecContext);
            if (formatContext)
                avformat_close_input(&formatContext);
            return "Unknown exception occurred";
        }
    }

    bool FFmpegThumbnailHelper::SaveImage(
        AVFrame *frame,
        int width,
        int height,
        const wchar_t *destFile,
        REFGUID format,
        int quality)
    {

        // Initialize GDI+
        Gdiplus::GdiplusStartupInput gdiplusStartupInput;
        ULONG_PTR gdiplusToken;
        Gdiplus::GdiplusStartup(&gdiplusToken, &gdiplusStartupInput, nullptr);

        bool result = false;

        try
        {
            // Create a GDI+ bitmap
            Gdiplus::Bitmap bitmap(width, height, PixelFormat24bppRGB);

            // Lock the bitmap for writing
            Gdiplus::BitmapData bitmapData;
            Gdiplus::Rect rect(0, 0, width, height);
            bitmap.LockBits(&rect, Gdiplus::ImageLockModeWrite, PixelFormat24bppRGB, &bitmapData);

            // Copy pixel data from FFmpeg frame to GDI+ bitmap
            for (int y = 0; y < height; y++)
            {
                uint8_t *srcLine = frame->data[0] + y * frame->linesize[0];
                uint8_t *dstLine = (uint8_t *)bitmapData.Scan0 + y * bitmapData.Stride;

                for (int x = 0; x < width; x++)
                {
                    // RGB24 format: R, G, B
                    dstLine[x * 3 + 2] = srcLine[x * 3 + 0]; // R
                    dstLine[x * 3 + 1] = srcLine[x * 3 + 1]; // G
                    dstLine[x * 3 + 0] = srcLine[x * 3 + 2]; // B
                }
            }

            // Unlock the bitmap
            bitmap.UnlockBits(&bitmapData);

            // Get encoder CLSID
            CLSID encoderClsid;
            int encoderIndex = -1;

            if (format == Gdiplus::ImageFormatPNG)
            {
                encoderIndex = GetEncoderClsid(L"image/png", &encoderClsid);
            }
            else
            {
                encoderIndex = GetEncoderClsid(L"image/jpeg", &encoderClsid);
            }

            if (encoderIndex < 0)
            {
                throw std::runtime_error("Failed to find image encoder");
            }

            // Set JPEG quality if needed (higher value = better quality)
            Gdiplus::EncoderParameters encoderParams;
            ULONG qualityValue = quality;

            if (format == Gdiplus::ImageFormatJPEG)
            {
                encoderParams.Count = 1;
                encoderParams.Parameter[0].Guid = Gdiplus::EncoderQuality;
                encoderParams.Parameter[0].Type = Gdiplus::EncoderParameterValueTypeLong;
                encoderParams.Parameter[0].NumberOfValues = 1;
                encoderParams.Parameter[0].Value = &qualityValue;

                result = (bitmap.Save(destFile, &encoderClsid, &encoderParams) == Gdiplus::Ok);
            }
            else
            {
                result = (bitmap.Save(destFile, &encoderClsid) == Gdiplus::Ok);
            }
        }
        catch (const std::exception &)
        {
            result = false;
        }

        // Shutdown GDI+
        Gdiplus::GdiplusShutdown(gdiplusToken);

        return result;
    }

    double FFmpegThumbnailHelper::GetVideoDuration(const wchar_t *srcFile)
    {
        const std::string srcFileUtf8 = WideToUtf8(srcFile);
        AVFormatContext *formatContext = nullptr;

        try
        {
            // Open the input file
            if (avformat_open_input(&formatContext, srcFileUtf8.c_str(), nullptr, nullptr) != 0)
            {
                return -1.0;
            }

            // Retrieve stream information
            if (avformat_find_stream_info(formatContext, nullptr) < 0)
            {
                avformat_close_input(&formatContext);
                return -1.0;
            }

            // Get duration from format context (in AV_TIME_BASE units)
            double durationSeconds = -1.0;

            if (formatContext->duration != AV_NOPTS_VALUE)
            {
                durationSeconds = static_cast<double>(formatContext->duration) / AV_TIME_BASE;
            }
            else
            {
                // Try to get duration from the first video stream
                for (unsigned int i = 0; i < formatContext->nb_streams; i++)
                {
                    AVStream *stream = formatContext->streams[i];
                    if (stream->codecpar->codec_type == AVMEDIA_TYPE_VIDEO)
                    {
                        if (stream->duration != AV_NOPTS_VALUE)
                        {
                            // Convert from stream time base to seconds
                            durationSeconds = static_cast<double>(stream->duration) *
                                              av_q2d(stream->time_base);
                        }
                        break;
                    }
                }
            }

            avformat_close_input(&formatContext);
            return durationSeconds;
        }
        catch (const std::exception &)
        {
            if (formatContext)
            {
                avformat_close_input(&formatContext);
            }
            return -1.0;
        }
    }

} // namespace fc_native_video_thumbnail