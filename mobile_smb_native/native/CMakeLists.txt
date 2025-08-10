cmake_minimum_required(VERSION 3.10)

project(smb_bridge)

# Set C++ standard
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Find libsmb2
find_package(PkgConfig QUIET)
if(PKG_CONFIG_FOUND)
    pkg_check_modules(LIBSMB2 QUIET libsmb2)
    # LibVLC check removed - now using flutter_vlc_player
endif()

# LibVLC support removed - now using flutter_vlc_player

# Source files - using libsmb2 implementation
set(SOURCES
    src/smb_bridge.cpp
    src/smb_client.cpp
    src/thumbnail_generator.cpp
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

# LibVLC linking removed - now using flutter_vlc_player

# Platform-specific configurations
if(WIN32)
    target_link_libraries(smb_bridge ws2_32)
elseif(UNIX)
    target_link_libraries(smb_bridge pthread)
endif()