# Build script for mobile_smb_native with libsmb2
# This script builds the native C++ library with libsmb2 integration

Write-Host "Building mobile_smb_native with libsmb2..." -ForegroundColor Green

# Check if vcpkg is available
$vcpkgPath = "C:\vcpkg\vcpkg.exe"
if (-not (Test-Path $vcpkgPath)) {
    Write-Host "Error: vcpkg not found at $vcpkgPath" -ForegroundColor Red
    Write-Host "Please install vcpkg and libsmb2:" -ForegroundColor Yellow
    Write-Host "  git clone https://github.com/Microsoft/vcpkg.git C:\vcpkg" -ForegroundColor Yellow
    Write-Host "  cd C:\vcpkg" -ForegroundColor Yellow
    Write-Host "  .\bootstrap-vcpkg.bat" -ForegroundColor Yellow
    Write-Host "  .\vcpkg install libsmb2:x64-windows" -ForegroundColor Yellow
    exit 1
}

# Check if libsmb2 is installed
$libsmb2Installed = & $vcpkgPath list | Select-String "libsmb2"
if (-not $libsmb2Installed) {
    Write-Host "Installing libsmb2 via vcpkg..." -ForegroundColor Yellow
    & $vcpkgPath install libsmb2:x64-windows
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Error: Failed to install libsmb2" -ForegroundColor Red
        exit 1
    }
}

# Create build directory
$buildDir = "build"
if (Test-Path $buildDir) {
    Remove-Item -Recurse -Force $buildDir
}
New-Item -ItemType Directory -Path $buildDir | Out-Null

# Configure with CMake
Write-Host "Configuring with CMake..." -ForegroundColor Yellow
Set-Location $buildDir

$cmakeArgs = @(
    "..",
    "-DCMAKE_TOOLCHAIN_FILE=C:/vcpkg/scripts/buildsystems/vcpkg.cmake",
    "-DVCPKG_TARGET_TRIPLET=x64-windows",
    "-DCMAKE_BUILD_TYPE=Release"
)

& cmake @cmakeArgs
if ($LASTEXITCODE -ne 0) {
    Write-Host "Error: CMake configuration failed" -ForegroundColor Red
    Set-Location ..
    exit 1
}

# Build
Write-Host "Building..." -ForegroundColor Yellow
& cmake --build . --config Release
if ($LASTEXITCODE -ne 0) {
    Write-Host "Error: Build failed" -ForegroundColor Red
    Set-Location ..
    exit 1
}

# Copy built library to appropriate location
Write-Host "Copying built library..." -ForegroundColor Yellow
$builtLib = "Release\smb_bridge.dll"
if (Test-Path $builtLib) {
    Copy-Item $builtLib "..\windows\" -Force
    Write-Host "Library copied to windows/smb_bridge.dll" -ForegroundColor Green
} else {
    Write-Host "Warning: Built library not found at $builtLib" -ForegroundColor Yellow
}

Set-Location ..
Write-Host "Build completed successfully!" -ForegroundColor Green
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Run 'flutter pub get' in the plugin directory" -ForegroundColor Yellow
Write-Host "  2. Test the plugin with your Flutter app" -ForegroundColor Yellow