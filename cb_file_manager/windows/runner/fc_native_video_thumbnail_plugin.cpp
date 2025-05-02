#include "fc_native_video_thumbnail_plugin.h"
#include "ffmpeg_thumbnail_helper.h"

// This must be included before many other Windows headers.
#include <atlimage.h>
#include <comdef.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>
#include <gdiplus.h>
#include <gdiplusimaging.h>
#include <shlwapi.h>
#include <thumbcache.h>
#include <wincodec.h>
#include <windows.h>
#include <wingdi.h>
// MediaFoundation headers for timestamp-based extraction
#include <mfapi.h>
#include <mfidl.h>
#include <mfreadwrite.h>
#include <propvarutil.h>

#include <codecvt>
#include <iostream>
#include <locale>
#include <memory>
#include <sstream>
#include <string>

const std::string kGetThumbnailFailedExtraction = "Failed extraction";

// Need to link with these libraries for MediaFoundation
#pragma comment(lib, "mfplat.lib")
#pragma comment(lib, "mfuuid.lib")
#pragma comment(lib, "mfreadwrite.lib")
#pragma comment(lib, "propsys.lib")

namespace fc_native_video_thumbnail {

const flutter::EncodableValue* ValueOrNull(const flutter::EncodableMap& map, const char* key) {
  auto it = map.find(flutter::EncodableValue(key));
  if (it == map.end()) {
    return nullptr;
  }
  return &(it->second);
}

std::optional<int64_t> GetInt64ValueOrNull(const flutter::EncodableMap& map,
                                           const char* key) {
  auto value = ValueOrNull(map, key);
  if (!value) {
    return std::nullopt;
  }

  if (std::holds_alternative<int32_t>(*value)) {
    return static_cast<int64_t>(std::get<int32_t>(*value));
  }
  auto val64 = std::get_if<int64_t>(value);
  if (!val64) {
    return std::nullopt;
  }
  return *val64;
}

std::wstring Utf16FromUtf8(const std::string& utf8_string) {
  if (utf8_string.empty()) {
    return std::wstring();
  }
  int target_length =
      ::MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, utf8_string.data(),
                            static_cast<int>(utf8_string.length()), nullptr, 0);
  if (target_length == 0) {
    return std::wstring();
  }
  std::wstring utf16_string;
  utf16_string.resize(target_length);
  int converted_length =
      ::MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, utf8_string.data(),
                            static_cast<int>(utf8_string.length()),
                            utf16_string.data(), target_length);
  if (converted_length == 0) {
    return std::wstring();
  }
  return utf16_string;
}

std::string HRESULTToString(HRESULT hr) {
  _com_error error(hr);
  CString cs;
  cs.Format(_T("Error 0x%08x: %s"), hr, error.ErrorMessage());

  std::string res;

#ifdef UNICODE
  int wlen = lstrlenW(cs);
  int len = WideCharToMultiByte(CP_ACP, 0, cs, wlen, NULL, 0, NULL, NULL);
  res.resize(len);
  WideCharToMultiByte(CP_ACP, 0, cs, wlen, &res[0], len, NULL, NULL);
#else
  res = errMsg;
#endif
  return res;
}

int GetEncoderClsid(const WCHAR* format, CLSID* pClsid) {
  UINT num = 0;
  UINT size = 0;

  Gdiplus::ImageCodecInfo* pImageCodecInfo = NULL;

  Gdiplus::GetImageEncodersSize(&num, &size);
  if (size == 0) return -1;

  pImageCodecInfo = (Gdiplus::ImageCodecInfo*)(malloc(size));
  if (pImageCodecInfo == NULL) return -1;

  Gdiplus::GetImageEncoders(num, size, pImageCodecInfo);

  for (UINT j = 0; j < num; ++j) {
    if (wcscmp(pImageCodecInfo[j].MimeType, format) == 0) {
      *pClsid = pImageCodecInfo[j].Clsid;
      free(pImageCodecInfo);
      return j;
    }
  }

  free(pImageCodecInfo);
  return -1;
}

