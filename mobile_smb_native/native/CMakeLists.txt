cmake_minimum_required(VERSION 3.10)

project(smb_bridge)

# Set C++ standard
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Find libsmb2
find_package(PkgConfig QUIET)
if(PKG_CONFIG_FOUND)
    pkg_check_modules(LIBSMB2 QUIET libsmb2)
    pkg_check_modules(LIBVLC QUIET libvlc)
endif()

# Check for LibVLC
if(LIBVLC_FOUND)
    add_definitions(-DENABLE_LIBVLC)
    message(STATUS "LibVLC found, enabling media streaming support")
else()
    message(WARNING "LibVLC not found, media streaming will be disabled")
endif()

# Source files - using libsmb2 implementation
set(SOURCES
    src/smb_bridge.cpp
    src/smb_client.cpp
    src/thumbnail_generator.cpp
    src/media_streamer.cpp
)

# Include directories
include_directories(include)
if(LIBSMB2_FOUND)
    include_directories(${LIBSMB2_INCLUDE_DIRS})
endif()

# Create shared library
add_library(smb_bridge SHARED ${SOURCES})

# Set library properties
set_target_properties(smb_bridge PROPERTIES
    VERSION 1.0.0
    SOVERSION 1
)

# Link libraries
if(LIBSMB2_FOUND)
    target_link_libraries(smb_bridge ${LIBSMB2_LIBRARIES})
    target_compile_options(smb_bridge PRIVATE ${LIBSMB2_CFLAGS_OTHER})
else()
    # Fallback to manual linking if pkg-config not available
    target_link_libraries(smb_bridge smb2)
endif()

# Link LibVLC if available
if(LIBVLC_FOUND)
    target_link_libraries(smb_bridge ${LIBVLC_LIBRARIES})
    target_compile_options(smb_bridge PRIVATE ${LIBVLC_CFLAGS_OTHER})
    target_include_directories(smb_bridge PRIVATE ${LIBVLC_INCLUDE_DIRS})
else()
    # Try manual linking for common LibVLC locations
    find_library(VLC_LIB vlc PATHS /usr/lib /usr/local/lib)
    if(VLC_LIB)
        target_link_libraries(smb_bridge ${VLC_LIB})
        add_definitions(-DENABLE_LIBVLC)
    endif()
endif()

# Platform-specific configurations
if(WIN32)
    target_link_libraries(smb_bridge ws2_32)
elseif(UNIX)
    target_link_libraries(smb_bridge pthread)
endif()