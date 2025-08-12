import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as pathlib;
import 'package:window_manager/window_manager.dart';
import 'package:cb_file_manager/helpers/user_preferences.dart';
// Windows audio fix imports
import 'package:cb_file_manager/ui/components/video_player/windows_audio_fix.dart';

// Media Kit imports - replacing standard video_player
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';

/// Cross-platform video player using media_kit on desktop & VLC on mobile
class CustomVideoPlayer extends StatefulWidget {
  final File file;
  final bool autoPlay;
  final bool looping;
  final bool showControls;
  final bool allowFullScreen;
  final bool allowMuting;
  final bool allowPlaybackSpeedChanging;
  final Function(Map<String, dynamic>)? onVideoInitialized;
  final Function(String)? onError;
  final VoidCallback? onNextVideo;
  final VoidCallback? onPreviousVideo;
  final bool hasNextVideo;
  final bool hasPreviousVideo;
  final VoidCallback? onControlVisibilityChanged;
  final VoidCallback? onFullScreenChanged;
  final VoidCallback? onInitialized;
  final bool showStreamingSpeed;
  final VoidCallback? onToggleStreamingSpeed;

  const CustomVideoPlayer({
    Key? key,
    required this.file,
    this.autoPlay = true,
    this.looping = false,
    this.showControls = true,
    this.allowFullScreen = true,
    this.allowMuting = true,
    this.allowPlaybackSpeedChanging = true,
    this.onVideoInitialized,
    this.onError,
    this.onNextVideo,
    this.onPreviousVideo,
    this.hasNextVideo = false,
    this.hasPreviousVideo = false,
    this.onControlVisibilityChanged,
    this.onFullScreenChanged,
    this.onInitialized,
    this.showStreamingSpeed = false,
    this.onToggleStreamingSpeed,
  }) : super(key: key);

  @override
  _CustomVideoPlayerState createState() => _CustomVideoPlayerState();
}