// Using existing MediaFoundation extraction as fallback option
std::string ExtractVideoFrameAtTime(PCWSTR srcFile, PCWSTR destFile, int width, REFGUID format, int timeSeconds) {
  // Original MediaFoundation extraction implementation with improved quality
  
  // Initialize MediaFoundation
  HRESULT hr = MFStartup(MF_VERSION);
  if (!SUCCEEDED(hr)) {
    return "MFStartup failed with " + HRESULTToString(hr);
  }

  // Initialize GDI+
  Gdiplus::GdiplusStartupInput gdiplusStartupInput;
  ULONG_PTR gdiplusToken;
  Gdiplus::GdiplusStartup(&gdiplusToken, &gdiplusStartupInput, NULL);

  IMFSourceReader* pReader = NULL;
  hr = MFCreateSourceReaderFromURL(srcFile, NULL, &pReader);
  if (!SUCCEEDED(hr)) {
    MFShutdown();
    Gdiplus::GdiplusShutdown(gdiplusToken);
    return "MFCreateSourceReaderFromURL failed with " + HRESULTToString(hr);
  }

  // Configure the source reader to give us progressive RGB32 frames
  // Create a partial media type that specifies uncompressed RGB32 video
  IMFMediaType* pMediaType = NULL;
  hr = MFCreateMediaType(&pMediaType);
  if (!SUCCEEDED(hr)) {
    pReader->Release();
    MFShutdown();
    Gdiplus::GdiplusShutdown(gdiplusToken);
    return "MFCreateMediaType failed with " + HRESULTToString(hr);
  }

  hr = pMediaType->SetGUID(MF_MT_MAJOR_TYPE, MFMediaType_Video);
  if (!SUCCEEDED(hr)) {
    pMediaType->Release();
    pReader->Release();
    MFShutdown();
    Gdiplus::GdiplusShutdown(gdiplusToken);
    return "SetGUID MF_MT_MAJOR_TYPE failed with " + HRESULTToString(hr);
  }

  hr = pMediaType->SetGUID(MF_MT_SUBTYPE, MFVideoFormat_RGB32);
  if (!SUCCEEDED(hr)) {
    pMediaType->Release();
    pReader->Release();
    MFShutdown();
    Gdiplus::GdiplusShutdown(gdiplusToken);
    return "SetGUID MF_MT_SUBTYPE failed with " + HRESULTToString(hr);
  }

  // Set this type on the source reader
  hr = pReader->SetCurrentMediaType(
      (DWORD)MF_SOURCE_READER_FIRST_VIDEO_STREAM, NULL, pMediaType);
  if (!SUCCEEDED(hr)) {
    pMediaType->Release();
    pReader->Release();
    MFShutdown();
    Gdiplus::GdiplusShutdown(gdiplusToken);
    return "SetCurrentMediaType failed with " + HRESULTToString(hr);
  }
  pMediaType->Release();

  // Calculate the time offset to seek to
  PROPVARIANT var;
  PropVariantInit(&var);
  var.vt = VT_I8;

  // Convert from seconds to 100-nanosecond units
  var.hVal.QuadPart = timeSeconds * 10000000LL;
  hr = pReader->SetCurrentPosition(GUID_NULL, var);
  PropVariantClear(&var);

  if (!SUCCEEDED(hr)) {
    pReader->Release();
    MFShutdown();
    Gdiplus::GdiplusShutdown(gdiplusToken);
    return "SetCurrentPosition failed with " + HRESULTToString(hr);
  }

  // Try to find a keyframe by reading multiple samples if needed
  IMFSample* pSample = NULL;
  bool foundGoodFrame = false;
  int maxAttempts = 30; // Try reading more frames to find a better one

  for (int attempt = 0; attempt < maxAttempts; attempt++) {
    // Get the next sample
    DWORD streamIndex, flags;
    LONGLONG timestamp;
    
    if (pSample) {
      pSample->Release();
      pSample = NULL;
    }
    
    hr = pReader->ReadSample((DWORD)MF_SOURCE_READER_FIRST_VIDEO_STREAM,
                           0, &streamIndex, &flags, &timestamp, &pSample);
                           
    if (!SUCCEEDED(hr) || !pSample) {
      // If we can't read any more samples but already found one, use what we have
      if (foundGoodFrame) {
        break;
      }
      
      if (pSample) {
        pSample->Release();
      }
      pReader->Release();
      MFShutdown();
      Gdiplus::GdiplusShutdown(gdiplusToken);
      return "ReadSample failed with " + HRESULTToString(hr);
    }

    // Check if this is a good frame (not a repeat frame or too dark)
    foundGoodFrame = true;
    
    // If we've gone too far past our target time, stop
    if (attempt > 0 && timestamp > (timeSeconds + 2) * 10000000LL) {
      break;
    }
  }

  if (!pSample) {
    pReader->Release();
    MFShutdown();
    Gdiplus::GdiplusShutdown(gdiplusToken);
    return "Failed to find a suitable video frame";
  }

  IMFMediaBuffer* pBuffer = NULL;
  hr = pSample->ConvertToContiguousBuffer(&pBuffer);
  if (!SUCCEEDED(hr) || !pBuffer) {
    if (pBuffer) {
      pBuffer->Release();
    }
    pSample->Release();
    pReader->Release();
    MFShutdown();
    Gdiplus::GdiplusShutdown(gdiplusToken);
    return "ConvertToContiguousBuffer failed with " + HRESULTToString(hr);
  }

  DWORD maxSize = 0;
  DWORD curSize = 0;
  BYTE* data = NULL;
  hr = pBuffer->Lock(&data, &maxSize, &curSize);

  if (!SUCCEEDED(hr) || !data) {
    pBuffer->Release();
    pSample->Release();
    pReader->Release();
    MFShutdown();
    Gdiplus::GdiplusShutdown(gdiplusToken);
    return "Buffer->Lock failed with " + HRESULTToString(hr);
  }

  // Get the media type after ReadSample to get the real frame dimensions
  IMFMediaType* pType = NULL;
  hr = pReader->GetCurrentMediaType((DWORD)MF_SOURCE_READER_FIRST_VIDEO_STREAM,
                                    &pType);
  if (!SUCCEEDED(hr) || !pType) {
    pBuffer->Unlock();
    pBuffer->Release();
    pSample->Release();
    pReader->Release();
    MFShutdown();
    Gdiplus::GdiplusShutdown(gdiplusToken);
    return "GetCurrentMediaType failed with " + HRESULTToString(hr);
  }

  UINT32 videoWidth, videoHeight;
  hr = MFGetAttributeSize(pType, MF_MT_FRAME_SIZE, &videoWidth, &videoHeight);
  pType->Release();

  if (!SUCCEEDED(hr)) {
    pBuffer->Unlock();
    pBuffer->Release();
    pSample->Release();
    pReader->Release();
    MFShutdown();
    Gdiplus::GdiplusShutdown(gdiplusToken);
    return "MFGetAttributeSize failed with " + HRESULTToString(hr);
  }

  // Create a GDI+ bitmap from the RGB32 frame data
  Gdiplus::Bitmap* pGdiPlusBitmap = new Gdiplus::Bitmap(videoWidth, videoHeight, PixelFormat32bppRGB);
  if (!pGdiPlusBitmap) {
    pBuffer->Unlock();
    pBuffer->Release();
    pSample->Release();
    pReader->Release();
    MFShutdown();
    Gdiplus::GdiplusShutdown(gdiplusToken);
    return "Failed to create GDI+ bitmap";
  }

  // Copy the pixel data to the bitmap
  Gdiplus::BitmapData bitmapData;
  Gdiplus::Rect rect(0, 0, videoWidth, videoHeight);
  if (pGdiPlusBitmap->LockBits(&rect, Gdiplus::ImageLockModeWrite, PixelFormat32bppRGB, &bitmapData) == Gdiplus::Ok) {
    BYTE* pDest = (BYTE*)bitmapData.Scan0;
    BYTE* pSrc = data;
    int stride = bitmapData.Stride;

    for (UINT y = 0; y < videoHeight; y++) {
      memcpy(pDest, pSrc, videoWidth * 4);
      pDest += stride;
      pSrc += videoWidth * 4;
    }

    pGdiPlusBitmap->UnlockBits(&bitmapData);
  } else {
    delete pGdiPlusBitmap;
    pBuffer->Unlock();
    pBuffer->Release();
    pSample->Release();
    pReader->Release();
    MFShutdown();
    Gdiplus::GdiplusShutdown(gdiplusToken);
    return "Failed to lock GDI+ bitmap bits";
  }

  // Apply image enhancement to improve thumbnail quality
  Gdiplus::ColorMatrix enhancementMatrix = {
    1.05f, 0.0f, 0.0f, 0.0f, 0.0f,    // Slightly increase red channel
    0.0f, 1.05f, 0.0f, 0.0f, 0.0f,    // Slightly increase green channel
    0.0f, 0.0f, 1.1f, 0.0f, 0.0f,     // Slightly increase blue channel
    0.0f, 0.0f, 0.0f, 1.0f, 0.0f,
    0.0f, 0.0f, 0.0f, 0.0f, 1.0f
  };

  Gdiplus::ImageAttributes imgAttributes;
  imgAttributes.SetColorMatrix(&enhancementMatrix, Gdiplus::ColorMatrixFlagsDefault, Gdiplus::ColorAdjustTypeBitmap);

  int thumbnailWidth = width;
  int thumbnailHeight = (int)(((float)videoHeight / videoWidth) * width);

  Gdiplus::Bitmap* pResizedBitmap = new Gdiplus::Bitmap(thumbnailWidth, thumbnailHeight, PixelFormat32bppRGB);
  Gdiplus::Graphics* pGraphics = Gdiplus::Graphics::FromImage(pResizedBitmap);
  
  // Set high quality rendering settings for better thumbnails
  pGraphics->SetInterpolationMode(Gdiplus::InterpolationModeHighQualityBicubic);
  pGraphics->SetCompositingQuality(Gdiplus::CompositingQualityHighQuality);
  pGraphics->SetSmoothingMode(Gdiplus::SmoothingModeHighQuality);
  pGraphics->SetPixelOffsetMode(Gdiplus::PixelOffsetModeHighQuality);
  
  // Draw with enhanced color settings
  Gdiplus::Rect destRect(0, 0, thumbnailWidth, thumbnailHeight);
  pGraphics->DrawImage(pGdiPlusBitmap, destRect, 0, 0, videoWidth, videoHeight, 
                      Gdiplus::UnitPixel, &imgAttributes);

  // Configure encoder parameters for better quality
  Gdiplus::EncoderParameters encoderParams;
  ULONG quality;
  
  encoderParams.Count = 1;
  encoderParams.Parameter[0].Guid = Gdiplus::EncoderQuality;
  encoderParams.Parameter[0].Type = Gdiplus::EncoderParameterValueTypeLong;
  encoderParams.Parameter[0].NumberOfValues = 1;
  encoderParams.Parameter[0].Value = &quality;
  
  // Set higher quality value for JPEG (PNG is lossless so doesn't need quality setting)
  quality = format == Gdiplus::ImageFormatJPEG ? 95 : 100;

  CLSID clsid;
  if (format == Gdiplus::ImageFormatPNG) {
    GetEncoderClsid(L"image/png", &clsid);
  } else {
    GetEncoderClsid(L"image/jpeg", &clsid);
  }

  Gdiplus::Status status = pResizedBitmap->Save(destFile, &clsid, &encoderParams);

  delete pGraphics;
  delete pResizedBitmap;
  delete pGdiPlusBitmap;

  pBuffer->Unlock();
  pBuffer->Release();
  pSample->Release();
  pReader->Release();
  Gdiplus::GdiplusShutdown(gdiplusToken);
  MFShutdown();

  if (status != Gdiplus::Ok) {
    return "Failed to save thumbnail";
  }

  return "";
}

