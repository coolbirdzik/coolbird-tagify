cmake_minimum_required(VERSION 3.10.2)

project(smb_bridge)

# Set C++ standard
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Add include directories
include_directories(../native/include)

# Find prebuilt libraries
find_library(log-lib log)

# Source files for the shared library - using stub implementation
set(SOURCES
    ../native/smb_bridge_stub.cpp
    ../native/src/media_streamer.cpp
)

# Create shared library
add_library(smb_bridge SHARED ${SOURCES})

# Link libraries
target_link_libraries(smb_bridge
    ${log-lib}
    # Note: libsmbclient libraries will need to be provided as prebuilt libraries
    # or built from source for Android
)

# Add LibVLC support for Android
add_definitions(-DENABLE_LIBVLC)
# LibVLC will be linked through Gradle dependency

# Add VLC include directories for Android
# VLC headers are provided by the libvlc-all AAR dependency
set(VLC_INCLUDE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../.gradle/caches/transforms-3/*/transformed/libvlc-all-*/jni/include")
file(GLOB VLC_INCLUDE_PATHS "${CMAKE_CURRENT_SOURCE_DIR}/../.gradle/caches/transforms-*/*/transformed/libvlc-all-*/jni/include")
if(VLC_INCLUDE_PATHS)
    list(GET VLC_INCLUDE_PATHS 0 VLC_INCLUDE_DIR)
    include_directories(${VLC_INCLUDE_DIR})
    message(STATUS "Found VLC include directory: ${VLC_INCLUDE_DIR}")
else()
    # Fallback: try to find VLC headers in common locations
    find_path(VLC_INCLUDE_DIR vlc/vlc.h
        PATHS
        /usr/include
        /usr/local/include
        ${CMAKE_CURRENT_SOURCE_DIR}/../vlc/include
    )
    if(VLC_INCLUDE_DIR)
        include_directories(${VLC_INCLUDE_DIR})
        message(STATUS "Found VLC include directory: ${VLC_INCLUDE_DIR}")
    else()
        message(WARNING "VLC include directory not found, media streaming may not compile")
    endif()
endif()

# Set library properties
set_target_properties(smb_bridge PROPERTIES
    VERSION 1.0.0
    SOVERSION 1
)