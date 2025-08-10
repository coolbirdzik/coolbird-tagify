#include "smb_native.h"
#include <windows.h>
#include <winnetwk.h>
#include <cstdint>
#include <vector>
#include <string>
#include <iostream>
#include <mutex>
#include <chrono>
#include <thread>
#include <condition_variable>
#include <unordered_map>
#include <memory>
#include <algorithm>

// For Thumbnails
#include <shobjidl.h>
#include <thumbcache.h>
#include <gdiplus.h>
#include <shlwapi.h>
#include <shlobj.h>
#include <propkey.h>
#include <lm.h>

#pragma comment(lib, "Mpr.lib")
#pragma comment(lib, "gdiplus.lib")
#pragma comment(lib, "shlwapi.lib")
#pragma comment(lib, "netapi32.lib")

// Define BHID_ThumbnailHandler if not available
#ifndef BHID_ThumbnailHandler
// {7B2E650A-8E20-4F4A-B09E-6597AFC72381}
DEFINE_GUID(BHID_ThumbnailHandler,
            0x7b2e650a, 0x8e20, 0x4f4a, 0xb0, 0x9e, 0x65, 0x97, 0xaf, 0xc7, 0x23, 0x81);
#endif

// Helper to convert FILETIME to milliseconds since epoch
long long FileTimeToMillis(const FILETIME &ft)
{
    ULARGE_INTEGER uli;
    uli.LowPart = ft.dwLowDateTime;
    uli.HighPart = ft.dwHighDateTime;
    return (long long)(uli.QuadPart / 10000) - 11644473600000LL;
}

// --- Connection Management ---

FFI_EXPORT int32_t Connect(const wchar_t *path, const wchar_t *username, const wchar_t *password)
{
    NETRESOURCEW nr = {};
    nr.dwType = RESOURCETYPE_DISK;
    nr.lpLocalName = NULL;
    nr.lpRemoteName = const_cast<LPWSTR>(path);
    nr.lpProvider = NULL;

    DWORD dwFlags = CONNECT_INTERACTIVE;
    return WNetAddConnection2W(&nr, password, username, dwFlags);
}

FFI_EXPORT int32_t Disconnect(const wchar_t *path)
{
    return WNetCancelConnection2W(path, 0, TRUE);
}

// --- File and Directory Operations ---

FFI_EXPORT NativeFileList *ListDirectory(const wchar_t *path)
{
    std::vector<NativeFileInfo> files;
    std::wstring search_path = std::wstring(path) + L"\\*";

    // Debug output
    wprintf(L"Listing directory: %s\n", path);
    wprintf(L"Search path: %s\n", search_path.c_str());

    WIN32_FIND_DATAW find_data;
    HANDLE find_handle = FindFirstFileW(search_path.c_str(), &find_data);

    if (find_handle == INVALID_HANDLE_VALUE)
    {
        DWORD error = GetLastError();
        wprintf(L"FindFirstFile failed with error: %lu\n", error);

        // Special case for ERROR_ACCESS_DENIED (5)
        if (error == ERROR_ACCESS_DENIED)
        {
            wprintf(L"Access denied to directory: %s\n", path);
        }

        return nullptr;
    }

    do
    {
        if (wcscmp(find_data.cFileName, L".") != 0 && wcscmp(find_data.cFileName, L"..") != 0)
        {
            NativeFileInfo info = {};
            info.name = _wcsdup(find_data.cFileName);
            ULARGE_INTEGER size;
            size.LowPart = find_data.nFileSizeLow;
            size.HighPart = find_data.nFileSizeHigh;
            info.size = size.QuadPart;
            info.modification_time = FileTimeToMillis(find_data.ftLastWriteTime);
            info.is_directory = (find_data.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) != 0;
            files.push_back(info);

            // Debug output for each file
            wprintf(L"Found: %s, is_dir: %d, size: %llu\n",
                    info.name,
                    info.is_directory ? 1 : 0,
                    info.size);
        }
    } while (FindNextFileW(find_handle, &find_data));

    DWORD last_error = GetLastError();
    if (last_error != ERROR_NO_MORE_FILES)
    {
        wprintf(L"FindNextFile ended with error: %lu\n", last_error);
    }

    FindClose(find_handle);

    wprintf(L"Found %zu items in directory\n", files.size());

    auto *result = new NativeFileList();
    result->count = static_cast<int32_t>(files.size());
    result->files = new NativeFileInfo[files.size()];
    std::copy(files.begin(), files.end(), result->files);

    return result;
}