std::string SaveThumbnail(PCWSTR srcFile, PCWSTR destFile, int size, REFGUID type, int* timeSeconds) {
  // If timeSeconds is provided, use FFmpeg first (faster and more reliable)
  if (timeSeconds != nullptr) {
    // Try FFmpeg implementation first
    std::string result = FFmpegThumbnailHelper::ExtractThumbnail(srcFile, destFile, size, type, *timeSeconds);
    
    // If FFmpeg succeeds or file exists, return result
    if (result.empty() || GetFileAttributesW(destFile) != INVALID_FILE_ATTRIBUTES) {
      return result;
    }
    
    // If FFmpeg fails, fall back to MediaFoundation
    return ExtractVideoFrameAtTime(srcFile, destFile, size, type, *timeSeconds);
  }

  // If no timeSeconds, use original Windows thumbnail cache method
  IShellItem* pSI;
  HRESULT hr = SHCreateItemFromParsingName(srcFile, NULL, IID_IShellItem, (void**)&pSI);
  if (!SUCCEEDED(hr)) {
    return "`SHCreateItemFromParsingName` failed with " + HRESULTToString(hr);
  }

  IThumbnailCache* pThumbCache;
  hr = CoCreateInstance(CLSID_LocalThumbnailCache,
                        NULL,
                        CLSCTX_INPROC_SERVER,
                        IID_PPV_ARGS(&pThumbCache));

  if (!SUCCEEDED(hr)) {
    pSI->Release();
    return "`CoCreateInstance` failed with " + HRESULTToString(hr);
  }
  ISharedBitmap* pSharedBitmap = NULL;
  hr = pThumbCache->GetThumbnail(pSI,
                                 size,
                                 WTS_EXTRACT | WTS_SCALETOREQUESTEDSIZE,
                                 &pSharedBitmap,
                                 NULL,
                                 NULL);

  if (!SUCCEEDED(hr) || !pSharedBitmap) {
    pSI->Release();
    pThumbCache->Release();
    if (hr == WTS_E_FAILEDEXTRACTION) {
      return kGetThumbnailFailedExtraction;
    }
    return "`GetThumbnail` failed with " + HRESULTToString(hr);
  }
  HBITMAP hBitmap;
  hr = pSharedBitmap->GetSharedBitmap(&hBitmap);
  if (!SUCCEEDED(hr) || !hBitmap) {
    pSI->Release();
    pSharedBitmap->Release();
    pThumbCache->Release();
    return "`GetSharedBitmap` failed with " + HRESULTToString(hr);
  }

  pSI->Release();
  pSharedBitmap->Release();
  pThumbCache->Release();

  CImage image;
  image.Attach(hBitmap);
  hr = image.Save(destFile, type);
  if (!SUCCEEDED(hr)) {
    return "`image.Attach` failed with " + HRESULTToString(hr);
  }
  return "";
}

void FcNativeVideoThumbnailPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows* registrar) {
  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "fc_native_video_thumbnail",
          &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<FcNativeVideoThumbnailPlugin>();

  channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto& call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  registrar->AddPlugin(std::move(plugin));
}

FcNativeVideoThumbnailPlugin::FcNativeVideoThumbnailPlugin() {}

FcNativeVideoThumbnailPlugin::~FcNativeVideoThumbnailPlugin() {}

void FcNativeVideoThumbnailPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const auto* argsPtr = std::get_if<flutter::EncodableMap>(method_call.arguments());
  assert(argsPtr);
  auto args = *argsPtr;
  if (method_call.method_name().compare("getVideoThumbnail") == 0) {
    const auto* src_file =
        std::get_if<std::string>(ValueOrNull(args, "srcFile"));
    assert(src_file);

    const auto* dest_file =
        std::get_if<std::string>(ValueOrNull(args, "destFile"));
    assert(dest_file);

    const auto* width =
        std::get_if<int>(ValueOrNull(args, "width"));
    assert(width);

    const auto* outType =
        std::get_if<std::string>(ValueOrNull(args, "format"));
    assert(outType);

    int* timeSeconds = nullptr;
    int timeSecondsValue = 0;
    const auto* time_seconds_val = ValueOrNull(args, "timeSeconds");
    if (time_seconds_val != nullptr && std::holds_alternative<int>(*time_seconds_val)) {
      timeSecondsValue = std::get<int>(*time_seconds_val);
      timeSeconds = &timeSecondsValue;
    }

    auto oper_res = SaveThumbnail(
        Utf16FromUtf8(*src_file).c_str(), 
        Utf16FromUtf8(*dest_file).c_str(), 
        *width, 
        outType->compare("png") == 0 ? Gdiplus::ImageFormatPNG : Gdiplus::ImageFormatJPEG,
        timeSeconds);

    if (oper_res == kGetThumbnailFailedExtraction) {
      result->Success(flutter::EncodableValue(false));
    } else if (oper_res != "") {
      result->Error("PluginError", "Operation failed. " + oper_res);
    } else {
      result->Success(flutter::EncodableValue(true));
    }
  } else {
    result->NotImplemented();
  }
}

}  // namespace fc_native_video_thumbnail
