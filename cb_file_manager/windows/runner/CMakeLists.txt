cmake_minimum_required(VERSION 3.14)
project(runner LANGUAGES CXX)

# Define the application target. To change its name, change BINARY_NAME in the
# top-level CMakeLists.txt, not the value here, or `flutter run` will no longer
# work.
#
# Any new source files that you add to the application should be added here.
add_executable(${BINARY_NAME} WIN32
  "flutter_window.cpp"
  "main.cpp"
  "utils.cpp"
  "win32_window.cpp"
  "${FLUTTER_MANAGED_DIR}/generated_plugin_registrant.cc"
  "fc_native_video_thumbnail_plugin.cpp"
  "fc_native_video_thumbnail_plugin.h"
  "ffmpeg_thumbnail_helper.cpp"
  "ffmpeg_thumbnail_helper.h"
  "smb_native_thumbnail_plugin.cpp"
  "smb_native_thumbnail_plugin.h"
  "app_icon_plugin.cpp"
  "app_icon_plugin.h"
  "shell_context_menu_plugin.cpp"
  "shell_context_menu_plugin.h"
  "file_operations_plugin.cpp"
  "file_operations_plugin.h"
  "window_utils_plugin.cpp"
  "window_utils_plugin.h"
  "Runner.rc"
  "runner.exe.manifest"
)

# Apply the standard set of build settings. This can be removed for applications
# that need different build settings.
apply_standard_settings(${BINARY_NAME})

# Add preprocessor definitions for the build version.
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION=\"${FLUTTER_VERSION}\"")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_MAJOR=${FLUTTER_VERSION_MAJOR}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_MINOR=${FLUTTER_VERSION_MINOR}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_PATCH=${FLUTTER_VERSION_PATCH}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_BUILD=${FLUTTER_VERSION_BUILD}")

# Disable Windows macros that collide with C++ standard library functions.
target_compile_definitions(${BINARY_NAME} PRIVATE "NOMINMAX")

# Add dependency libraries and include directories. Add any application-specific
# dependencies here.
target_link_libraries(${BINARY_NAME} PRIVATE flutter flutter_wrapper_app flutter_wrapper_plugin)
target_link_libraries(${BINARY_NAME} PRIVATE "dwmapi.lib")
target_link_libraries(${BINARY_NAME} PRIVATE smb_native)
target_link_libraries(${BINARY_NAME} PRIVATE "comctl32.lib")
target_link_libraries(${BINARY_NAME} PRIVATE "ole32.lib")
target_link_libraries(${BINARY_NAME} PRIVATE "shell32.lib")

# Add FFmpeg libraries
set(FFMPEG_DIR "${CMAKE_SOURCE_DIR}/ffmpeg")
target_include_directories(${BINARY_NAME} SYSTEM PRIVATE "${FFMPEG_DIR}/include")
target_include_directories(${BINARY_NAME} PRIVATE "${CMAKE_SOURCE_DIR}")
target_link_directories(${BINARY_NAME} PRIVATE "${FFMPEG_DIR}/lib")
target_link_libraries(${BINARY_NAME} PRIVATE avformat avcodec avutil swscale)

# Disable warnings as errors for ffmpeg_thumbnail_helper.cpp (FFmpeg headers have warnings)
set_source_files_properties(
  "${CMAKE_CURRENT_SOURCE_DIR}/ffmpeg_thumbnail_helper.cpp"
  PROPERTIES COMPILE_FLAGS "/W3"
)

# Copy FFmpeg DLLs to output directory
set(FFMPEG_DLLS
  "${FFMPEG_DIR}/bin/avcodec-62.dll"
  "${FFMPEG_DIR}/bin/avformat-62.dll"
  "${FFMPEG_DIR}/bin/avutil-60.dll"
  "${FFMPEG_DIR}/bin/swscale-9.dll"
  "${FFMPEG_DIR}/bin/swresample-6.dll"
)
add_custom_command(TARGET ${BINARY_NAME} POST_BUILD
  COMMAND ${CMAKE_COMMAND} -E copy_if_different
    ${FFMPEG_DLLS}
    $<TARGET_FILE_DIR:${BINARY_NAME}>
  COMMENT "Copying FFmpeg DLLs to output directory"
)

# Run the Flutter tool portions of the build. This must not be removed.
add_dependencies(${BINARY_NAME} flutter_assemble)
