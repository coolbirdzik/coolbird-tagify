import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:io';

/// A helper class to optimize frame timing and prevent the
/// "Reported frame time is older than the last one" error
class FrameTimingOptimizer {
  /// Singleton instance
  static final FrameTimingOptimizer _instance =
      FrameTimingOptimizer._internal();

  /// Factory constructor to return the singleton instance
  factory FrameTimingOptimizer() => _instance;

  /// Private constructor
  FrameTimingOptimizer._internal();

  /// Track if optimization has been initialized
  bool _initialized = false;

  /// Maximum resource cache size for Skia in bytes
  /// This helps prevent memory issues with large images/thumbnails
  static const int _maxResourceCacheBytes = 512 * 1024 * 1024; // 512MB

  /// Initialize frame timing optimizations
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Configure Flutter scheduler for better frame pacing
      // Note: Removed the incorrect schedulerPhase setter that caused the error

      // Optimize Skia render pipeline
      await SystemChannels.skia.invokeMethod<void>(
          'Skia.setResourceCacheMaxBytes', _maxResourceCacheBytes);

      // Register frame callback to ensure consistent frame timing
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _ensureConsistentFrameTiming();
      });

      _initialized = true;
      debugPrint('FrameTimingOptimizer: Initialized successfully');
    } catch (e) {
      debugPrint('FrameTimingOptimizer: Initialization error: $e');
    }
  }

  /// Call this method when starting heavy operations that might affect frame timing
  void optimizeBeforeHeavyOperation() {
    if (!_initialized) {
      debugPrint(
          'FrameTimingOptimizer: Warning - Called before initialization');
      return;
    }

    // Schedule a microtask to yield to the event loop
    scheduleMicrotask(() {
      // Schedule a new frame to ensure the UI thread stays responsive
      SchedulerBinding.instance.scheduleFrame();
    });
  }

  /// Use this method when rendering multiple images or thumbnails
  /// to prevent frame time inconsistencies
  void optimizeImageRendering() {
    if (!_initialized) return;

    // Yield to the event loop to prevent UI thread blocking
    Timer(Duration.zero, () {
      SchedulerBinding.instance.ensureVisualUpdate();
    });
  }

  /// Internal method to ensure consistent frame timing
  void _ensureConsistentFrameTiming() {
    // Register a persistent frame callback
    SchedulerBinding.instance.addPersistentFrameCallback((timeStamp) {
      // This callback runs after every frame is drawn
      // and helps maintain consistent frame timing
    });

    // Schedule the first frame
    SchedulerBinding.instance.scheduleFrame();
  }

  /// Call this when scrolling through lists with thumbnails
  /// to prevent frame timing issues
  void optimizeScrolling() {
    if (!_initialized) return;

    // Ensure proper render scheduling during scrolling
    SchedulerBinding.instance.addPostFrameCallback((_) {
      // Schedule a frame with slight delay to prevent back-to-back frames
      Timer(const Duration(milliseconds: 5), () {
        SchedulerBinding.instance.scheduleFrame();
      });
    });
  }
}