FFI_EXPORT bool DeleteFileOrDir(const wchar_t *path)
{
    WIN32_FILE_ATTRIBUTE_DATA file_info;
    if (GetFileAttributesExW(path, GetFileExInfoStandard, &file_info))
    {
        if (file_info.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY)
        {
            return RemoveDirectoryW(path);
        }
        else
        {
            return DeleteFileW(path);
        }
    }
    return false;
}

FFI_EXPORT bool CreateDir(const wchar_t *path)
{
    return CreateDirectoryW(path, NULL);
}

FFI_EXPORT bool Rename(const wchar_t *old_path, const wchar_t *new_path)
{
    return MoveFileW(old_path, new_path);
}

// --- File I/O (Streaming) ---

FFI_EXPORT HANDLE OpenFileForReading(const wchar_t *path)
{
    return CreateFileW(path, GENERIC_READ, FILE_SHARE_READ, NULL, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL);
}

FFI_EXPORT HANDLE CreateFileForWriting(const wchar_t *path)
{
    return CreateFileW(path, GENERIC_WRITE, 0, NULL, CREATE_NEW, FILE_ATTRIBUTE_NORMAL, NULL);
}

FFI_EXPORT ReadResult ReadFileChunk(HANDLE handle, int64_t chunk_size)
{
    ReadResult result = {};

    if (handle == INVALID_HANDLE_VALUE)
    {
        result.bytes_read = -1;
        result.data = nullptr;
        return result;
    }

    uint8_t *buffer = new uint8_t[static_cast<size_t>(chunk_size)];
    DWORD bytes_read = 0;

    if (ReadFile(handle, buffer, static_cast<DWORD>(chunk_size), &bytes_read, NULL))
    {
        if (bytes_read > 0)
        {
            result.bytes_read = bytes_read;
            result.data = buffer;
            return result;
        }
        else
        { // End of file
            delete[] buffer;
            result.bytes_read = 0;
            result.data = nullptr;
            return result;
        }
    }

    delete[] buffer;
    result.bytes_read = -1;
    result.data = nullptr;
    return result;
}

FFI_EXPORT bool WriteFileChunk(HANDLE handle, uint8_t *data, int32_t length)
{
    if (handle == INVALID_HANDLE_VALUE)
    {
        return false;
    }
    DWORD bytes_written = 0;
    return WriteFile(handle, data, length, &bytes_written, NULL) && (bytes_written == static_cast<DWORD>(length));
}

FFI_EXPORT void CloseFile(HANDLE handle)
{
    if (handle != INVALID_HANDLE_VALUE)
    {
        CloseHandle(handle);
    }
}

// --- Thumbnail Generation ---

// Global COM and GDI+ initialization for better performance
static bool g_ComInitialized = false;
static ULONG_PTR g_GdiplusToken = 0;
static std::mutex g_InitMutex;

// Thumbnail operation management (inspired by fc_native_video_thumbnail.dart)
static std::mutex g_ThumbnailMutex;
static std::condition_variable g_ThumbnailCV;
static bool g_ThumbnailOperationInProgress = false;
static constexpr auto THUMBNAIL_OPERATION_TIMEOUT = std::chrono::seconds(5);

// Thumbnail cache for better performance
struct CachedThumbnail {
    std::vector<uint8_t> data;
    std::chrono::steady_clock::time_point timestamp;
    int32_t size;
};

static std::unordered_map<std::wstring, CachedThumbnail> g_ThumbnailCache;
static std::mutex g_CacheMutex;
static constexpr auto CACHE_EXPIRY_TIME = std::chrono::minutes(10);
static constexpr size_t MAX_CACHE_SIZE = 100;

void EnsureInitialized()
{
    std::lock_guard<std::mutex> lock(g_InitMutex);
    if (!g_ComInitialized)
    {
        CoInitializeEx(NULL, COINIT_APARTMENTTHREADED | COINIT_DISABLE_OLE1DDE);
        
        Gdiplus::GdiplusStartupInput gdiplusStartupInput;
        Gdiplus::GdiplusStartup(&g_GdiplusToken, &gdiplusStartupInput, NULL);
        
        g_ComInitialized = true;
    }
}

