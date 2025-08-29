import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';

/// Helper class for MediaKit audio configuration
class MediaKitAudioHelper {
  static bool _isInitialized = false;

  /// Initialize MediaKit with default audio settings
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Make sure MediaKit is initialized with default settings
      MediaKit.ensureInitialized();
      debugPrint('MediaKit Audio Helper initialized with default settings');
      _isInitialized = true;
    } catch (e) {
      debugPrint('Error initializing MediaKit Audio Helper: $e');
    }
  }

  /// Get recommended audio options - using defaults
  static Map<String, dynamic> getRecommendedAudioOptions() {
    // Return empty map to use MediaKit defaults
    return {};
  }

  /// Apply default audio settings to a specific player instance
  static Future<void> configurePlayerAudio(Player player) async {
    try {
      // Set volume to default (1.0)
      await player.setVolume(100.0);
      debugPrint('Player audio configured with default settings');
    } catch (e) {
      debugPrint('Error configuring player audio: $e');
    }
  }

  /// Check if audio is working by verifying audio track status
  static Future<bool> checkAudioWorking(Player player) async {
    try {
      // Check if we have valid audio tracks
      final audioTracks = player.state.tracks.audio;
      debugPrint('Audio tracks available: ${audioTracks.length}');

      // Check if any audio track is selected
      final currentTrack = player.state.track.audio;
      debugPrint('Current audio track: ${currentTrack.id}');

      // Consider audio working if we have at least one audio track
      return audioTracks.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking audio status: $e');
      return false;
    }
  }
}
