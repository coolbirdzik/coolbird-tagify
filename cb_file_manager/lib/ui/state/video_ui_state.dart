import 'package:flutter/foundation.dart';

/// Global UI flags related to video playback.
class VideoUiState {
  // Indicates whether a video player is currently in fullscreen mode on mobile.
  static final ValueNotifier<bool> isFullscreen = ValueNotifier<bool>(false);
}