void CleanupGlobal()
{
    std::lock_guard<std::mutex> lock(g_InitMutex);
    if (g_ComInitialized)
    {
        Gdiplus::GdiplusShutdown(g_GdiplusToken);
        CoUninitialize();
        g_ComInitialized = false;
    }
    
    // Clear thumbnail cache
    std::lock_guard<std::mutex> cache_lock(g_CacheMutex);
    g_ThumbnailCache.clear();
}

// Cache management functions
bool GetCachedThumbnail(const std::wstring& path, ThumbnailResult& result)
{
    std::lock_guard<std::mutex> lock(g_CacheMutex);
    auto it = g_ThumbnailCache.find(path);
    
    if (it != g_ThumbnailCache.end())
    {
        // Check if cache entry is still valid
        auto now = std::chrono::steady_clock::now();
        if (now - it->second.timestamp < CACHE_EXPIRY_TIME)
        {
            // Copy cached data
            result.size = it->second.size;
            result.data = new uint8_t[result.size];
            std::copy(it->second.data.begin(), it->second.data.end(), result.data);
            return true;
        }
        else
        {
            // Remove expired entry
            g_ThumbnailCache.erase(it);
        }
    }
    return false;
}

void CacheThumbnail(const std::wstring& path, const ThumbnailResult& result)
{
    if (!result.data || result.size <= 0) return;
    
    std::lock_guard<std::mutex> lock(g_CacheMutex);
    
    // Remove oldest entries if cache is full
    if (g_ThumbnailCache.size() >= MAX_CACHE_SIZE)
    {
        auto oldest = g_ThumbnailCache.begin();
        for (auto it = g_ThumbnailCache.begin(); it != g_ThumbnailCache.end(); ++it)
        {
            if (it->second.timestamp < oldest->second.timestamp)
            {
                oldest = it;
            }
        }
        g_ThumbnailCache.erase(oldest);
    }
    
    // Add new entry
    CachedThumbnail cached;
    cached.data.assign(result.data, result.data + result.size);
    cached.timestamp = std::chrono::steady_clock::now();
    cached.size = result.size;
    
    g_ThumbnailCache[path] = std::move(cached);
}

// Format validation (inspired by isSupportedFormat in fc_native_video_thumbnail.dart)
bool IsSupportedThumbnailFormat(const std::wstring& path)
{
    size_t dot_pos = path.find_last_of(L'.');
    if (dot_pos == std::wstring::npos) return false;
    
    std::wstring ext = path.substr(dot_pos);
    std::transform(ext.begin(), ext.end(), ext.begin(), ::towlower);
    
    // Support common image and video formats
    static const std::vector<std::wstring> supported_formats = {
        L".jpg", L".jpeg", L".png", L".bmp", L".gif", L".tiff", L".webp",
        L".mp4", L".mov", L".wmv", L".avi", L".mkv", L".mpg", L".mpeg", L".m4v", L".ts"
    };
    
    return std::find(supported_formats.begin(), supported_formats.end(), ext) != supported_formats.end();
}

// Semaphore-like operation management
bool WaitForThumbnailOperation()
{
    std::unique_lock<std::mutex> lock(g_ThumbnailMutex);
    
    if (g_ThumbnailOperationInProgress)
    {
        // Wait for current operation to complete with timeout
        return g_ThumbnailCV.wait_for(lock, THUMBNAIL_OPERATION_TIMEOUT, []() {
            return !g_ThumbnailOperationInProgress;
        });
    }
    
    g_ThumbnailOperationInProgress = true;
    return true;
}

void ReleaseThumbnailOperation()
{
    std::lock_guard<std::mutex> lock(g_ThumbnailMutex);
    g_ThumbnailOperationInProgress = false;
    g_ThumbnailCV.notify_one();
}

int GetEncoderClsid(const WCHAR *format, CLSID *pClsid)
{
    UINT num = 0;
    UINT size = 0;
    Gdiplus::GetImageEncodersSize(&num, &size);
    if (size == 0)
        return -1;

    Gdiplus::ImageCodecInfo *pImageCodecInfo = (Gdiplus::ImageCodecInfo *)(malloc(size));
    if (pImageCodecInfo == NULL)
        return -1;

    GetImageEncoders(num, size, pImageCodecInfo);
    for (UINT j = 0; j < num; ++j)
    {
        if (wcscmp(pImageCodecInfo[j].MimeType, format) == 0)
        {
            *pClsid = pImageCodecInfo[j].Clsid;
            free(pImageCodecInfo);
            return j;
        }
    }
    free(pImageCodecInfo);
    return -1;
}