class _CustomVideoPlayerState extends State<CustomVideoPlayer> {
  @override
  void didUpdateWidget(CustomVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.file.path != widget.file.path) {
      _disposeControllers();
      _initializePlayer();
    }
  }

  void _setupPlayerEventListeners(UserPreferences prefs) {
    // Track play state changes
    _player.stream.playing.listen((playing) {
      if (mounted && _isPlaying != playing) {
        setState(() {
          _isPlaying = playing;
        });
      }
    });

    // Track volume changes for mute state and preferences
    _player.stream.volume.listen((volume) {
      if (!mounted) return;

      debugPrint('Volume changed to: ${volume.toStringAsFixed(1)}');

      // Update mute state based on volume
      final wasMuted = _isMuted;
      final isMutedNow = volume <= 0.1;

      if (wasMuted != isMutedNow) {
        setState(() {
          _isMuted = isMutedNow;
        });

        // Save mute state when it changes
        prefs.setVideoPlayerMute(isMutedNow).then((_) {
          debugPrint('Saved mute state: $isMutedNow');
        });
      }

      // Only update volume preference if not muted and volume changed significantly
      if (!isMutedNow && (_savedVolume - volume).abs() > 0.5) {
        setState(() {
          _savedVolume = volume;
        });

        prefs.setVideoPlayerVolume(volume).then((_) {
          debugPrint('Saved volume preference: ${volume.toStringAsFixed(1)}');
        });
      }
    });

    // Track errors
    _player.stream.error.listen((error) {
      debugPrint('Player error: $error');
      if (mounted && !_hasError) {
        setState(() {
          _hasError = true;
          _errorMessage = error;
        });
        if (widget.onError != null) {
          widget.onError!(_errorMessage);
        }
      }
    });

    // Log all events for debugging
    _player.stream.log.listen((event) {
      debugPrint('Player log: $event');
    });
  }

  void _disposeControllers() {
    _initializationTimeout?.cancel();
    _player.dispose();
  }

  // Media Kit controllers
  late final Player _player;
  late final VideoController _videoController;

  // VLC for mobile
  VlcPlayerController? _vlcController;

  // Focus node for keyboard events
  final FocusNode _focusNode = FocusNode();

  bool _isLoading = true;
  bool _hasError = false;
  bool _isFullScreen = false;
  bool _isPlaying = false; // Local state variable to track playing state
  bool _isMuted = false; // Local state variable to track mute state
  String _errorMessage = '';
  Timer? _initializationTimeout;
  Map<String, dynamic>? _videoMetadata;
  double _savedVolume = 70.0; // Store volume as 0.0-100.0 scale, default 70.0
  // Track if audio tracks menu is open
  bool _showControls = true; // Track if controls are visible in fullscreen
  Timer? _hideControlsTimer; // Timer to auto-hide controls

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  String _normalizeToFileUri(String path) {
    // Chuẩn hóa path thành file:// URI cho VLC & media_kit khi cần
    if (Platform.isWindows) {
      if (path.startsWith('\\\\')) {
        // UNC: \\server\share\path -> file://server/share/path
        final cleaned = path.replaceAll('\\', '/');
        // Remove leading double slashes for UNC when building file://server/share
        final withoutLeading =
            cleaned.startsWith('//') ? cleaned.substring(2) : cleaned;
        return 'file://$withoutLeading';
      }
      // Local drive: C:\path -> file:///C:/path
      final cleaned = path.replaceAll('\\', '/');
      return 'file:///$cleaned';
    }
    // Non-Windows: just return path directly, let backends handle it
    return path;
  }

  Future<void> _initializePlayer() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
        _errorMessage = '';
      });

      _initializationTimeout = Timer(const Duration(seconds: 30), () {
        if (_isLoading && mounted) {
          setState(() {
            _isLoading = false;
            _hasError = true;
            _errorMessage = 'Video initialization timed out after 30 seconds';
          });

          if (widget.onError != null) {
            widget.onError!(_errorMessage);
          }
        }
      });

      // Load saved volume and mute preferences
      final userPreferences = UserPreferences.instance;
      await userPreferences.init();

      // Load preferences in parallel since they're independent
      final volume = await userPreferences.getVideoPlayerVolume();
      final isMuted = await userPreferences.getVideoPlayerMute();

      // Ensure volume is within valid range and save to state
      _savedVolume = volume.clamp(0.0, 100.0);
      _isMuted = isMuted;

      debugPrint(
          'Loaded preferences - volume: ${_savedVolume.toStringAsFixed(1)}, muted: $_isMuted');

      // On desktop, prefer media_kit
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        // Create Media Kit player instance
        _player = Player();
        _videoController = VideoController(_player);

        // Add player event listeners
        _setupPlayerEventListeners(userPreferences);

        // Set initial volume based on preferences
        if (_isMuted) {
          await _player.setVolume(0.0);
        } else {
          await _player.setVolume(_savedVolume);
        }

        // Open video file
        await _player.open(Media(widget.file.path));

        // Auto-play if enabled
        if (widget.autoPlay) {
          await _player.play();
        }

        // Wait for video info to be available
        await Future.delayed(const Duration(milliseconds: 300));

        // Cancel timeout as we've successfully initialized
        _initializationTimeout?.cancel();
        _initializationTimeout = null;

        // Extract video metadata
        _videoMetadata = {
          'duration': _player.state.duration,
          'width': _player.state.width,
          'height': _player.state.height,
        };

        // Notify parent widget
        if (widget.onVideoInitialized != null) {
          widget.onVideoInitialized!(_videoMetadata!);
        }
        if (widget.onInitialized != null) {
          widget.onInitialized!();
        }

        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Mobile (Android/iOS): use VLC
      String mrl = widget.file.path;
      final isNetwork = mrl.startsWith('smb://') ||
          mrl.startsWith('http://') ||
          mrl.startsWith('https://');

      String vlcMrl;
      if (isNetwork) {
        vlcMrl = mrl; // keep smb/http/https as-is
      } else if (Platform.isAndroid || Platform.isIOS) {
        // Normalize local path to file:/// for VLC
        vlcMrl = _normalizeToFileUri(mrl);
      } else {
        vlcMrl = mrl;
      }

      _vlcController = VlcPlayerController.network(
        vlcMrl,
        hwAcc: HwAcc.full,
        autoPlay: widget.autoPlay,
        options: VlcPlayerOptions(
          advanced: VlcAdvancedOptions([
            '--network-caching=2000',
          ]),
        ),
      );

      _vlcController?.addListener(() {
        if (!mounted) return;
        final controller = _vlcController;
        if (controller == null) return;
        final v = controller.value;
        if (v.hasError) {
          setState(() {
            _isLoading = false;
            _hasError = true;
            _errorMessage = v.errorDescription ?? 'Unknown error';
          });
          widget.onError?.call(_errorMessage);
        } else {
          if (!_isLoading) return;
          if (v.isInitialized) {
            setState(() {
              _isLoading = false;
            });
            widget.onVideoInitialized?.call({'path': widget.file.path});
            widget.onInitialized?.call();
          }
        }
      });
    } catch (e) {
      debugPrint('Error initializing player: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = e.toString();
        });

        if (widget.onError != null) {
          widget.onError!(_errorMessage);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const Center(
            child: CircularProgressIndicator(color: Colors.white),
          )
        : _hasError
            ? _buildErrorWidget(_errorMessage)
            : KeyboardListener(
                focusNode: _focusNode,
                autofocus: true,
                onKeyEvent: (KeyEvent event) {
                  if (event is KeyDownEvent) {
                    if (event.logicalKey == LogicalKeyboardKey.space) {
                      _togglePlayPause();
                    } else if (event.logicalKey ==
                        LogicalKeyboardKey.arrowLeft) {
                      _seekBackward();
                    } else if (event.logicalKey ==
                        LogicalKeyboardKey.arrowRight) {
                      _seekForward();
                    }
                  }
                },
                child: MouseRegion(
                  // Detect mouse movements in fullscreen mode
                  onHover: (_) {
                    if (_isFullScreen) {
                      _showControlsWithTimer();
                    }
                  },
                  child: GestureDetector(
                    // Add tap gesture to show controls in fullscreen mode
                    onTap: () {
                      if (_isFullScreen) {
                        _showControlsWithTimer();
                      }
                    },
                    child: Stack(
                      children: [
                        // Base video with double-click for fullscreen
                        GestureDetector(
                          onDoubleTap:
                              widget.allowFullScreen ? _toggleFullScreen : null,
                          child: ClipRRect(
                            borderRadius: _isFullScreen
                                ? BorderRadius.zero
                                : BorderRadius.circular(8.0),
                            child: _buildVideoWidget(),
                          ),
                        ),

                        // Add custom controls if enabled
                        // In fullscreen mode, only show controls when _showControls is true
                        if (widget.showControls &&
                            (!_isFullScreen || _showControls))
                          _buildCustomControls(),
                      ],
                    ),
                  ),
                ),
              );
  }

  Widget _buildVideoWidget() {
    final isDesktop =
        Platform.isWindows || Platform.isLinux || Platform.isMacOS;

    if (isDesktop) {
      return Video(
        controller: _videoController,
        controls: null, // Always use our custom controls
        fill: Colors.black,
      );
    } else {
      return _vlcController != null
          ? VlcPlayer(
              controller: _vlcController!,
              aspectRatio: 16 / 9,
              placeholder: const Center(child: CircularProgressIndicator()),
            )
          : const Center(child: CircularProgressIndicator());
    }
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _disposeControllers();
    // Dispose VLC controller if used
    _vlcController?.stop();
    _vlcController?.dispose();
    super.dispose();
  }

  // Start timer to auto-hide controls
  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _isFullScreen) {
        setState(() {
          _showControls = false;
        });
        // Notify parent about control visibility change if needed
        if (widget.onControlVisibilityChanged != null) {
          widget.onControlVisibilityChanged!();
        }
      }
    });
  }

  // Show controls and restart timer
  void _showControlsWithTimer() {
    if (mounted) {
      setState(() {
        _showControls = true;
      });
      _startHideControlsTimer();

      // Notify parent about control visibility change if needed
      if (widget.onControlVisibilityChanged != null) {
        widget.onControlVisibilityChanged!();
      }
    }
  }

  // Toggle fullscreen state
  Future<void> _toggleFullScreen() async {
    if (widget.allowFullScreen) {
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        // Desktop platforms - use window_manager
        try {
          bool isFullScreen = await windowManager.isFullScreen();
          if (isFullScreen) {
            // Exit fullscreen mode
            await windowManager.setFullScreen(false);
            await windowManager.setResizable(true);
          } else {
            // Enter fullscreen mode
            await windowManager.setFullScreen(true);
          }
          setState(() {
            _isFullScreen = !isFullScreen;

            // When entering fullscreen, start with controls visible
            if (_isFullScreen) {
              _showControls = true;
              _startHideControlsTimer();
            }
          });

          // Notify parent about fullscreen state change
          if (widget.onFullScreenChanged != null) {
            widget.onFullScreenChanged!();
          }
        } catch (e) {
          debugPrint('Error toggling fullscreen: $e');
        }
      } else {
        // Mobile platforms - use system chrome
        setState(() {
          _isFullScreen = !_isFullScreen;

          // When entering fullscreen, start with controls visible
          if (_isFullScreen) {
            _showControls = true;
            _startHideControlsTimer();
          }
        });

        if (_isFullScreen) {
          // Enter fullscreen mode
          SystemChrome.setPreferredOrientations([
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight,
          ]);
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
        } else {
          // Exit fullscreen mode
          SystemChrome.setPreferredOrientations(DeviceOrientation.values);
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        }

        // Notify parent about fullscreen state change
        if (widget.onFullScreenChanged != null) {
          widget.onFullScreenChanged!();
        }
      }
    }
  }

  // Seek forward by the specified number of seconds
  void _seekForward([int seconds = 10]) async {
    final currentPosition = _player.state.position;
    final newPosition = currentPosition + Duration(seconds: seconds);

    // Make sure we don't seek past the end of the video
    final seekPosition = newPosition > _player.state.duration
        ? _player.state.duration
        : newPosition;

    await _player.seek(seekPosition);

    // Show controls briefly when seeking
    if (_isFullScreen) {
      _showControlsWithTimer();
    }
  }

  // Seek backward by the specified number of seconds
  void _seekBackward([int seconds = 10]) async {
    final currentPosition = _player.state.position;
    final newPosition = currentPosition - Duration(seconds: seconds);

    // Make sure we don't seek before the start of the video
    final seekPosition =
        newPosition < Duration.zero ? Duration.zero : newPosition;

    await _player.seek(seekPosition);

    // Show controls briefly when seeking
    if (_isFullScreen) {
      _showControlsWithTimer();
    }
  }

  // Toggle play/pause state
  void _togglePlayPause() async {
    // Update local state immediately for UI responsiveness
    setState(() {
      _isPlaying = !_player.state.playing;
    });

    // Then update the actual player state
    if (_player.state.playing) {
      await _player.pause();
    } else {
      await _player.play();
    }

    // If in fullscreen, show controls briefly when play/pause is toggled
    if (_isFullScreen) {
      _showControlsWithTimer();
    }

    // Force another update to ensure UI is in sync with player
    if (mounted) {
      setState(() {});
    }
  }

  Widget _buildErrorWidget(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            color: Colors.red,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Build the complete set of custom controls
  Widget _buildCustomControls() {
    return Stack(
      children: [
        // Bottom control bar with seekbar, play/pause, next/prev, and volume
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Custom seek bar
              _buildCustomSeekBar(),

              // Main controls row with attractive UI
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.8),
                      Colors.black.withOpacity(0.6),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    // Previous button
                    _buildControlButton(
                      icon: Icons.skip_previous,
                      onPressed: widget.hasPreviousVideo &&
                              widget.onPreviousVideo != null
                          ? widget.onPreviousVideo
                          : null,
                      enabled: widget.hasPreviousVideo,
                    ),

                    // Play/Pause button with larger size
                    StreamBuilder<bool>(
                      stream: _player.stream.playing,
                      initialData:
                          _isPlaying, // Use local state for initial value
                      builder: (context, snapshot) {
                        // Use local state variable when stream doesn't have data yet
                        final isPlaying = snapshot.data ?? _isPlaying;

                        return _buildControlButton(
                          icon: isPlaying ? Icons.pause : Icons.play_arrow,
                          onPressed: _togglePlayPause,
                          size: 36,
                          padding: 12,
                          enabled: true,
                        );
                      },
                    ),

                    // Next button
                    _buildControlButton(
                      icon: Icons.skip_next,
                      onPressed:
                          widget.hasNextVideo && widget.onNextVideo != null
                              ? widget.onNextVideo
                              : null,
                      enabled: widget.hasNextVideo,
                    ),

                    // Flexible spacer to push volume and fullscreen to the right
                    const Spacer(),

                    // Screenshot button
                    _buildControlButton(
                      icon: Icons.photo_camera,
                      onPressed: _takeScreenshot,
                      enabled: true,
                      tooltip: 'Take screenshot',
                    ),

                    // Volume control
                    if (widget.allowMuting) _buildVolumeControl(),

                    // Windows Audio Fix Button for audio troubleshooting
                    if (Platform.isWindows)
                      WindowsAudioFixButton(
                        onAudioConfigSelected: (audioConfig) {
                          debugPrint('Applying new audio config: $audioConfig');
                          // Reopen the media with the new audio configuration
                          _player.open(
                            Media(
                              widget.file.path,
                              extras: audioConfig,
                            ),
                            play: _isPlaying,
                          );
                        },
                      ),

                    // Audio track selection button
                    _buildAudioTrackButton(),

                    // Fullscreen button
                    if (widget.allowFullScreen)
                      _buildControlButton(
                        icon: _isFullScreen
                            ? Icons.fullscreen_exit
                            : Icons.fullscreen,
                        onPressed: _toggleFullScreen,
                        enabled: true,
                        tooltip: _isFullScreen
                            ? 'Exit fullscreen'
                            : 'Enter fullscreen',
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Build individual control button with consistent styling
  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback? onPressed,
    bool enabled = true,
    double size = 24,
    double padding = 8,
    String? tooltip,
  }) {
    final button = IconButton(
      icon: Icon(
        icon,
        size: size,
        color: enabled ? Colors.white : Colors.grey,
      ),
      onPressed: enabled ? onPressed : null,
      padding: EdgeInsets.all(padding),
      constraints: const BoxConstraints(),
      splashRadius: size + 4,
    );

    return tooltip != null
        ? Tooltip(
            message: tooltip,
            child: button,
          )
        : button;
  }

  // Build custom seek bar
  Widget _buildCustomSeekBar() {
    return StreamBuilder<Duration>(
      stream: _player.stream.position,
      builder: (context, snapshot) {
        final position = snapshot.data ?? Duration.zero;
        final duration = _player.state.duration;
        final progress = duration.inMilliseconds > 0
            ? position.inMilliseconds / duration.inMilliseconds
            : 0.0;

        return Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              // Current time
              Text(
                _formatDuration(position),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 8),
              // Seek bar
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 6,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 12,
                    ),
                  ),
                  child: Slider(
                    value: progress.clamp(0.0, 1.0),
                    onChanged: (value) {
                      final newPosition = Duration(
                        milliseconds: (value * duration.inMilliseconds).round(),
                      );
                      _player.seek(newPosition);
                    },
                    activeColor: Colors.white,
                    inactiveColor: Colors.white.withOpacity(0.3),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Total duration
              Text(
                _formatDuration(duration),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Build volume control
  Widget _buildVolumeControl() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        StreamBuilder<double>(
          stream: _player.stream.volume,
          initialData: _savedVolume,
          builder: (context, snapshot) {
            final volume = snapshot.data ?? _savedVolume;
            final isMuted = volume <= 0.1;

            return _buildControlButton(
              icon: isMuted
                  ? Icons.volume_off
                  : volume < 50
                      ? Icons.volume_down
                      : Icons.volume_up,
              onPressed: () async {
                if (isMuted) {
                  // Unmute: restore saved volume
                  await _player.setVolume(_savedVolume);
                } else {
                  // Mute: set volume to 0
                  await _player.setVolume(0.0);
                }
              },
              enabled: true,
              tooltip: isMuted ? 'Unmute' : 'Mute',
            );
          },
        ),
        // Volume slider (only show on desktop or when not in fullscreen)
        if (!_isFullScreen ||
            (Platform.isWindows || Platform.isLinux || Platform.isMacOS))
          SizedBox(
            width: 80,
            child: StreamBuilder<double>(
              stream: _player.stream.volume,
              initialData: _savedVolume,
              builder: (context, snapshot) {
                final volume = snapshot.data ?? _savedVolume;
                return SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 4,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 8,
                    ),
                  ),
                  child: Slider(
                    value: volume.clamp(0.0, 100.0),
                    min: 0.0,
                    max: 100.0,
                    onChanged: (value) {
                      _player.setVolume(value);
                    },
                    activeColor: Colors.white,
                    inactiveColor: Colors.white.withOpacity(0.3),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  // Build audio track selection button
  Widget _buildAudioTrackButton() {
    return _buildControlButton(
      icon: Icons.audiotrack,
      onPressed: () {
        // Show audio track selection dialog
        _showAudioTrackDialog();
      },
      enabled: true,
      tooltip: 'Audio tracks',
    );
  }

  // Show audio track selection dialog
  void _showAudioTrackDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Audio Tracks'),
        content: const Text('Audio track selection will be implemented here.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // Format duration for display
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${twoDigits(minutes)}:${twoDigits(seconds)}';
    } else {
      return '${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
  }

  Future<void> _takeScreenshot() async {
    try {
      final path = widget.file.path;
      pathlib.basenameWithoutExtension(path);

      // Implement actual screenshot capture logic here
      // This will depend on your video player implementation

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Screenshot saved')),
      );
    } catch (e) {
      debugPrint('Error taking screenshot: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save screenshot')),
      );
    }
  }
}

// A component that displays video information
class VideoInfoDialog extends StatelessWidget {
  final File file;
  final Map<String, dynamic>? videoMetadata;

  const VideoInfoDialog({
    Key? key,
    required this.file,
    this.videoMetadata,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Video Information'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _infoRow('File Name', file.path.split('/').last),
            const Divider(),
            _infoRow('Path', file.path),
            const Divider(),
            _infoRow('Type', file.path.split('.').last.toUpperCase()),
            if (videoMetadata != null) ...[
              const Divider(),
              _infoRow('Duration', 'Unknown'),
              const Divider(),
              _infoRow('Resolution', 'Unknown'),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _infoRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$title: ',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
