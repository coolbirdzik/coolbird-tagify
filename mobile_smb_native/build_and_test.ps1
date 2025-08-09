# Build and Test Script for Mobile SMB Native
# This script builds the project and runs the example app

Write-Host "Mobile SMB Native - Build and Test Script" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green

# Check if Flutter is installed
Write-Host "Checking Flutter installation..." -ForegroundColor Yellow
try {
    $flutterVersion = flutter --version 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Flutter is installed" -ForegroundColor Green
    } else {
        throw "Flutter not found"
    }
} catch {
    Write-Host "✗ Flutter is not installed or not in PATH" -ForegroundColor Red
    Write-Host "Please install Flutter and add it to your PATH" -ForegroundColor Red
    exit 1
}

# Navigate to the plugin directory
$pluginDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $pluginDir

Write-Host "Current directory: $pluginDir" -ForegroundColor Cyan

# Clean previous builds
Write-Host "Cleaning previous builds..." -ForegroundColor Yellow
if (Test-Path "example\build") {
    Remove-Item -Recurse -Force "example\build"
    Write-Host "✓ Cleaned example/build" -ForegroundColor Green
}

# Get dependencies for the plugin
Write-Host "Getting plugin dependencies..." -ForegroundColor Yellow
try {
    flutter pub get
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Plugin dependencies resolved" -ForegroundColor Green
    } else {
        throw "Failed to get plugin dependencies"
    }
} catch {
    Write-Host "✗ Failed to get plugin dependencies" -ForegroundColor Red
    exit 1
}

# Navigate to example directory
Set-Location "example"
Write-Host "Switched to example directory" -ForegroundColor Cyan

# Get dependencies for the example
Write-Host "Getting example dependencies..." -ForegroundColor Yellow
try {
    flutter pub get
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Example dependencies resolved" -ForegroundColor Green
    } else {
        throw "Failed to get example dependencies"
    }
} catch {
    Write-Host "✗ Failed to get example dependencies" -ForegroundColor Red
    exit 1
}

# Check for connected devices
Write-Host "Checking for connected devices..." -ForegroundColor Yellow
$devices = flutter devices --machine | ConvertFrom-Json

if ($devices.Count -eq 0) {
    Write-Host "✗ No devices found" -ForegroundColor Red
    Write-Host "Please connect a device or start an emulator" -ForegroundColor Yellow
    
    # Ask user if they want to continue with build only
    $response = Read-Host "Do you want to continue with build only? (y/n)"
    if ($response -ne "y" -and $response -ne "Y") {
        exit 1
    }
    $buildOnly = $true
} else {
    Write-Host "✓ Found $($devices.Count) device(s)" -ForegroundColor Green
    foreach ($device in $devices) {
        Write-Host "  - $($device.name) ($($device.id))" -ForegroundColor Cyan
    }
    $buildOnly = $false
}

# Build for Android
Write-Host "Building Android APK..." -ForegroundColor Yellow
try {
    flutter build apk --debug
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Android APK built successfully" -ForegroundColor Green
        $apkPath = "build\app\outputs\flutter-apk\app-debug.apk"
        if (Test-Path $apkPath) {
            $apkSize = (Get-Item $apkPath).Length / 1MB
            Write-Host "  APK size: $([math]::Round($apkSize, 2)) MB" -ForegroundColor Cyan
        }
    } else {
        throw "Android build failed"
    }
} catch {
    Write-Host "✗ Android build failed" -ForegroundColor Red
    Write-Host "Check the build output above for errors" -ForegroundColor Yellow
}

# Run the app if devices are available
if (-not $buildOnly) {
    Write-Host "Starting the example app..." -ForegroundColor Yellow
    Write-Host "Press Ctrl+C to stop the app" -ForegroundColor Cyan
    
    try {
        flutter run --debug
    } catch {
        Write-Host "App execution stopped" -ForegroundColor Yellow
    }
} else {
    Write-Host "Build completed. To run the app:" -ForegroundColor Green
    Write-Host "1. Connect a device or start an emulator" -ForegroundColor Cyan
    Write-Host "2. Run: flutter run" -ForegroundColor Cyan
}

Write-Host "" 
Write-Host "Build and test script completed!" -ForegroundColor Green
Write-Host "" 
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Test the stub implementation in the example app" -ForegroundColor Cyan
Write-Host "2. Integrate real libsmbclient and FFmpeg libraries" -ForegroundColor Cyan
Write-Host "3. Replace stub_implementations.cpp with real implementations" -ForegroundColor Cyan
Write-Host "4. Test with actual SMB servers and media files" -ForegroundColor Cyan