FFI_EXPORT ThumbnailResult GetThumbnail(const wchar_t *path, int32_t thumbnail_size)
{
    ThumbnailResult result = {};
    result.data = nullptr;
    result.size = 0;

    // Basic validation
    if (!path || wcslen(path) == 0) {
        return result;
    }

    std::wstring pathStr(path);
    
    // Check format support first
    if (!IsSupportedThumbnailFormat(pathStr)) {
        return result;
    }

    // Try to get from cache first
    if (GetCachedThumbnail(pathStr, result)) {
        return result;
    }

    // Wait for thumbnail operation slot (semaphore-like behavior)
    if (!WaitForThumbnailOperation()) {
        return result; // Timeout
    }

    // Use global initialization for better performance
    EnsureInitialized();

    IShellItem *pShellItem = nullptr;
    HRESULT hr = SHCreateItemFromParsingName(path, NULL, IID_PPV_ARGS(&pShellItem));

    if (SUCCEEDED(hr))
    {
        IThumbnailProvider *pThumbProvider = nullptr;
        hr = pShellItem->BindToHandler(NULL, BHID_ThumbnailHandler, IID_PPV_ARGS(&pThumbProvider));

        if (SUCCEEDED(hr))
        {
            HBITMAP hBitmap = NULL;
            WTS_ALPHATYPE alphaType;
            
            // Set shorter timeout for better responsiveness
            hr = pThumbProvider->GetThumbnail(thumbnail_size, &hBitmap, &alphaType);

            if (SUCCEEDED(hr) && hBitmap != NULL)
            {
                // Create bitmap from handle
                Gdiplus::Bitmap bitmap(hBitmap, NULL);
                
                if (bitmap.GetLastStatus() == Gdiplus::Ok)
                {
                    // Use optimized PNG encoding with lower compression for speed
                    CLSID clsid_png;
                    if (GetEncoderClsid(L"image/png", &clsid_png) >= 0)
                    {
                        // Create global memory stream for better performance
                        HGLOBAL hGlobal = GlobalAlloc(GMEM_MOVEABLE, 0);
                        if (hGlobal)
                        {
                            IStream *pStream = nullptr;
                            if (CreateStreamOnHGlobal(hGlobal, TRUE, &pStream) == S_OK)
                            {
                                // Fast PNG encoding parameters
                                Gdiplus::EncoderParameters encoderParams;
                                Gdiplus::EncoderParameter compressionParam;
                                ULONG compression = 1; // Lowest compression for speed
                                
                                // Initialize compressionParam first
                                compressionParam.Guid = Gdiplus::EncoderCompression;
                                compressionParam.Type = Gdiplus::EncoderParameterValueTypeLong;
                                compressionParam.NumberOfValues = 1;
                                compressionParam.Value = &compression;
                                
                                encoderParams.Count = 1;
                                encoderParams.Parameter[0] = compressionParam;

                                if (bitmap.Save(pStream, &clsid_png, &encoderParams) == Gdiplus::Ok)
                                {
                                    // Get stream size efficiently
                                    STATSTG statstg;
                                    if (pStream->Stat(&statstg, STATFLAG_NONAME) == S_OK)
                                    {
                                        result.size = static_cast<int32_t>(statstg.cbSize.QuadPart);
                                        if (result.size > 0 && result.size < 10 * 1024 * 1024) // Max 10MB
                                        {
                                            result.data = new uint8_t[result.size];
                                            
                                            // Reset stream position and read
                                            LARGE_INTEGER zero = {0};
                                            pStream->Seek(zero, STREAM_SEEK_SET, NULL);
                                            
                                            ULONG bytesRead;
                                            if (pStream->Read(result.data, result.size, &bytesRead) == S_OK &&
                                                bytesRead == static_cast<ULONG>(result.size))
                                            {
                                                // Success - data is ready
                                            }
                                            else
                                            {
                                                // Read failed, cleanup
                                                delete[] result.data;
                                                result.data = nullptr;
                                                result.size = 0;
                                            }
                                        }
                                    }
                                }
                                pStream->Release();
                            }
                        }
                    }
                }
                DeleteObject(hBitmap);
            }
            pThumbProvider->Release();
        }
        pShellItem->Release();
    }

    // Cache the result if successful
    if (result.data && result.size > 0) {
        CacheThumbnail(pathStr, result);
    }

    // Release the operation slot
    ReleaseThumbnailOperation();

    return result;
}

