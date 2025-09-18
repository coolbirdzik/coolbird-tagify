# Streaming Feature Documentation

## Overview

Streaming provides video and audio playback using media_kit and flutter_vlc_player. Handles platform-specific limitations and performance.

## Key Files & Entry Points

- services*streaming*\*
- ui_components_streaming_performance_widget

## Architecture & Integration

- Uses media_kit and flutter_vlc_player for playback
- UI components for performance monitoring
- Platform-specific fixes for audio/video

## Technical Debt & Known Issues

- Platform-specific limitations (e.g., Windows audio)
- Limited test coverage

## Workarounds & Gotchas

- Apply platform-specific fixes as needed

## Testing

- Manual testing for playback on all platforms

## Success Criteria

- Smooth playback on all supported platforms
- No major regressions in streaming functionality
