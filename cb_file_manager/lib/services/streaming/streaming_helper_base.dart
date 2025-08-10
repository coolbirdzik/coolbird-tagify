import '../network_browsing/i_smb_service.dart';

/// Base class for all streaming helpers
abstract class StreamingHelperBase {
  /// Name of the streaming helper
  String get name;

  /// Priority of this helper (higher = more preferred)
  int get priority;

  /// Check if this helper supports the given SMB service
  bool isServiceSupported(ISmbService smbService);

  /// Check if this helper supports the given media type
  bool isSupportedMediaType(String fileName);

  /// Get capabilities of this streaming helper
  Map<String, dynamic> getCapabilities();
}

/// Base interface for media player callbacks
abstract class MediaPlayerCallbacks {
  /// Called when media is ready to play
  void onMediaReady();

  /// Called when a media error occurs
  void onMediaError(int errorCode, String message);

  /// Called when media playback ends
  void onMediaEnd();

  /// Called when playback position changes
  void onPositionChanged(int position, int duration);
}