// Fast thumbnail generation with minimal processing
FFI_EXPORT ThumbnailResult GetThumbnailFast(const wchar_t *path, int32_t thumbnail_size)
{
    ThumbnailResult result = {};
    result.data = nullptr;
    result.size = 0;

    // Basic validation
    if (!path || wcslen(path) == 0) {
        return result;
    }

    std::wstring pathStr(path);
    
    // Check format support first
    if (!IsSupportedThumbnailFormat(pathStr)) {
        return result;
    }

    // Try to get from cache first
    if (GetCachedThumbnail(pathStr, result)) {
        return result;
    }

    // Wait for thumbnail operation slot (semaphore-like behavior)
    if (!WaitForThumbnailOperation()) {
        return result; // Timeout
    }

    // Use global initialization
    EnsureInitialized();

    IShellItem *pShellItem = nullptr;
    HRESULT hr = SHCreateItemFromParsingName(path, NULL, IID_PPV_ARGS(&pShellItem));

    if (SUCCEEDED(hr))
    {
        IThumbnailProvider *pThumbProvider = nullptr;
        hr = pShellItem->BindToHandler(NULL, BHID_ThumbnailHandler, IID_PPV_ARGS(&pThumbProvider));

        if (SUCCEEDED(hr))
        {
            HBITMAP hBitmap = NULL;
            WTS_ALPHATYPE alphaType;
            hr = pThumbProvider->GetThumbnail(thumbnail_size, &hBitmap, &alphaType);

            if (SUCCEEDED(hr) && hBitmap != NULL)
            {
                // Get bitmap info quickly
                BITMAP bm;
                if (GetObject(hBitmap, sizeof(BITMAP), &bm) > 0)
                {
                    // Calculate minimal buffer size (24-bit RGB)
                    int stride = ((bm.bmWidth * 3 + 3) & ~3); // 4-byte aligned
                    int imageSize = stride * bm.bmHeight;
                    
                    // Create minimal BMP header + data
                    int fileSize = sizeof(BITMAPFILEHEADER) + sizeof(BITMAPINFOHEADER) + imageSize;
                    result.data = new uint8_t[fileSize];
                    result.size = fileSize;
                    
                    // Fill BMP headers quickly
                    BITMAPFILEHEADER* fileHeader = (BITMAPFILEHEADER*)result.data;
                    BITMAPINFOHEADER* infoHeader = (BITMAPINFOHEADER*)(result.data + sizeof(BITMAPFILEHEADER));
                    
                    fileHeader->bfType = 0x4D42; // 'BM'
                    fileHeader->bfSize = fileSize;
                    fileHeader->bfOffBits = sizeof(BITMAPFILEHEADER) + sizeof(BITMAPINFOHEADER);
                    
                    infoHeader->biSize = sizeof(BITMAPINFOHEADER);
                    infoHeader->biWidth = bm.bmWidth;
                    infoHeader->biHeight = -bm.bmHeight; // Top-down
                    infoHeader->biPlanes = 1;
                    infoHeader->biBitCount = 24;
                    infoHeader->biCompression = BI_RGB;
                    infoHeader->biSizeImage = imageSize;
                    
                    // Copy bitmap data quickly
                    HDC hdc = GetDC(NULL);
                    GetDIBits(hdc, hBitmap, 0, bm.bmHeight, 
                             result.data + sizeof(BITMAPFILEHEADER) + sizeof(BITMAPINFOHEADER),
                             (BITMAPINFO*)infoHeader, DIB_RGB_COLORS);
                    ReleaseDC(NULL, hdc);
                }
                DeleteObject(hBitmap);
            }
            pThumbProvider->Release();
        }
        pShellItem->Release();
    }

    // Cache the result if successful
    if (result.data && result.size > 0) {
        CacheThumbnail(pathStr, result);
    }

    // Release the operation slot
    ReleaseThumbnailOperation();

    return result;
}

// --- Memory Management ---

// RAII wrapper for safer memory management
class SafeFileList {
private:
    NativeFileList* list_;
public:
    explicit SafeFileList(NativeFileList* list) : list_(list) {}
    ~SafeFileList() { 
        if (list_) FreeFileList(list_); 
    }
    
    SafeFileList(const SafeFileList&) = delete;
    SafeFileList& operator=(const SafeFileList&) = delete;
    
    SafeFileList(SafeFileList&& other) noexcept : list_(other.list_) {
        other.list_ = nullptr;
    }
    
    SafeFileList& operator=(SafeFileList&& other) noexcept {
        if (this != &other) {
            if (list_) FreeFileList(list_);
            list_ = other.list_;
            other.list_ = nullptr;
        }
        return *this;
    }
    
    NativeFileList* get() const { return list_; }
    NativeFileList* release() { 
        auto* temp = list_; 
        list_ = nullptr; 
        return temp; 
    }
};

FFI_EXPORT void FreeFileList(NativeFileList *file_list)
{
    if (file_list)
    {
        for (int i = 0; i < file_list->count; ++i)
        {
            free(file_list->files[i].name);
        }
        delete[] file_list->files;
        delete file_list;
    }
}

FFI_EXPORT void FreeReadResultData(uint8_t *data)
{
    if (data)
    {
        delete[] data;
    }
}

FFI_EXPORT void FreeThumbnailResult(ThumbnailResult result)
{
    if (result.data)
    {
        delete[] result.data;
    }
}

FFI_EXPORT NativeShareList *EnumerateShares(const wchar_t *server)
{
    std::vector<NativeShareInfo> shares;
    SHARE_INFO_1 *buffer = nullptr;
    DWORD entries_read = 0;
    DWORD total_entries = 0;
    DWORD resume_handle = 0;
    NET_API_STATUS result;

    // Debug output
    wprintf(L"Enumerating shares on server: %s\n", server);

    // Call NetShareEnum to list all shares on the server
    result = NetShareEnum(
        const_cast<LPWSTR>(server), // Server name
        1,                          // Level (1 = name and comment)
        (LPBYTE *)&buffer,          // Buffer to receive data
        MAX_PREFERRED_LENGTH,       // Preferred maximum length
        &entries_read,              // Number of entries read
        &total_entries,             // Total number of entries
        &resume_handle              // Resume handle
    );

    if (result != NERR_Success && result != ERROR_MORE_DATA)
    {
        wprintf(L"NetShareEnum failed with error: %lu\n", result);

        // Special case handling for common errors
        if (result == ERROR_ACCESS_DENIED)
        {
            wprintf(L"Access denied when enumerating shares\n");
        }
        else if (result == ERROR_BAD_NETPATH)
        {
            wprintf(L"The network path was not found\n");
        }
        else if (result == ERROR_INVALID_LEVEL)
        {
            wprintf(L"Invalid level parameter\n");
        }

        return nullptr;
    }

    wprintf(L"NetShareEnum returned %lu entries\n", entries_read);

    // Process the shares
    for (DWORD i = 0; i < entries_read; i++)
    {
        // Skip special administrative shares (ending with $)
        if (buffer[i].shi1_netname[wcslen(buffer[i].shi1_netname) - 1] != L'$')
        {
            NativeShareInfo info = {};
            info.name = _wcsdup(buffer[i].shi1_netname);
            info.comment = buffer[i].shi1_remark ? _wcsdup(buffer[i].shi1_remark) : _wcsdup(L"");
            info.type = buffer[i].shi1_type;
            shares.push_back(info);

            // Debug output
            wprintf(L"Share found: %s, type: %d\n", info.name, info.type);
        }
    }

    // Free the allocated buffer
    if (buffer != nullptr)
    {
        NetApiBufferFree(buffer);
    }

    // Create the result structure
    auto *result_list = new NativeShareList();
    result_list->count = static_cast<int32_t>(shares.size());
    result_list->shares = new NativeShareInfo[shares.size()];
    std::copy(shares.begin(), shares.end(), result_list->shares);

    wprintf(L"Returning %d shares\n", result_list->count);
    return result_list;
}

FFI_EXPORT void FreeShareList(NativeShareList *share_list)
{
    if (share_list)
    {
        for (int i = 0; i < share_list->count; ++i)
        {
            free(share_list->shares[i].name);
            free(share_list->shares[i].comment);
        }
        delete[] share_list->shares;
        delete share_list;
    }
}