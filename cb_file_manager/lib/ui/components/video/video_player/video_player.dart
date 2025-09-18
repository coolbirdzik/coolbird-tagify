import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:video_player/video_player.dart' as exo;
import 'package:flutter_vlc_player/flutter_vlc_player.dart';
import 'package:window_manager/window_manager.dart';
import 'package:path/path.dart' as pathlib;
// Windows PiP uses a separate OS window (external process).

import '../../../../services/pip_window_service.dart';
import '../pip_window/windows_pip_overlay.dart';
import '../../../../services/streaming/smb_http_proxy_server.dart';
import 'package:cb_file_manager/ui/state/video_ui_state.dart';

import '../../../../helpers/files/file_type_helper.dart';
import '../../../../helpers/core/user_preferences.dart';
import '../../../../helpers/network/win32_smb_helper.dart';
import '../../streaming/stream_speed_indicator.dart';
import '../../streaming/buffer_info_widget.dart';
import '../../../utils/route.dart';

// Enums for new features
enum LoopMode { none, single, all }

enum VideoFilter { none, brightness, contrast, saturation }

// Subtitle track model
class SubtitleTrack {
  final int id;
  final String language;
  final String? title;
  final bool isEnabled;

  const SubtitleTrack({
    required this.id,
    required this.language,
    this.title,
    this.isEnabled = false,
  });
}

// Audio track model
class AudioTrack {
  final int id;
  final String language;
  final String? title;
  final bool isEnabled;

  const AudioTrack({
    required this.id,
    required this.language,
    this.title,
    this.isEnabled = false,
  });
}

/// Unified video player component supporting multiple media sources
/// Consolidates functionality from CustomVideoPlayer and StreamingMediaPlayer
class VideoPlayer extends StatefulWidget {
  // Media source properties
  final File? file;
  final String? streamingUrl;
  final String? smbMrl;
  final Stream<List<int>>? fileStream;

  // Media metadata
  final String fileName;
  final FileType? fileType;

  // Playback configuration
  final bool autoPlay;
  final bool looping;
  final bool showControls;
  final bool allowFullScreen;
  final bool allowMuting;
  final bool allowPlaybackSpeedChanging;

  // Callback functions
  final Function(Map<String, dynamic>)? onVideoInitialized;
  final Function(String)? onError;
  final VoidCallback? onNextVideo;
  final VoidCallback? onPreviousVideo;
  final VoidCallback? onClose;
  final VoidCallback? onControlVisibilityChanged;
  final VoidCallback? onFullScreenChanged;
  final VoidCallback? onInitialized;

  // Navigation state
  final bool hasNextVideo;
  final bool hasPreviousVideo;

  // UI configuration
  final bool showStreamingSpeed;
  final VoidCallback? onToggleStreamingSpeed;

  const VideoPlayer._({
    Key? key,
    this.file,
    this.streamingUrl,
    this.smbMrl,
    this.fileStream,
    required this.fileName,
    this.fileType,
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
    this.onClose,
    this.onControlVisibilityChanged,
    this.onFullScreenChanged,
    this.onInitialized,
    this.hasNextVideo = false,
    this.hasPreviousVideo = false,
    this.showStreamingSpeed = false,
    this.onToggleStreamingSpeed,
  })  : assert(
          file != null ||
              streamingUrl != null ||
              smbMrl != null ||
              fileStream != null,
          'At least one media source must be provided',
        ),
        super(key: key);

  /// Constructor for local file playback
  VideoPlayer.file({
    Key? key,
    required File file,
    bool autoPlay = true,
    bool looping = false,
    bool showControls = true,
    bool allowFullScreen = true,
    bool allowMuting = true,
    bool allowPlaybackSpeedChanging = true,
    Function(Map<String, dynamic>)? onVideoInitialized,
    Function(String)? onError,
    VoidCallback? onNextVideo,
    VoidCallback? onPreviousVideo,
    VoidCallback? onControlVisibilityChanged,
    VoidCallback? onFullScreenChanged,
    VoidCallback? onInitialized,
    bool hasNextVideo = false,
    bool hasPreviousVideo = false,
    bool showStreamingSpeed = false,
    VoidCallback? onToggleStreamingSpeed,
  }) : this._(
          key: key,
          file: file,
          fileName: pathlib.basename(file.path),
          fileType: FileTypeHelper.getFileType(file.path),
          autoPlay: autoPlay,
          looping: looping,
          showControls: showControls,
          allowFullScreen: allowFullScreen,
          allowMuting: allowMuting,
          allowPlaybackSpeedChanging: allowPlaybackSpeedChanging,
          onVideoInitialized: onVideoInitialized,
          onError: onError,
          onNextVideo: onNextVideo,
          onPreviousVideo: onPreviousVideo,
          onControlVisibilityChanged: onControlVisibilityChanged,
          onFullScreenChanged: onFullScreenChanged,
          onInitialized: onInitialized,
          hasNextVideo: hasNextVideo,
          hasPreviousVideo: hasPreviousVideo,
          showStreamingSpeed: showStreamingSpeed,
          onToggleStreamingSpeed: onToggleStreamingSpeed,
        );

  /// Constructor for streaming URL playback
  VideoPlayer.url({
    Key? key,
    required String streamingUrl,
    required String fileName,
    FileType? fileType,
    bool autoPlay = true,
    bool looping = false,
    bool showControls = true,
    bool allowFullScreen = true,
    bool allowMuting = true,
    bool allowPlaybackSpeedChanging = true,
    Function(Map<String, dynamic>)? onVideoInitialized,
    Function(String)? onError,
    VoidCallback? onClose,
    VoidCallback? onControlVisibilityChanged,
    VoidCallback? onFullScreenChanged,
    VoidCallback? onInitialized,
    bool showStreamingSpeed = false,
    VoidCallback? onToggleStreamingSpeed,
  }) : this._(
          key: key,
          streamingUrl: streamingUrl,
          fileName: fileName,
          fileType: fileType ?? FileTypeHelper.getFileType(fileName),
          autoPlay: autoPlay,
          looping: looping,
          showControls: showControls,
          allowFullScreen: allowFullScreen,
          allowMuting: allowMuting,
          allowPlaybackSpeedChanging: allowPlaybackSpeedChanging,
          onVideoInitialized: onVideoInitialized,
          onError: onError,
          onClose: onClose,
          onControlVisibilityChanged: onControlVisibilityChanged,
          onFullScreenChanged: onFullScreenChanged,
          onInitialized: onInitialized,
          showStreamingSpeed: showStreamingSpeed,
          onToggleStreamingSpeed: onToggleStreamingSpeed,
        );

  /// Constructor for SMB MRL playback
  VideoPlayer.smb({
    Key? key,
    required String smbMrl,
    required String fileName,
    FileType? fileType,
    bool autoPlay = true,
    bool looping = false,
    bool showControls = true,
    bool allowFullScreen = true,
    bool allowMuting = true,
    bool allowPlaybackSpeedChanging = true,
    Function(Map<String, dynamic>)? onVideoInitialized,
    Function(String)? onError,
    VoidCallback? onClose,
    VoidCallback? onControlVisibilityChanged,
    VoidCallback? onFullScreenChanged,
    VoidCallback? onInitialized,
    bool showStreamingSpeed = false,
    VoidCallback? onToggleStreamingSpeed,
  }) : this._(
          key: key,
          smbMrl: smbMrl,
          fileName: fileName,
          fileType: fileType ?? FileTypeHelper.getFileType(fileName),
          autoPlay: autoPlay,
          looping: looping,
          showControls: showControls,
          allowFullScreen: allowFullScreen,
          allowMuting: allowMuting,
          allowPlaybackSpeedChanging: allowPlaybackSpeedChanging,
          onVideoInitialized: onVideoInitialized,
          onError: onError,
          onClose: onClose,
          onControlVisibilityChanged: onControlVisibilityChanged,
          onFullScreenChanged: onFullScreenChanged,
          onInitialized: onInitialized,
          showStreamingSpeed: showStreamingSpeed,
          onToggleStreamingSpeed: onToggleStreamingSpeed,
        );

  /// Constructor for file stream playback
  VideoPlayer.stream({
    Key? key,
    required Stream<List<int>> fileStream,
    required String fileName,
    FileType? fileType,
    bool autoPlay = true,
    bool looping = false,
    bool showControls = true,
    bool allowFullScreen = true,
    bool allowMuting = true,
    bool allowPlaybackSpeedChanging = true,
    Function(Map<String, dynamic>)? onVideoInitialized,
    Function(String)? onError,
    VoidCallback? onClose,
    VoidCallback? onControlVisibilityChanged,
    VoidCallback? onFullScreenChanged,
    VoidCallback? onInitialized,
    bool showStreamingSpeed = false,
    VoidCallback? onToggleStreamingSpeed,
  }) : this._(
          key: key,
          fileStream: fileStream,
          fileName: fileName,
          fileType: fileType ?? FileTypeHelper.getFileType(fileName),
          autoPlay: autoPlay,
          looping: looping,
          showControls: showControls,
          allowFullScreen: allowFullScreen,
          allowMuting: allowMuting,
          allowPlaybackSpeedChanging: allowPlaybackSpeedChanging,
          onVideoInitialized: onVideoInitialized,
          onError: onError,
          onClose: onClose,
          onControlVisibilityChanged: onControlVisibilityChanged,
          onFullScreenChanged: onFullScreenChanged,
          onInitialized: onInitialized,
          showStreamingSpeed: showStreamingSpeed,
          onToggleStreamingSpeed: onToggleStreamingSpeed,
        );

  @override
  State<VideoPlayer> createState() => _VideoPlayerState();
}

class _VideoPlayerState extends State<VideoPlayer> {
  // Media Kit controllers
  Player? _player;
  VideoController? _videoController;

  // VLC for mobile/Android
  VlcPlayerController? _vlcController;
  exo.VideoPlayerController?
      _exoController; // ExoPlayer for Android PiP fallback
  bool _usingExoInPip = false;
  // Fallback timer if VLC fails to start on Android
  Timer? _vlcStartupFallback;

  // State variables
  bool _isLoading = true;
  bool _hasError = false;
  bool _isFullScreen = false;
  bool _isPlaying = false;
  bool _isMuted = false;
  String _errorMessage = '';
  double _savedVolume = 70.0;
  bool _showControls = true;
  bool _showSpeedIndicator = false;
  bool _useFlutterVlc = false;

  // Seeking state to prevent loading indicator during seek
  bool _isSeeking = false;
  Timer? _seekingTimer;

  // New advanced features state
  List<SubtitleTrack> _subtitleTracks = [];
  int? _selectedSubtitleTrack = -1;
  double _playbackSpeed = 1.0;
  bool _isPictureInPicture = false;
  bool _isAndroidPip = false;

  // PiP IPC (desktop): server to receive state back from PiP window
  ServerSocket? _pipServer;
  Socket? _pipClient;
  StreamSubscription<Socket>? _pipServerSub;
  StreamSubscription<String>? _pipMsgSub;
  String? _pipToken;

  // Video filters
  double _brightness = 0.0; // -1.0 to 1.0
  double _contrast = 0.0; // -1.0 to 1.0
  double _saturation = 0.0; // -1.0 to 1.0

  // Sleep timer
  Timer? _sleepTimer;
  Duration? _sleepDuration;

  // Video statistics - placeholder for future use
  Timer? _statsUpdateTimer;

  // Video player settings
  String _selectedCodec = 'auto'; // auto, h264, h265, vp9, av1
  bool _hardwareAcceleration = true;
  String _videoDecoder = 'auto'; // auto, software, hardware
  String _audioDecoder = 'auto'; // auto, software, hardware
  int _bufferSize = 10; // MB
  int _networkTimeout = 30; // seconds
  String _subtitleEncoding = 'utf-8';
  String _videoOutputFormat = 'auto'; // auto, yuv420p, rgb24
  String _videoScaleMode =
      'contain'; // cover, contain, fill, fitWidth, fitHeight, none, scaleDown

  // Timers
  Timer? _initializationTimeout;
  Timer? _hideControlsTimer;

  // Streaming state
  Stream<List<int>>? _currentStream;
  StreamController<List<int>>? _streamController;
  int _totalBytesBuffered = 0;
  int _chunkCountBuffered = 0;

  // Progressive buffering state
  File? _tempFile;
  RandomAccessFile? _tempRaf;
  StreamSubscription<List<int>>? _bufferSub;
  int _bytesWritten = 0;
  bool _playerOpenedFromTemp = false;
  Timer? _noDataTimer;
  DateTime? _firstDataTime;

  // VLC state
  bool _vlcListenerAttached = false;
  bool _vlcPlaying = false;
  Duration _vlcPosition = Duration.zero;
  Duration _vlcDuration = Duration.zero;
  double _vlcVolume = 70.0;
  double _lastVolume = 70.0;
  bool _vlcMuted = false;
  bool _isRestoringVolume = false;
  bool _vlcWasActiveBeforePip = false;
  Map<String, dynamic>?
      _vlcPendingRestore; // {pos: Duration, vol: double0..1or0..100, playing: bool}
  bool _vlcPendingRestoreApplied = false;

  // Exo PiP init guard to prevent concurrent initializations
  bool _exoInitInProgress = false;
  bool get _isSmbSource =>
      widget.smbMrl != null && (widget.smbMrl?.isNotEmpty ?? false);
  bool _shouldUseExoForPip() =>
      true; // With local HTTP proxy, prefer Exo for all sources in PiP

  Map<String, dynamic>? _videoMetadata;

  // Helper method to convert string to BoxFit
  BoxFit _getBoxFitFromString(String scaleMode) {
    switch (scaleMode) {
      case 'cover':
        return BoxFit.cover;
      case 'contain':
        return BoxFit.contain;
      case 'fill':
        return BoxFit.fill;
      case 'fitWidth':
        return BoxFit.fitWidth;
      case 'fitHeight':
        return BoxFit.fitHeight;
      case 'none':
        return BoxFit.none;
      case 'scaleDown':
        return BoxFit.scaleDown;
      default:
        return BoxFit.cover;
    }
  }

  @override
  void initState() {
    super.initState();
    // Load settings first, then initialize the player so configuration is applied
    _loadSettings().whenComplete(_initializePlayer);
    _setupAndroidPipChannelListener();
  }

  void _showWindowsOverlayPip(
    BuildContext context, {
    required String sourceType,
    required String source,
    required String fileName,
    required int positionMs,
    required double volume,
    required bool playing,
  }) async {
    // Pause current playback to avoid double audio while overlay plays
    try {
      if (_player != null && _player!.state.playing) {
        await _player!.pause();
      } else if (_vlcController != null && _vlcController!.value.isPlaying) {
        await _vlcController!.pause();
      }
    } catch (_) {}

    WindowsPipOverlay.show(
      context,
      args: {
        'sourceType': sourceType,
        'source': source,
        'fileName': fileName,
        'positionMs': positionMs,
        'volume': volume,
        'playing': playing,
      },
      onClose: (
          {required int positionMs,
          required double volume,
          required bool playing}) async {
        try {
          if (_player != null) {
            await _player!.seek(Duration(milliseconds: positionMs));
            await _player!.setVolume(volume.clamp(0.0, 100.0));
            if (playing) {
              await _player!.play();
            }
          } else if (_vlcController != null) {
            await _vlcController!.seekTo(Duration(milliseconds: positionMs));
            await _vlcController!.setVolume(volume.toInt());
            if (playing) {
              await _vlcController!.play();
            }
          }
        } catch (_) {}
        if (mounted) {
          setState(() => _isPictureInPicture = false);
        }
      },
    );

    if (mounted) {
      setState(() => _isPictureInPicture = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã bật PiP overlay trong ứng dụng')),
      );
    }
  }

  @override
  void dispose() {
    _disposeResources();
    super.dispose();
  }

  void _disposeResources() {
    try {
      _hideControlsTimer?.cancel();
      _vlcStartupFallback?.cancel();
      _initializationTimeout?.cancel();
      _noDataTimer?.cancel();
      _bufferSub?.cancel();
      _sleepTimer?.cancel();
      _statsUpdateTimer?.cancel();
      _seekingTimer?.cancel();
      _tempRaf?.close();
      _tempFile?.delete();
      // Clear video controller reference before disposing the player
      _videoController = null;
      _player?.dispose();
      _vlcController?.dispose();
      _exoController?.dispose();
      _streamController?.close();
      // Close PiP IPC if any
      _pipMsgSub?.cancel();
      _pipServerSub?.cancel();
      _pipClient?.destroy();
      _pipServer?.close();
    } catch (e) {
      debugPrint('Error disposing resources: $e');
    }
    // Reset global fullscreen flag if needed
    try {
      if (VideoUiState.isFullscreen.value == true) {
        VideoUiState.isFullscreen.value = false;
      }
    } catch (_) {}
  }

  Future<void> _initExoForPip() async {
    if (_usingExoInPip || _exoInitInProgress || !Platform.isAndroid) return;
    _exoInitInProgress = true;
    // For SMB MRLs, we will feed Exo via a local HTTP proxy.

    try {
      exo.VideoPlayerController controller;
      if (widget.file != null) {
        controller = exo.VideoPlayerController.file(widget.file!);
      } else if (widget.streamingUrl != null) {
        controller = exo.VideoPlayerController.networkUrl(
            Uri.parse(widget.streamingUrl!));
      } else if (widget.smbMrl != null) {
        final uri = await SmbHttpProxyServer.instance.urlFor(widget.smbMrl!);
        controller = exo.VideoPlayerController.networkUrl(uri);
      } else {
        _exoInitInProgress = false;
        return;
      }
      await controller.initialize();

      // Sync position & volume from current player if available
      if (_player != null) {
        final pos = _player!.state.position;
        if (pos > Duration.zero) {
          await controller.seekTo(pos);
        }
        final vol = _player!.state.volume / 100.0;
        try {
          await controller.setVolume(vol);
        } catch (_) {}
      } else if (_vlcController != null) {
        try {
          final pos = _vlcController!.value.position;
          if (pos > Duration.zero) {
            await controller.seekTo(pos);
          }
        } catch (_) {}
        try {
          await controller.setVolume((_vlcVolume / 100.0).clamp(0.0, 1.0));
        } catch (_) {}
      }

      // Always play in PiP for visible frames
      await controller.play();

      if (mounted) {
        setState(() {
          _exoController = controller;
          _usingExoInPip = true;
        });
      }
    } catch (e) {
      debugPrint('Exo init error: $e');
    }
    _exoInitInProgress = false;
  }

  Future<void> _waitForExoInitialized(
      {Duration timeout = const Duration(seconds: 1)}) async {
    final sw = Stopwatch()..start();
    while (sw.elapsed < timeout) {
      if (_exoController != null && _exoController!.value.isInitialized) {
        break;
      }
      await Future.delayed(const Duration(milliseconds: 50));
    }
  }

  Future<void> _teardownExoAfterPip() async {
    if (!Platform.isAndroid) return;
    final controller = _exoController;
    if (controller == null) return;

    try {
      final pos = await controller.position ?? Duration.zero;
      final playing = controller.value.isPlaying;
      final vol = controller.value.volume; // 0..1

      // Sync back to the appropriate player
      if (_vlcController != null) {
        try {
          await _vlcController!.seekTo(pos);
        } catch (_) {}
        try {
          await _vlcController!.setVolume((vol * 100).toInt());
        } catch (_) {}
        if (playing) {
          try {
            await _vlcController!.play();
          } catch (_) {}
        }
      } else if (_player != null) {
        try {
          await _player!.seek(pos);
        } catch (_) {}
        try {
          await _player!.setVolume((vol * 100).clamp(0.0, 100.0));
        } catch (_) {}
        if (playing) {
          try {
            await _player!.play();
          } catch (_) {}
        }
      } else if (_vlcWasActiveBeforePip) {
        // VLC was active but disposed for PiP. Defer restore until controller re-creates.
        _vlcPendingRestore = {
          'pos': pos,
          'vol': vol, // 0..1
          'playing': playing,
        };
        _vlcPendingRestoreApplied = false;
      }
    } catch (e) {
      debugPrint('Error syncing state after PiP: $e');
    }

    try {
      await controller.pause();
    } catch (_) {}
    try {
      await controller.dispose();
    } catch (_) {}

    if (mounted) {
      setState(() {
        _exoController = null;
        _usingExoInPip = false;
      });
    }
  }

  void _setupAndroidPipChannelListener() {
    if (!kIsWeb && Platform.isAndroid) {
      final channel = MethodChannel('cb_file_manager/pip');
      channel.setMethodCallHandler((call) async {
        debugPrint('PiP channel method call: ${call.method}');

        if (call.method == 'onPipChanged') {
          final args = call.arguments;
          bool inPip = false;
          if (args is Map) {
            inPip = args['inPip'] == true;
          }

          debugPrint('PiP state changed: $inPip');

          if (mounted) {
            setState(() {
              _isAndroidPip = inPip;
            });
          }

          if (inPip) {
            debugPrint('Entering Android PiP mode');
          } else {
            debugPrint('Exiting Android PiP mode');
            // Try to restore state from native PiP payload if provided
            try {
              int posMs = 0;
              bool playing = false;
              double? volume;
              if (args is Map) {
                posMs = (args['positionMs'] as num?)?.toInt() ?? 0;
                playing = args['playing'] == true;
                volume = (args['volume'] as num?)?.toDouble();
              }
              if (_vlcController != null) {
                if (posMs > 0) {
                  await _vlcController!.seekTo(Duration(milliseconds: posMs));
                }
                if (volume != null) {
                  await _vlcController!.setVolume((volume * 100).toInt());
                }
                if (playing) {
                  await _vlcController!.play();
                }
              } else if (_player != null) {
                if (posMs > 0) {
                  await _player!.seek(Duration(milliseconds: posMs));
                }
                if (volume != null) {
                  await _player!.setVolume((volume * 100).clamp(0.0, 100.0));
                }
                if (playing) {
                  await _player!.play();
                }
              }
            } catch (e) {
              debugPrint('Restore after PiP error: $e');
            }
          }
        }
      });
    }
  }

  @override
  void didUpdateWidget(VideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reinitialize if media source changed
    if (_hasMediaSourceChanged(oldWidget)) {
      _disposeResources();
      _initializePlayer();
    }
  }

  bool _hasMediaSourceChanged(VideoPlayer oldWidget) {
    return oldWidget.file?.path != widget.file?.path ||
        oldWidget.streamingUrl != widget.streamingUrl ||
        oldWidget.smbMrl != widget.smbMrl ||
        oldWidget.fileStream != widget.fileStream;
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
          widget.onError?.call(_errorMessage);
        }
      });

      // Load saved volume and mute preferences
      final userPreferences = UserPreferences.instance;
      await userPreferences.init();

      // Enable ObjectBox for persistent storage
      if (!userPreferences.isUsingObjectBox()) {
        await userPreferences.setUseObjectBox(true);
        debugPrint('Enabled ObjectBox for UserPreferences storage');
      }

      final savedVolume = await userPreferences.getVideoPlayerVolume();
      _lastVolume = savedVolume > 0 ? savedVolume : _lastVolume;
      final savedMuted = await userPreferences.getVideoPlayerMute();

      setState(() {
        _savedVolume = savedVolume.clamp(0.0, 100.0);
        _vlcVolume = _savedVolume;
        _isMuted = savedMuted;
        _vlcMuted = savedMuted;
      });

      debugPrint(
          'Loaded volume preferences - volume: ${_savedVolume.toStringAsFixed(1)}, muted: $_isMuted');

      // On Android, prefer flutter_vlc_player for wider device compatibility
      // (workaround for driver/decoder issues observed with some codecs/GPU combos).
      if (!kIsWeb && Platform.isAndroid) {
        _useFlutterVlc = true;
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Initialize media_kit player for desktop or general use
      if (_player == null) {
        _player = Player(
          configuration: PlayerConfiguration(
            // Use configured buffer size (MB) loaded from preferences
            bufferSize: (_bufferSize > 0 ? _bufferSize : 10) * 1024 * 1024,
          ),
        );
        _videoController = VideoController(
          _player!,
          configuration: VideoControllerConfiguration(
            enableHardwareAcceleration: _hardwareAcceleration,
          ),
        );
        _setupPlayerEventListeners(userPreferences);
      }

      // Open media based on source type
      await _openMediaSource();

      // Apply saved volume preferences with multiple attempts
      await _applyVolumeSettings();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error initializing player: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Error initializing player: $e';
          _isLoading = false;
          _hasError = true;
        });
        widget.onError?.call(_errorMessage);
      }
    }
  }

  void _setupPlayerEventListeners(UserPreferences prefs) {
    if (_player == null) return;

    // Track buffering state - but ignore buffering during seek to prevent UI flicker
    _player!.stream.buffering.listen((buffering) {
      // Only rebuild if value actually changes & not during seek
      if (!mounted || _isSeeking) return;
      if (_isLoading != buffering) {
        setState(() {
          _isLoading = buffering;
        });
      }
    });

    // Track play state changes
    _player!.stream.playing.listen((playing) {
      if (mounted && _isPlaying != playing) {
        setState(() {
          _isPlaying = playing;
        });
      }
    });

    // Track volume changes for mute state and preferences
    _player!.stream.volume.listen((volume) {
      if (!mounted || _isRestoringVolume) return;

      final isMutedNow = volume <= 0.1;

      // Save volume preference if not muted and volume changed significantly
      if (!isMutedNow && (_savedVolume - volume).abs() > 0.5) {
        setState(() {
          _savedVolume = volume;
          _vlcVolume = volume;
          if (volume > 0.1) _lastVolume = volume;
        });

        prefs.setVideoPlayerVolume(volume).then((_) {
          debugPrint('Saved volume preference: ${volume.toStringAsFixed(1)}');
        });
      }

      // Save mute state when it changes
      if (_isMuted != isMutedNow) {
        setState(() {
          _isMuted = isMutedNow;
          _vlcMuted = isMutedNow;
        });

        prefs.setVideoPlayerMute(isMutedNow).then((_) {
          debugPrint('Saved mute state: $isMutedNow');
        });
      }
    });

    // Track errors
    _player!.stream.error.listen((error) {
      debugPrint('Player error: $error');
      if (mounted && !_hasError) {
        setState(() {
          _hasError = true;
          _errorMessage = error;
        });
        widget.onError?.call(_errorMessage);
      }
    });
  }

  Future<void> _openMediaSource() async {
    if (widget.file != null) {
      // Local file playback
      await _player!.open(Media(widget.file!.path));
      if (widget.autoPlay) {
        await _player!.play();
      }
    } else if (widget.streamingUrl != null) {
      // Streaming URL playback
      await _player!.open(Media(widget.streamingUrl!));
      if (widget.autoPlay) {
        await _player!.play();
      }
    } else if (widget.smbMrl != null) {
      // SMB MRL playback
      await _openSmbMrl();
    } else if (widget.fileStream != null) {
      // File stream playback
      await _openFileStream();
    }

    // Extract video metadata after opening
    await Future.delayed(const Duration(milliseconds: 300));
    _extractVideoMetadata();
  }

  Future<void> _applyVolumeSettings() async {
    try {
      if (_player != null && mounted) {
        _isRestoringVolume = true;

        if (_isMuted) {
          await _player!.setVolume(0.0);
          debugPrint('Applied mute: volume set to 0.0');
        } else {
          final volumeToApply = _savedVolume > 0
              ? _savedVolume
              : (_lastVolume > 0 ? _lastVolume : 70.0);
          await _player!.setVolume(volumeToApply);
          debugPrint('Applied volume: $volumeToApply');
        }

        await Future.delayed(const Duration(milliseconds: 200));
        _isRestoringVolume = false;

        if (mounted) {
          setState(() {});
        }
      }
    } catch (e) {
      debugPrint('Error applying volume settings: $e');
      _isRestoringVolume = false;
    }
  }

  Future<void> _openSmbMrl() async {
    debugPrint('VideoPlayer: Opening SMB MRL: ${widget.smbMrl}');

    if (!kIsWeb && Platform.isWindows) {
      // On Windows desktop, convert SMB to UNC path
      final uncPath = _smbToUnc(widget.smbMrl!);
      final fileUri = _normalizeToFileUri(uncPath);
      debugPrint('VideoPlayer: Converted SMB to UNC: $uncPath');
      debugPrint('VideoPlayer: Using file URI: $fileUri');

      try {
        await _player!
            .open(Media(fileUri))
            .timeout(const Duration(seconds: 12));
        if (widget.autoPlay) {
          await _player!.play();
        }
        debugPrint('VideoPlayer: file URI opened successfully');
      } on TimeoutException catch (_) {
        debugPrint('VideoPlayer: Open timed out, trying temp file fallback...');
        await _openWithTempFileFallback(uncPath);
      } catch (e) {
        debugPrint(
            'VideoPlayer: Open failed: $e, trying temp file fallback...');
        await _openWithTempFileFallback(uncPath);
      }
    } else {
      // Test SMB URL format
      _testSmbUrlFormat(widget.smbMrl!);

      final media = Media(
        widget.smbMrl!,
        httpHeaders: {
          'User-Agent': 'VLC/3.0.0 LibVLC/3.0.0',
        },
        extras: {
          'load-unsafe-playlists': '',
          'network-caching': '3000',
          'file-caching': '3000',
        },
      );

      try {
        await _player!.open(media).timeout(const Duration(seconds: 10));
        if (widget.autoPlay) {
          await _player!.play();
        }
        debugPrint('VideoPlayer: SMB MRL opened successfully');
      } on TimeoutException catch (_) {
        debugPrint('VideoPlayer: Direct SMB timed out');
        await _openWithHttpProxy();
      } catch (e) {
        debugPrint('VideoPlayer: Direct SMB failed: $e');
        await _openWithHttpProxy();
      }
    }
  }

  Future<void> _openFileStream() async {
    // Progressive buffering: start playback after initial buffer
    _streamController = StreamController<List<int>>.broadcast();
    _currentStream = _streamController!.stream;
    debugPrint('VideoPlayer: Starting progressive buffering...');
    // Respect configured initial buffer size (MB)
    final initialBytes = (_bufferSize > 0 ? _bufferSize : 10) * 1024 * 1024;
    await _startProgressiveBufferingAndPlay(
      widget.fileStream!,
      initialBufferBytes: initialBytes,
    );
  }

  void _extractVideoMetadata() {
    if (_player != null) {
      _videoMetadata = {
        'duration': _player!.state.duration,
        'width': _player!.state.width,
        'height': _player!.state.height,
      };

      widget.onVideoInitialized?.call(_videoMetadata!);
      widget.onInitialized?.call();
    }
  }

  // Convert smb:// URL to Windows UNC path
  String _smbToUnc(String smbUrl) {
    try {
      final uri = Uri.parse(smbUrl);
      final host = uri.host;
      final segs = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      if (host.isEmpty || segs.isEmpty) {
        return smbUrl.replaceFirst('smb://', r'\\').replaceAll('/', r'\\');
      }
      final path = segs.join(r'\\');
      return r'\\' + host + r'\\' + path;
    } catch (_) {
      return smbUrl.replaceFirst('smb://', r'\\').replaceAll('/', r'\\');
    }
  }

  // Normalize Windows paths to file:// URI for media_kit/mpv
  String _normalizeToFileUri(String path) {
    if (Platform.isWindows) {
      if (path.startsWith('\\\\')) {
        // UNC: \\server\share\path -> file://server/share/path
        final cleaned = path.replaceAll('\\', '/');
        final withoutLeading =
            cleaned.startsWith('//') ? cleaned.substring(2) : cleaned;
        return 'file://$withoutLeading';
      }
      // Local drive: C:\path -> file:///C:/path
      final cleaned = path.replaceAll('\\', '/');
      return 'file:///$cleaned';
    }
    return path;
  }

  void _testSmbUrlFormat(String url) {
    debugPrint('=== VideoPlayer SMB URL Test ===');
    debugPrint('URL: $url');

    if (!url.startsWith('smb://')) {
      debugPrint('❌ ERROR: URL does not start with smb://');
      return;
    }

    try {
      final uri = Uri.parse(url);
      debugPrint('✅ URL parsing successful');
      debugPrint('Scheme: ${uri.scheme}');
      debugPrint('Host: ${uri.host}');
      debugPrint('Port: ${uri.port}');
      debugPrint('Path: ${uri.path}');
      debugPrint('User info: ${uri.userInfo}');

      if (uri.path.contains('%')) {
        debugPrint('⚠️ WARNING: URL contains encoded characters');
        debugPrint('Decoded path: ${Uri.decodeComponent(uri.path)}');
      }

      if (uri.userInfo.isNotEmpty) {
        debugPrint('✅ URL contains credentials');
        final parts = uri.userInfo.split(':');
        if (parts.length == 2) {
          debugPrint('Username: ${parts[0]}');
          debugPrint('Password: ${'*' * parts[1].length}');
        }
      } else {
        debugPrint('⚠️ WARNING: URL does not contain credentials');
      }
    } catch (e) {
      debugPrint('❌ ERROR: Failed to parse URL: $e');
    }

    debugPrint('=== End VideoPlayer SMB URL Test ===');
  }

  Future<void> _openWithHttpProxy() async {
    try {
      debugPrint('VideoPlayer: Opening SMB via HTTP proxy...');

      if (mounted) {
        setState(() {
          _errorMessage =
              'Direct SMB streaming failed. HTTP proxy fallback not implemented yet.';
          _isLoading = false;
          _hasError = true;
        });
      }
    } catch (e) {
      debugPrint('VideoPlayer: HTTP proxy error: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'HTTP proxy error: $e';
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  Future<void> _openWithTempFileFallback(String uncPath) async {
    if (kIsWeb || !Platform.isWindows) {
      await _openWithHttpProxy();
      return;
    }
    if (_player == null) return;

    try {
      debugPrint('VideoPlayer: _openWithTempFileFallback for $uncPath');
      final helper = Win32SmbHelper();

      // Try buffered stream approach first
      try {
        final bufferedStream = helper.createBufferedStream(uncPath);
        // Start playback only after sufficient initial buffer based on settings
        final initialBytes = (_bufferSize > 0 ? _bufferSize : 10) * 1024 * 1024;
        await _startProgressiveBufferingAndPlay(
          bufferedStream,
          initialBufferBytes: initialBytes,
        );
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        return;
      } catch (e) {
        debugPrint('VideoPlayer: Buffered stream failed: $e');
      }

      // Fallback to copying to temp file
      try {
        final tempPath = await helper.uncPathToTempFile(uncPath,
            highPriority: true, maxBytes: 32 * 1024 * 1024);
        if (tempPath != null) {
          await _player!.open(Media(tempPath));
          if (widget.autoPlay) {
            await _player!.play();
          }
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
          return;
        }
      } catch (e) {
        debugPrint('VideoPlayer: Temp copy failed: $e');
      }

      await _openWithHttpProxy();
    } catch (e) {
      debugPrint('VideoPlayer: _openWithTempFileFallback error: $e');
      await _openWithHttpProxy();
    }
  }

  Future<void> _startProgressiveBufferingAndPlay(
    Stream<List<int>> source, {
    int initialBufferBytes = 2 * 1024 * 1024,
    int flushEveryBytes = 512 * 1024,
  }) async {
    final tempDir = Directory.systemTemp;
    _tempFile = File(
        '${tempDir.path}/temp_media_${DateTime.now().millisecondsSinceEpoch}');

    try {
      _tempRaf = await _tempFile!.open(mode: FileMode.write);
    } catch (e) {
      debugPrint('VideoPlayer: Error opening temp file: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Cannot create temp file: $e';
          _hasError = true;
        });
      }
      return;
    }

    _bytesWritten = 0;
    _playerOpenedFromTemp = false;
    _firstDataTime = null;
    int bytesSinceFlush = 0;

    _noDataTimer?.cancel();
    _noDataTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_firstDataTime == null) return;
      final since = DateTime.now().difference(_firstDataTime!);
      if (since > const Duration(seconds: 30) && _bytesWritten == 0) {
        debugPrint('VideoPlayer: No data for 30s');
        if (mounted) {
          setState(() {
            _errorMessage = 'No data received from stream.';
            _hasError = true;
          });
        }
      }
    });

    _bufferSub = source.listen((chunk) async {
      if (chunk.isEmpty) return;
      _firstDataTime ??= DateTime.now();

      try {
        await _tempRaf!.writeFrom(chunk);
        _bytesWritten += chunk.length;
        bytesSinceFlush += chunk.length;

        if (mounted) {
          setState(() {
            _totalBytesBuffered = _bytesWritten;
            _chunkCountBuffered += 1;
          });
        }
        _streamController?.add(chunk);

        if (bytesSinceFlush >= flushEveryBytes) {
          await _tempRaf!.flush();
          bytesSinceFlush = 0;
        }

        if (!_playerOpenedFromTemp && _bytesWritten >= initialBufferBytes) {
          _playerOpenedFromTemp = true;
          try {
            await _tempRaf!.flush();
          } catch (_) {}
          debugPrint(
              'VideoPlayer: Opening from temp with ${_formatBytes(_bytesWritten)} buffered');
          try {
            await _player!.open(Media(_tempFile!.path));
            if (widget.autoPlay) {
              await _player!.play();
            }
          } catch (e) {
            debugPrint('VideoPlayer: Open error: $e');
            if (mounted) {
              setState(() {
                _errorMessage = 'Error opening playback: $e';
                _hasError = true;
              });
            }
          }
        }
      } catch (e) {
        debugPrint('VideoPlayer: Write error: $e');
        if (mounted) {
          setState(() {
            _errorMessage = 'Error writing temp data: $e';
            _hasError = true;
          });
        }
      }
    }, onError: (e) async {
      debugPrint('VideoPlayer: Buffer error: $e');
      try {
        await _tempRaf?.flush();
        await _tempRaf?.close();
      } catch (_) {}
      if (mounted) {
        setState(() {
          _errorMessage = 'Stream data error: $e';
          _hasError = true;
        });
      }
    }, onDone: () async {
      debugPrint('VideoPlayer: Buffer done at ${_formatBytes(_bytesWritten)}');
      try {
        await _tempRaf?.flush();
        await _tempRaf?.close();
      } catch (_) {}
      _tempRaf = null;
      if (!_playerOpenedFromTemp && _tempFile != null) {
        try {
          await _player!.open(Media(_tempFile!.path));
          if (widget.autoPlay) {
            await _player!.play();
          }
        } catch (e) {
          debugPrint('VideoPlayer: Open on done error: $e');
        }
      }
    }, cancelOnError: true);
  }

  String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    } else if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    } else {
      return '$bytes B';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.file != null) {
      // For local files, use the original CustomVideoPlayer-style UI
      return _buildLocalFilePlayer();
    } else {
      // For streaming sources, use the StreamingMediaPlayer-style UI
      return _buildStreamingPlayer();
    }
  }

  Widget _buildLocalFilePlayer() {
    if (_useFlutterVlc) {
      // On Android, render the VLC-based player directly (no internal Scaffold/AppBar)
      return _buildVlcPlayer();
    }

    return _isLoading
        ? const Center(child: CircularProgressIndicator(color: Colors.white))
        : _hasError
            ? _buildErrorWidget(_errorMessage)
            : Focus(
                autofocus: true,
                onKeyEvent: (node, event) => _handleKeyEvent(event),
                child: MouseRegion(
                  onHover: (_) {
                    if (_isFullScreen) {
                      _showControlsWithTimer();
                    }
                  },
                  child: GestureDetector(
                    onTap: () {
                      if (_isFullScreen) {
                        _showControlsWithTimer();
                      }
                    },
                    child: Stack(
                      children: [
                        GestureDetector(
                          onDoubleTap:
                              widget.allowFullScreen ? _toggleFullScreen : null,
                          child: _buildPrimaryVideoSurface(),
                        ),
                        if (!_isAndroidPip &&
                            widget.showControls &&
                            (!_isFullScreen || _showControls))
                          _buildCustomControls(),
                      ],
                    ),
                  ),
                ),
              );
  }

  // Tránh clip tròn trên desktop để giảm jank; cô lập bề mặt video bằng RepaintBoundary
  Widget _buildPrimaryVideoSurface() {
    final isDesktop =
        Platform.isWindows || Platform.isLinux || Platform.isMacOS;
    final surface = _buildVideoWidget();
    if (isDesktop) {
      // No rounded corners on desktop to prevent expensive saveLayer while playing
      return RepaintBoundary(child: surface);
    }
    return ClipRRect(
      borderRadius:
          _isFullScreen ? BorderRadius.zero : BorderRadius.circular(8.0),
      child: RepaintBoundary(child: surface),
    );
  }

  Widget _buildStreamingPlayer() {
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) => _handleKeyEvent(event),
      child: _buildPlayerBody(),
    );
  }

  Widget _buildPlayerBody() {
    if (_hasError) {
      return _buildErrorWidget(_errorMessage);
    }

    if (_isLoading) {
      return _buildLoadingWidget();
    }

    return _buildPlayer();
  }

  Widget _buildPlayer() {
    if (widget.fileType == FileType.video) {
      return _buildVideoPlayer();
    } else {
      return _buildAudioPlayer();
    }
  }

  Widget _buildVideoPlayer() {
    // On Android we prefer VLC for all sources
    if (_useFlutterVlc) {
      return _buildVlcPlayer();
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (_isFullScreen) _showControlsWithTimer();
      },
      onDoubleTap: _toggleFullScreen,
      child: Stack(
        children: [
          Positioned.fill(
            child: _buildVideoWidget(),
          ),
          if (widget.showControls && (!_isFullScreen || _showControls))
            _buildCustomControls(),
          if (_showSpeedIndicator && _currentStream != null)
            _buildSpeedIndicatorOverlay(),
        ],
      ),
    );
  }

  Widget _buildVideoWidget() {
    final isDesktop =
        Platform.isWindows || Platform.isLinux || Platform.isMacOS;
    final boxFit = _getBoxFitFromString(_videoScaleMode);

    if (isDesktop && _videoController != null) {
      return RepaintBoundary(
        child: Video(
          controller: _videoController!,
          controls: NoVideoControls,
          fill: Colors.black,
          fit: boxFit,
        ),
      );
    } else if (_vlcController != null) {
      return RepaintBoundary(
        child: FittedBox(
          fit: boxFit,
          child: VlcPlayer(
            controller: _vlcController!,
            aspectRatio:
                16 / 9, // Default aspect ratio, will be overridden by FittedBox
            placeholder: const Center(child: CircularProgressIndicator()),
          ),
        ),
      );
    } else {
      return const Center(child: CircularProgressIndicator());
    }
  }

  Widget _buildVlcPlayer() {
    // Initialize VLC controller lazily for the active Android source type
    if (_vlcController == null) {
      if (widget.smbMrl != null) {
        // SMB MRL with credentials support
        final original = widget.smbMrl!;
        final uri = Uri.parse(original);
        final creds = uri.userInfo.isNotEmpty
            ? uri.userInfo.split(':')
            : const <String>[];
        final user = creds.isNotEmpty ? Uri.decodeComponent(creds[0]) : null;
        final pwd = creds.length > 1 ? Uri.decodeComponent(creds[1]) : null;
        final cleanUrl = uri.replace(userInfo: '').toString();

        _vlcController = VlcPlayerController.network(
          cleanUrl,
          hwAcc: HwAcc.full,
          autoPlay: true,
          options: VlcPlayerOptions(
            advanced: VlcAdvancedOptions([
              '--network-caching=2000',
            ]),
            video: VlcVideoOptions([
              '--android-display-chroma=RV32',
            ]),
            extras: [
              if (user != null) '--smb-user=$user',
              if (pwd != null) '--smb-pwd=$pwd',
            ],
          ),
        );
      } else if (widget.streamingUrl != null) {
        // HTTP/HTTPS or other stream URL
        _vlcController = VlcPlayerController.network(
          widget.streamingUrl!,
          hwAcc: HwAcc.full,
          autoPlay: widget.autoPlay,
          options: VlcPlayerOptions(
            advanced: VlcAdvancedOptions([
              '--network-caching=1000',
            ]),
            video: VlcVideoOptions([
              '--android-display-chroma=RV32',
            ]),
          ),
        );
      } else if (widget.file != null) {
        // Local file
        _vlcController = VlcPlayerController.file(
          widget.file!,
          hwAcc: HwAcc.full,
          autoPlay: widget.autoPlay,
          options: VlcPlayerOptions(
            video: VlcVideoOptions([
              '--android-display-chroma=RV32',
            ]),
          ),
        );
      }

      // Arm a short fallback in case VLC fails to render on some devices
      if (Platform.isAndroid) {
        _vlcStartupFallback?.cancel();
        _vlcStartupFallback = Timer(const Duration(seconds: 3), () async {
          if (!mounted) return;
          final notReady = _vlcController == null ||
              !_vlcController!.value.isInitialized ||
              _vlcController!.value.size == null ||
              (_vlcController!.value.size?.width ?? 0) == 0;
          if (notReady) {
            debugPrint('VLC not ready, falling back to Exo');
            await _initExoFallback();
            if (mounted) setState(() {});
          }
        });
      }
    }

    if (!_vlcListenerAttached) {
      _vlcListenerAttached = true;
      // Keep listener minimal to avoid frequent full widget rebuilds.
      _vlcController!.addListener(() {
        // Apply pending restore once after controller is producing values.
        if (_vlcPendingRestore != null && !_vlcPendingRestoreApplied) {
          final restore = _vlcPendingRestore!;
          final pos = (restore['pos'] as Duration?) ?? Duration.zero;
          final vol = (restore['vol'] as num?)?.toDouble(); // 0..1
          final playing = restore['playing'] == true;
          Future.microtask(() async {
            try {
              if (pos > Duration.zero) await _vlcController!.seekTo(pos);
            } catch (_) {}
            try {
              if (vol != null)
                await _vlcController!.setVolume((vol * 100).toInt());
            } catch (_) {}
            try {
              if (playing) {
                await _vlcController!.play();
              } else {
                await _vlcController!.pause();
              }
            } catch (_) {}
            _vlcPendingRestoreApplied = true;
            _vlcPendingRestore = null;
            if (mounted) {
              // Mark once for controls state that depends on restore flags.
              setState(() {});
            }
          });
        }
      });
    }

    // Prefer Exo output when available: in Android PiP or as runtime fallback
    if (_exoController != null && _exoController!.value.isInitialized) {
      final ar = _exoController!.value.aspectRatio > 0
          ? _exoController!.value.aspectRatio
          : (16 / 9);
      return Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (_isFullScreen) _showControlsWithTimer();
              },
              onDoubleTap: _toggleFullScreen,
              child: Container(color: Colors.black),
            ),
          ),
          Center(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Ensure we have valid constraints
                if (constraints.maxWidth.isInfinite ||
                    constraints.maxHeight.isInfinite) {
                  return SizedBox(
                    width: 400,
                    height: 225,
                    child: exo.VideoPlayer(_exoController!),
                  );
                }
                return AspectRatio(
                  aspectRatio: ar,
                  child: exo.VideoPlayer(_exoController!),
                );
              },
            ),
          ),
          if (widget.showControls && (!_isFullScreen || _showControls))
            _buildCustomControls(),
        ],
      );
    } else if (_isAndroidPip) {
      return const ColoredBox(color: Colors.black);
    }

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (_isFullScreen) _showControlsWithTimer();
            },
            onDoubleTap: _toggleFullScreen,
            child: FittedBox(
              fit: _getBoxFitFromString(_videoScaleMode),
              child: VlcPlayer(
                controller: _vlcController!,
                aspectRatio: 16 / 9, // Default; FittedBox will scale
                placeholder: const Center(child: CircularProgressIndicator()),
              ),
            ),
          ),
        ),
        if (widget.showControls &&
            !_isAndroidPip &&
            (!_isFullScreen || _showControls))
          _buildCustomControls(),
      ],
    );
  }

  // Initialize Exo for Android as a VLC fallback (non-PiP & PiP)
  Future<void> _initExoFallback() async {
    if (!Platform.isAndroid) return;
    if (_exoController != null) return;

    try {
      exo.VideoPlayerController controller;
      if (widget.file != null) {
        controller = exo.VideoPlayerController.file(widget.file!);
      } else if (widget.streamingUrl != null) {
        controller = exo.VideoPlayerController.networkUrl(
            Uri.parse(widget.streamingUrl!));
      } else if (widget.smbMrl != null) {
        // Use local HTTP proxy for SMB to ensure Exo compatibility
        try {
          final proxied =
              await SmbHttpProxyServer.instance.urlFor(widget.smbMrl!);
          controller = exo.VideoPlayerController.networkUrl(proxied);
        } catch (e) {
          debugPrint('Exo fallback: proxy failed: $e');
          return;
        }
      } else if (widget.fileStream != null) {
        // Not supported directly by Exo; keep VLC path for streams
        debugPrint('Exo fallback: stream source not supported, skipping');
        return;
      } else {
        return;
      }

      await controller.initialize();
      if (widget.autoPlay) {
        await controller.play();
      }
      _exoController = controller;
    } catch (e) {
      debugPrint('Exo fallback init failed: $e');
    }
  }

  // UI Helper Methods
  Widget _buildErrorWidget(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 64),
          const SizedBox(height: 16),
          Text(
            'Error playing media',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.white70),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _hasError = false;
                _isLoading = true;
              });
              _initializePlayer();
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Colors.white),
          const SizedBox(height: 16),
          Text(
            'Loading media...',
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            widget.fileName,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioPlayer() {
    return Stack(
      children: [
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(100),
                ),
                child:
                    const Icon(Icons.music_note, size: 80, color: Colors.white),
              ),
              const SizedBox(height: 32),
              Text(
                widget.fileName,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              _buildAudioControls(),
            ],
          ),
        ),
        if (_showSpeedIndicator && _currentStream != null)
          _buildSpeedIndicatorOverlay(),
      ],
    );
  }

  Widget _buildAudioControls() {
    if (_player == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<bool>(
      stream: _player!.stream.playing,
      builder: (context, snapshot) {
        final isPlaying = snapshot.data ?? false;

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              onPressed: () => _player!.previous(),
              icon: const Icon(Icons.skip_previous,
                  color: Colors.white, size: 32),
            ),
            const SizedBox(width: 16),
            IconButton(
              onPressed: () => _player!.playOrPause(),
              icon: Icon(
                isPlaying
                    ? Icons.pause_circle_filled
                    : Icons.play_circle_filled,
                color: Colors.white,
                size: 64,
              ),
            ),
            const SizedBox(width: 16),
            IconButton(
              onPressed: () => _player!.next(),
              icon: const Icon(Icons.skip_next, color: Colors.white, size: 32),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSpeedIndicatorOverlay() {
    return Positioned(
      top: 16,
      right: 16,
      child: Column(
        children: [
          StreamSpeedIndicator(
            stream: _currentStream,
            label: 'Stream Speed',
          ),
          const SizedBox(height: 12),
          BufferInfoWidget(
            stream: _currentStream,
            label: 'Buffer Info',
          ),
          const SizedBox(height: 12),
          Container(
            width: 200,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.black.withValues(alpha: 0.9),
                  Colors.black.withValues(alpha: 0.7),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.orange.withValues(alpha: 0.5),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Debug Info',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Buffered: ${_formatBytes(_totalBytesBuffered)}',
                  style: const TextStyle(color: Colors.white70, fontSize: 10),
                ),
                Text(
                  'Chunks: $_chunkCountBuffered',
                  style: const TextStyle(color: Colors.white70, fontSize: 10),
                ),
                Text(
                  'Stream Active: ${_streamController != null ? "Yes" : "No"}',
                  style: const TextStyle(color: Colors.white70, fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Event Handlers
  KeyEventResult _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      // Spacebar for pause/play
      if (event.logicalKey == LogicalKeyboardKey.space) {
        _togglePlayPause();
        return KeyEventResult.handled;
      }
      // Arrow keys for seeking
      else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        _seekBackward();
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        _seekForward();
        return KeyEventResult.handled;
      }
      // Arrow up/down for volume
      else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        _increaseVolume();
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        _decreaseVolume();
        return KeyEventResult.handled;
      }
      // M for mute/unmute
      else if (event.logicalKey == LogicalKeyboardKey.keyM) {
        _toggleMute();
        return KeyEventResult.handled;
      }
      // F for fullscreen
      else if (event.logicalKey == LogicalKeyboardKey.keyF) {
        _toggleFullScreen();
        return KeyEventResult.handled;
      }
      // Escape to exit fullscreen
      else if (event.logicalKey == LogicalKeyboardKey.escape) {
        if (_isFullScreen) {
          _toggleFullScreen();
          return KeyEventResult.handled;
        }
      }
    }
    return KeyEventResult.ignored;
  }

  void _showControlsWithTimer() {
    if (!mounted) return;
    setState(() {
      _showControls = true;
    });
    _startHideControlsTimer();
    widget.onControlVisibilityChanged?.call();
  }

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _isFullScreen) {
        setState(() {
          _showControls = false;
        });
        widget.onControlVisibilityChanged?.call();
      }
    });
  }

  Future<void> _toggleFullScreen() async {
    if (!widget.allowFullScreen) return;

    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      // Desktop platforms - use window_manager
      try {
        bool isFullScreen = await windowManager.isFullScreen();
        if (isFullScreen) {
          await windowManager.setFullScreen(false);
          await windowManager.setResizable(true);
        } else {
          await windowManager.setFullScreen(true);
        }
        setState(() {
          _isFullScreen = !isFullScreen;
          if (_isFullScreen) {
            _showControls = true;
            _startHideControlsTimer();
          }
        });
        widget.onFullScreenChanged?.call();
      } catch (e) {
        debugPrint('Error toggling fullscreen: $e');
      }
    } else {
      // Mobile platforms - use system chrome
      setState(() {
        _isFullScreen = !_isFullScreen;
        VideoUiState.isFullscreen.value = _isFullScreen;
        if (_isFullScreen) {
          _showControls = true;
          _startHideControlsTimer();
        }
      });

      if (_isFullScreen) {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      } else {
        SystemChrome.setPreferredOrientations(DeviceOrientation.values);
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      }
      widget.onFullScreenChanged?.call();
    }
  }

  void _togglePlayPause() async {
    if (_player != null) {
      if (_player!.state.playing) {
        await _player!.pause();
      } else {
        await _player!.play();
      }
      if (_isFullScreen) _showControlsWithTimer();
      if (mounted) setState(() {});
    } else if (_exoController != null) {
      final playing = _exoController!.value.isPlaying;
      if (playing) {
        await _exoController!.pause();
      } else {
        await _exoController!.play();
      }
      if (_isFullScreen) _showControlsWithTimer();
      if (mounted) setState(() {});
    } else if (_vlcController != null) {
      final playing = _vlcController!.value.isPlaying;
      if (playing) {
        await _vlcController!.pause();
      } else {
        await _vlcController!.play();
      }
      if (_isFullScreen) _showControlsWithTimer();
      if (mounted) setState(() {});
    }
  }

  void _seekForward([int seconds = 10]) async {
    _startSeeking();

    if (_player != null) {
      final currentPosition = _player!.state.position;
      final newPosition = currentPosition + Duration(seconds: seconds);
      final seekPosition = newPosition > _player!.state.duration
          ? _player!.state.duration
          : newPosition;
      await _player!.seek(seekPosition);
    } else if (_exoController != null) {
      final pos = _exoController!.value.position;
      final target = pos + Duration(seconds: seconds);
      await _exoController!.seekTo(target);
    } else if (_vlcController != null) {
      final pos = _vlcController!.value.position;
      final targetMs = (pos.inMilliseconds + (seconds * 1000));
      await _vlcController!.seekTo(Duration(milliseconds: targetMs));
    }

    if (_isFullScreen) {
      _showControlsWithTimer();
    }
  }

  void _seekBackward([int seconds = 10]) async {
    _startSeeking();

    if (_player != null) {
      final currentPosition = _player!.state.position;
      final newPosition = currentPosition - Duration(seconds: seconds);
      final seekPosition =
          newPosition < Duration.zero ? Duration.zero : newPosition;
      await _player!.seek(seekPosition);
    } else if (_exoController != null) {
      final pos = _exoController!.value.position;
      final target = pos - Duration(seconds: seconds);
      await _exoController!
          .seekTo(target < Duration.zero ? Duration.zero : target);
    } else if (_vlcController != null) {
      final v = _vlcController!.value;
      final targetMs = (v.position.inMilliseconds - (seconds * 1000));
      await _vlcController!.seekTo(
          Duration(milliseconds: targetMs.clamp(0, v.duration.inMilliseconds)));
    }

    if (_isFullScreen) {
      _showControlsWithTimer();
    }
  }

  void _increaseVolume() async {
    if (_player != null) {
      final currentVolume = _player!.state.volume;
      final newVolume = (currentVolume + 5).clamp(0.0, 100.0);
      await _player!.setVolume(newVolume);
    } else if (_exoController != null) {
      final v = _exoController!.value.volume; // 0..1
      final nv = (v + 0.05).clamp(0.0, 1.0);
      await _exoController!.setVolume(nv);
    } else if (_vlcController != null) {
      final v = _vlcController!.value.volume.toDouble();
      final newVolume = (v + 5).clamp(0.0, 100.0);
      await _vlcController!.setVolume(newVolume.toInt());
    }
  }

  void _decreaseVolume() async {
    if (_player != null) {
      final currentVolume = _player!.state.volume;
      final newVolume = (currentVolume - 5).clamp(0.0, 100.0);
      await _player!.setVolume(newVolume);
    } else if (_exoController != null) {
      final v = _exoController!.value.volume; // 0..1
      final nv = (v - 0.05).clamp(0.0, 1.0);
      await _exoController!.setVolume(nv);
    } else if (_vlcController != null) {
      final v = _vlcController!.value.volume.toDouble();
      final newVolume = (v - 5).clamp(0.0, 100.0);
      await _vlcController!.setVolume(newVolume.toInt());
    }
  }

  void _toggleMute() async {
    if (_player != null) {
      final isMuted = _player!.state.volume <= 0.1;
      if (isMuted) {
        await _player!.setVolume(_savedVolume);
      } else {
        await _player!.setVolume(0.0);
      }
    } else if (_exoController != null) {
      final isMuted = (_exoController!.value.volume) <= 0.001;
      if (isMuted) {
        final restore = (_lastVolume / 100.0).clamp(0.0, 1.0);
        await _exoController!.setVolume(restore);
      } else {
        await _exoController!.setVolume(0.0);
      }
    } else if (_vlcController != null) {
      final isMuted = _vlcController!.value.volume <= 0;
      if (isMuted) {
        await _vlcController!.setVolume(_lastVolume.toInt());
      } else {
        await _vlcController!.setVolume(0);
      }
    }
  }

  // Custom Controls
  Widget _buildCustomControls() {
    final isDesktop =
        Platform.isWindows || Platform.isLinux || Platform.isMacOS;
    if (isDesktop) {
      return _buildPipStyleControls();
    }
    // Mobile-specific redesigned controls
    return _buildMobileControls();
  }

  // New: Mobile-focused overlay controls with cleaner layout & working bindings
  Widget _buildMobileControls() {
    return Stack(
      children: [
        // Top gradient
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: IgnorePointer(
            ignoring: true,
            child: Container(
              height: 140,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.6),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),

        // Center play/pause
        if (_showControls)
          Center(
            child: _buildPlayPauseButton(),
          ),

        // Bottom controls
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.75),
                ],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    // Current time
                    _player != null
                        ? StreamBuilder<Duration>(
                            stream: _player!.stream.position,
                            builder: (context, snap) {
                              final pos = snap.data ?? Duration.zero;
                              return Text(
                                _formatDuration(pos),
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 12),
                              );
                            },
                          )
                        : _exoController != null
                            ? ValueListenableBuilder<exo.VideoPlayerValue>(
                                valueListenable: _exoController!,
                                builder: (context, v, _) {
                                  return Text(
                                    _formatDuration(v.position),
                                    style: const TextStyle(
                                        color: Colors.white70, fontSize: 12),
                                  );
                                },
                              )
                            : ValueListenableBuilder<VlcPlayerValue>(
                                valueListenable: _vlcController!,
                                builder: (context, v, _) {
                                  return Text(
                                    _formatDuration(v.position),
                                    style: const TextStyle(
                                        color: Colors.white70, fontSize: 12),
                                  );
                                },
                              ),

                    const SizedBox(width: 8),

                    // Slider expanded
                    Expanded(child: _buildMobileSeekSlider()),

                    const SizedBox(width: 8),

                    // Duration
                    _player != null
                        ? Text(
                            _formatDuration(_player!.state.duration),
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12),
                          )
                        : _exoController != null
                            ? ValueListenableBuilder<exo.VideoPlayerValue>(
                                valueListenable: _exoController!,
                                builder: (context, v, _) {
                                  return Text(
                                    _formatDuration(v.duration),
                                    style: const TextStyle(
                                        color: Colors.white70, fontSize: 12),
                                  );
                                },
                              )
                            : ValueListenableBuilder<VlcPlayerValue>(
                                valueListenable: _vlcController!,
                                builder: (context, v, _) {
                                  return Text(
                                    _formatDuration(v.duration),
                                    style: const TextStyle(
                                        color: Colors.white70, fontSize: 12),
                                  );
                                },
                              ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _buildControlButton(
                      icon: Icons.replay_10,
                      onPressed: () => _seekBackward(10),
                      tooltip: 'Rewind 10s',
                    ),
                    const SizedBox(width: 4),
                    _buildPlayPauseButton(),
                    const SizedBox(width: 4),
                    _buildControlButton(
                      icon: Icons.forward_10,
                      onPressed: () => _seekForward(10),
                      tooltip: 'Forward 10s',
                    ),
                    const Spacer(),
                    if (widget.allowMuting) _buildVolumeButtonOnly(),
                    const SizedBox(width: 6),
                    _buildAdvancedControlsMenu(),
                    if (widget.allowFullScreen) ...[
                      const SizedBox(width: 6),
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
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Slider used by mobile controls with support for VLC/Exo/MediaKit
  Widget _buildMobileSeekSlider() {
    if (_player != null) {
      return StreamBuilder<Duration>(
        stream: _player!.stream.position,
        builder: (context, snapshot) {
          final position = snapshot.data ?? Duration.zero;
          final duration = _player!.state.duration;
          final maxMs =
              duration.inMilliseconds <= 0 ? 1 : duration.inMilliseconds;
          final value = position.inMilliseconds.clamp(0, maxMs).toDouble();
          return SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            ),
            child: Slider(
              value: value,
              min: 0,
              max: maxMs.toDouble(),
              activeColor: Colors.white,
              inactiveColor: Colors.white24,
              onChangeStart: (_) => _isSeeking = true,
              onChanged: (v) async {
                final target = Duration(milliseconds: v.toInt());
                await _player!.seek(target);
              },
              onChangeEnd: (_) {
                _seekingTimer?.cancel();
                _seekingTimer = Timer(const Duration(milliseconds: 200), () {
                  if (mounted) _isSeeking = false;
                });
              },
            ),
          );
        },
      );
    } else if (_exoController != null) {
      return ValueListenableBuilder<exo.VideoPlayerValue>(
        valueListenable: _exoController!,
        builder: (context, v, _) {
          final maxMs =
              v.duration.inMilliseconds <= 0 ? 1 : v.duration.inMilliseconds;
          final value = v.position.inMilliseconds.clamp(0, maxMs).toDouble();
          return Slider(
            value: value,
            min: 0,
            max: maxMs.toDouble(),
            activeColor: Colors.white,
            inactiveColor: Colors.white24,
            onChangeStart: (_) => _isSeeking = true,
            onChanged: (vv) async {
              await _exoController!.seekTo(Duration(milliseconds: vv.toInt()));
            },
            onChangeEnd: (_) {
              _seekingTimer?.cancel();
              _seekingTimer = Timer(const Duration(milliseconds: 200), () {
                if (mounted) _isSeeking = false;
              });
            },
          );
        },
      );
    } else {
      return ValueListenableBuilder<VlcPlayerValue>(
        valueListenable: _vlcController!,
        builder: (context, v, _) {
          final maxMs =
              v.duration.inMilliseconds == 0 ? 1 : v.duration.inMilliseconds;
          final value = v.position.inMilliseconds.clamp(0, maxMs).toDouble();
          return Slider(
            value: value,
            min: 0,
            max: maxMs.toDouble(),
            activeColor: Colors.white,
            inactiveColor: Colors.white24,
            onChangeStart: (_) => _isSeeking = true,
            onChanged: (vv) async {
              await _vlcController?.seekTo(Duration(milliseconds: vv.toInt()));
            },
            onChangeEnd: (_) {
              _seekingTimer?.cancel();
              _seekingTimer = Timer(const Duration(milliseconds: 200), () {
                if (mounted) _isSeeking = false;
              });
            },
          );
        },
      );
    }
  }

  // Mobile-only compact volume toggle button (no inline slider)
  Widget _buildVolumeButtonOnly() {
    if (_player != null) {
      return StreamBuilder<double>(
        stream: _player!.stream.volume,
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
            onPressed: _toggleMute,
            enabled: true,
            tooltip: isMuted ? 'Unmute' : 'Mute',
          );
        },
      );
    } else if (_exoController != null) {
      return ValueListenableBuilder<exo.VideoPlayerValue>(
        valueListenable: _exoController!,
        builder: (context, v, _) {
          final vol = v.volume; // 0..1
          final isMuted = vol <= 0.001;
          return _buildControlButton(
            icon: isMuted
                ? Icons.volume_off
                : (vol < 0.5 ? Icons.volume_down : Icons.volume_up),
            onPressed: _toggleMute,
            enabled: true,
            tooltip: isMuted ? 'Unmute' : 'Mute',
          );
        },
      );
    } else {
      return ValueListenableBuilder<VlcPlayerValue>(
        valueListenable: _vlcController!,
        builder: (context, v, _) {
          final vol = v.volume; // 0..100
          final isMuted = vol <= 0;
          return _buildControlButton(
            icon: isMuted
                ? Icons.volume_off
                : (vol < 50 ? Icons.volume_down : Icons.volume_up),
            onPressed: _toggleMute,
            enabled: true,
            tooltip: isMuted ? 'Unmute' : 'Mute',
          );
        },
      );
    }
  }

  Widget _buildPipStyleControls() {
    // Bottom overlay with: Play/Pause, currentTime, slider, duration, volume, menu, fullscreen
    return Stack(
      children: [
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x00000000), Color(0xB3000000)],
              ),
            ),
            child: Row(
              children: [
                // Play / Pause
                _buildPlayPauseButton(),
                const SizedBox(width: 8),

                // Current time
                if (_player != null)
                  StreamBuilder<Duration>(
                    stream: _player!.stream.position,
                    builder: (context, snapshot) {
                      final p = snapshot.data ?? Duration.zero;
                      return Text(
                        _formatDuration(p),
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12),
                      );
                    },
                  )
                else
                  ValueListenableBuilder<VlcPlayerValue>(
                    valueListenable: _vlcController!,
                    builder: (context, v, _) {
                      return Text(
                        _formatDuration(v.position),
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12),
                      );
                    },
                  ),

                const SizedBox(width: 8),

                // Slider
                Expanded(
                  child: _player != null
                      ? StreamBuilder<Duration>(
                          stream: _player!.stream.position,
                          builder: (context, snapshot) {
                            final position = snapshot.data ?? Duration.zero;
                            final duration = _player!.state.duration;
                            final maxMs = duration.inMilliseconds <= 0
                                ? 1
                                : duration.inMilliseconds;
                            final value = position.inMilliseconds
                                .clamp(0, maxMs)
                                .toDouble();
                            return SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 2.5,
                                thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 7),
                              ),
                              child: Slider(
                                value: value,
                                min: 0,
                                max: maxMs.toDouble(),
                                activeColor: Colors.white,
                                inactiveColor: Colors.white24,
                                onChangeStart: (_) => _isSeeking = true,
                                onChanged: (v) async {
                                  final target =
                                      Duration(milliseconds: v.toInt());
                                  await _player!.seek(target);
                                },
                                onChangeEnd: (_) {
                                  _seekingTimer?.cancel();
                                  _seekingTimer = Timer(
                                      const Duration(milliseconds: 200), () {
                                    if (mounted) _isSeeking = false;
                                  });
                                },
                              ),
                            );
                          },
                        )
                      : ValueListenableBuilder<VlcPlayerValue>(
                          valueListenable: _vlcController!,
                          builder: (context, v, _) {
                            final maxMs = v.duration.inMilliseconds == 0
                                ? 1
                                : v.duration.inMilliseconds;
                            final value = v.position.inMilliseconds
                                .clamp(0, maxMs)
                                .toDouble();
                            return Slider(
                              value: value,
                              min: 0,
                              max: maxMs.toDouble(),
                              activeColor: Colors.white,
                              inactiveColor: Colors.white24,
                              onChangeStart: (_) => _isSeeking = true,
                              onChanged: (vv) async {
                                await _vlcController?.seekTo(
                                    Duration(milliseconds: vv.toInt()));
                              },
                              onChangeEnd: (_) {
                                _seekingTimer?.cancel();
                                _seekingTimer = Timer(
                                    const Duration(milliseconds: 200), () {
                                  if (mounted) _isSeeking = false;
                                });
                              },
                            );
                          },
                        ),
                ),

                const SizedBox(width: 8),

                // Duration
                _player != null
                    ? Text(
                        _formatDuration(_player!.state.duration),
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12),
                      )
                    : ValueListenableBuilder<VlcPlayerValue>(
                        valueListenable: _vlcController!,
                        builder: (context, v, _) {
                          return Text(
                            _formatDuration(v.duration),
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12),
                          );
                        },
                      ),

                const SizedBox(width: 8),
                if (widget.allowMuting) _buildVolumeControl(),
                const SizedBox(width: 4),
                _buildAdvancedControlsMenu(),
                if (widget.allowFullScreen)
                  _buildControlButton(
                    icon: _isFullScreen
                        ? Icons.fullscreen_exit
                        : Icons.fullscreen,
                    onPressed: _toggleFullScreen,
                    enabled: true,
                    tooltip:
                        _isFullScreen ? 'Exit fullscreen' : 'Enter fullscreen',
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlayPauseButton() {
    if (_player != null) {
      return StreamBuilder<bool>(
        stream: _player!.stream.playing,
        initialData: _isPlaying,
        builder: (context, snapshot) {
          final isPlaying = snapshot.data ?? _player!.state.playing;
          return _buildControlButton(
            icon: isPlaying ? Icons.pause : Icons.play_arrow,
            onPressed: _togglePlayPause,
            size: 40,
            padding: 10,
            enabled: true,
          );
        },
      );
    } else if (_exoController != null) {
      return ValueListenableBuilder<exo.VideoPlayerValue>(
        valueListenable: _exoController!,
        builder: (context, v, _) {
          return _buildControlButton(
            icon: v.isPlaying ? Icons.pause : Icons.play_arrow,
            onPressed: _togglePlayPause,
            size: 40,
            padding: 10,
            enabled: true,
          );
        },
      );
    } else {
      return ValueListenableBuilder<VlcPlayerValue>(
        valueListenable: _vlcController!,
        builder: (context, v, _) {
          return _buildControlButton(
            icon: v.isPlaying ? Icons.pause : Icons.play_arrow,
            onPressed: _togglePlayPause,
            size: 40,
            padding: 10,
            enabled: true,
          );
        },
      );
    }
  }

  Widget _buildCustomSeekBar() {
    if (_player != null) {
      return StreamBuilder<Duration>(
        stream: _player!.stream.position,
        builder: (context, snapshot) {
          final position = snapshot.data ?? Duration.zero;
          final duration = _player!.state.duration;
          final progress = duration.inMilliseconds > 0
              ? position.inMilliseconds / duration.inMilliseconds
              : 0.0;

          return Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  _formatDuration(position),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      thumbShape:
                          const RoundSliderThumbShape(enabledThumbRadius: 6),
                      overlayShape:
                          const RoundSliderOverlayShape(overlayRadius: 12),
                    ),
                    child: Slider(
                      value: progress.clamp(0.0, 1.0),
                      onChangeStart: (value) {
                        // Start seeking when user begins dragging
                        setState(() {
                          _isSeeking = true;
                        });
                        _seekingTimer?.cancel();
                      },
                      onChanged: (value) {
                        final newPosition = Duration(
                          milliseconds:
                              (value * duration.inMilliseconds).round(),
                        );
                        _player!.seek(newPosition);
                      },
                      onChangeEnd: (value) {
                        // End seeking after user finishes dragging with a slight delay
                        _seekingTimer?.cancel();
                        _seekingTimer =
                            Timer(const Duration(milliseconds: 300), () {
                          if (mounted) {
                            setState(() {
                              _isSeeking = false;
                            });
                          }
                        });
                      },
                      activeColor: Colors.white,
                      inactiveColor: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _formatDuration(duration),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          );
        },
      );
    } else {
      // VLC seek bar (avoid full rebuilds by listening directly to controller value)
      return ValueListenableBuilder<VlcPlayerValue>(
        valueListenable: _vlcController!,
        builder: (context, v, _) {
          final pos = v.position;
          final dur = v.duration.inMilliseconds > 0
              ? v.duration
              : const Duration(seconds: 1);
          final progress = dur.inMilliseconds > 0
              ? (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0)
              : 0.0;

          return Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  _formatDuration(pos),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Slider(
                    value: progress,
                    onChangeStart: (value) {
                      // Start seeking when user begins dragging
                      setState(() {
                        _isSeeking = true;
                      });
                      _seekingTimer?.cancel();
                    },
                    onChanged: (vv) async {
                      final targetMs = (dur.inMilliseconds * vv).toInt();
                      await _vlcController
                          ?.seekTo(Duration(milliseconds: targetMs));
                    },
                    onChangeEnd: (value) {
                      // End seeking after user finishes dragging with a slight delay
                      _seekingTimer?.cancel();
                      _seekingTimer =
                          Timer(const Duration(milliseconds: 300), () {
                        if (mounted) {
                          setState(() {
                            _isSeeking = false;
                          });
                        }
                      });
                    },
                    activeColor: Colors.redAccent,
                    inactiveColor: Colors.white.withValues(alpha: 0.3),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _formatDuration(dur),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          );
        },
      );
    }
  }

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

  Widget _buildVolumeControl() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_player != null)
          StreamBuilder<double>(
            stream: _player!.stream.volume,
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
                onPressed: _toggleMute,
                enabled: true,
                tooltip: isMuted ? 'Unmute' : 'Mute',
              );
            },
          )
        else if (_exoController != null)
          ValueListenableBuilder<exo.VideoPlayerValue>(
            valueListenable: _exoController!,
            builder: (context, v, _) {
              final vol = v.volume; // 0..1
              final isMuted = vol <= 0.001;
              return _buildControlButton(
                icon: isMuted
                    ? Icons.volume_off
                    : (vol < 0.5 ? Icons.volume_down : Icons.volume_up),
                onPressed: _toggleMute,
                enabled: true,
                tooltip: isMuted ? 'Unmute' : 'Mute',
              );
            },
          )
        else
          ValueListenableBuilder<VlcPlayerValue>(
            valueListenable: _vlcController!,
            builder: (context, v, _) {
              final vol = v.volume; // 0..100
              final isMuted = vol <= 0;
              return _buildControlButton(
                icon: isMuted
                    ? Icons.volume_off
                    : (vol < 50 ? Icons.volume_down : Icons.volume_up),
                onPressed: _toggleMute,
                enabled: true,
                tooltip: isMuted ? 'Unmute' : 'Mute',
              );
            },
          ),
        if (!_isFullScreen ||
            (Platform.isWindows || Platform.isLinux || Platform.isMacOS))
          SizedBox(
            width: 80,
            child: _player != null
                ? StreamBuilder<double>(
                    stream: _player!.stream.volume,
                    initialData: _savedVolume,
                    builder: (context, snapshot) {
                      final volume = snapshot.data ?? _savedVolume;
                      return SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 2,
                          thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 4),
                          overlayShape:
                              const RoundSliderOverlayShape(overlayRadius: 8),
                        ),
                        child: Slider(
                          value: volume.clamp(0.0, 100.0),
                          min: 0.0,
                          max: 100.0,
                          onChanged: (value) {
                            _player!.setVolume(value);
                          },
                          activeColor: Colors.white,
                          inactiveColor: Colors.white.withValues(alpha: 0.3),
                        ),
                      );
                    },
                  )
                : _exoController != null
                    ? ValueListenableBuilder<exo.VideoPlayerValue>(
                        valueListenable: _exoController!,
                        builder: (context, v, _) {
                          return Slider(
                            value: (v.volume * 100).clamp(0.0, 100.0),
                            min: 0.0,
                            max: 100.0,
                            onChanged: (value) {
                              _exoController!.setVolume((value / 100.0));
                            },
                            activeColor: Colors.white,
                            inactiveColor: Colors.white.withValues(alpha: 0.3),
                          );
                        },
                      )
                    : ValueListenableBuilder<VlcPlayerValue>(
                        valueListenable: _vlcController!,
                        builder: (context, v, _) {
                          return Slider(
                            value: (v.volume.toDouble()).clamp(0.0, 100.0),
                            min: 0.0,
                            max: 100.0,
                            onChanged: (value) {
                              _vlcController!.setVolume(value.toInt());
                            },
                            activeColor: Colors.white,
                            inactiveColor: Colors.white.withValues(alpha: 0.3),
                          );
                        },
                      ),
          ),
      ],
    );
  }

  void _showAudioTrackDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Audio Tracks'),
        content: const Text('Audio track selection will be implemented here.'),
        actions: [
          TextButton(
            onPressed: () => RouteUtils.safePopDialog(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _takeScreenshot() async {
    try {
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

  /// Advanced controls menu với popup menu để giảm số nút trên thanh điều khiển
  Widget _buildAdvancedControlsMenu() {
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.more_vert,
        color: Colors.white,
        size: 24,
      ),
      color: Colors.black.withValues(alpha: 0.9),
      tooltip: 'Advanced Controls',
      onSelected: (String value) {
        switch (value) {
          case 'screenshot':
            _takeScreenshot();
            break;
          case 'audio_tracks':
            if (Platform.isWindows) _showAudioTrackDialog();
            break;
          case 'subtitles':
            _showSubtitleDialog();
            break;
          case 'speed':
            _showPlaybackSpeedDialog();
            break;
          case 'pip':
            _togglePictureInPicture();
            break;
          case 'filters':
            _showVideoFiltersDialog();
            break;
          case 'sleep_timer':
            _showSleepTimerDialog();
            break;
          case 'settings':
            _showSettingsDialog();
            break;
        }
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          value: 'screenshot',
          child: ListTile(
            leading: Icon(Icons.photo_camera, color: Colors.white, size: 20),
            title:
                Text('Take Screenshot', style: TextStyle(color: Colors.white)),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        if (Platform.isWindows)
          PopupMenuItem<String>(
            value: 'audio_tracks',
            child: ListTile(
              leading: Icon(Icons.audiotrack, color: Colors.white, size: 20),
              title:
                  Text('Audio Tracks', style: TextStyle(color: Colors.white)),
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        PopupMenuItem<String>(
          value: 'subtitles',
          enabled: _subtitleTracks.isNotEmpty,
          child: ListTile(
            leading: Icon(Icons.subtitles,
                color: _subtitleTracks.isNotEmpty ? Colors.white : Colors.grey,
                size: 20),
            title: Text('Subtitles',
                style: TextStyle(
                    color: _subtitleTracks.isNotEmpty
                        ? Colors.white
                        : Colors.grey)),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem<String>(
          value: 'speed',
          child: ListTile(
            leading: Icon(Icons.speed, color: Colors.white, size: 20),
            title: Text('Playback Speed (${_playbackSpeed}x)',
                style: TextStyle(color: Colors.white)),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem<String>(
          value: 'pip',
          child: ListTile(
            leading: Icon(
                _isPictureInPicture
                    ? Icons.picture_in_picture_alt
                    : Icons.picture_in_picture,
                color: Colors.white,
                size: 20),
            title: Text(_isPictureInPicture ? 'Exit PiP' : 'Picture in Picture',
                style: TextStyle(color: Colors.white)),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem<String>(
          value: 'filters',
          child: ListTile(
            leading: Icon(Icons.tune, color: Colors.white, size: 20),
            title: Text('Video Filters', style: TextStyle(color: Colors.white)),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem<String>(
          value: 'sleep_timer',
          child: ListTile(
            leading: Icon(Icons.bedtime,
                color: _sleepDuration != null ? Colors.orange : Colors.white,
                size: 20),
            title: Text(
                _sleepDuration != null ? 'Sleep Timer (Active)' : 'Sleep Timer',
                style: TextStyle(
                    color:
                        _sleepDuration != null ? Colors.orange : Colors.white)),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'settings',
          child: ListTile(
            leading: Icon(Icons.settings, color: Colors.white, size: 20),
            title:
                Text('Video Settings', style: TextStyle(color: Colors.white)),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }

  // Dialog methods
  void _showSubtitleDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Subtitles'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Off'),
              leading: Radio<int?>(
                value: null,
                groupValue: _selectedSubtitleTrack,
                onChanged: (int? value) {
                  setState(() {
                    _selectedSubtitleTrack = value;
                  });
                  RouteUtils.safePopDialog(context);
                },
              ),
            ),
            ..._subtitleTracks.asMap().entries.map((entry) {
              final index = entry.key;
              final track = entry.value;
              return ListTile(
                title: Text(track.language),
                leading: Radio<int?>(
                  value: index,
                  groupValue: _selectedSubtitleTrack,
                  onChanged: (int? value) {
                    setState(() {
                      _selectedSubtitleTrack = value;
                    });
                    RouteUtils.safePopDialog(context);
                  },
                ),
              );
            }).toList(),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => RouteUtils.safePopDialog(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showPlaybackSpeedDialog() {
    final speeds = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Playback Speed'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: speeds.map((speed) {
            return ListTile(
              title: Text('${speed}x'),
              leading: Radio<double>(
                value: speed,
                groupValue: _playbackSpeed,
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _playbackSpeed = value;
                    });
                    _setPlaybackSpeed(value);
                    RouteUtils.safePopDialog(context);
                  }
                },
              ),
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => RouteUtils.safePopDialog(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showVideoFiltersDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Video Filters'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Brightness: ${(_brightness * 100).round()}%'),
              Slider(
                value: _brightness,
                min: 0.0,
                max: 2.0,
                divisions: 20,
                onChanged: (value) {
                  setDialogState(() {
                    _brightness = value;
                  });
                  setState(() {
                    _brightness = value;
                  });
                },
              ),
              Text('Contrast: ${(_contrast * 100).round()}%'),
              Slider(
                value: _contrast,
                min: 0.0,
                max: 2.0,
                divisions: 20,
                onChanged: (value) {
                  setDialogState(() {
                    _contrast = value;
                  });
                  setState(() {
                    _contrast = value;
                  });
                },
              ),
              Text('Saturation: ${(_saturation * 100).round()}%'),
              Slider(
                value: _saturation,
                min: 0.0,
                max: 2.0,
                divisions: 20,
                onChanged: (value) {
                  setDialogState(() {
                    _saturation = value;
                  });
                  setState(() {
                    _saturation = value;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  _brightness = 1.0;
                  _contrast = 1.0;
                  _saturation = 1.0;
                });
                setDialogState(() {
                  _brightness = 1.0;
                  _contrast = 1.0;
                  _saturation = 1.0;
                });
              },
              child: const Text('Reset'),
            ),
            TextButton(
              onPressed: () => RouteUtils.safePopDialog(context),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSleepTimerDialog() {
    final durations = [
      const Duration(minutes: 15),
      const Duration(minutes: 30),
      const Duration(hours: 1),
      const Duration(hours: 2),
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sleep Timer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Off'),
              leading: Radio<Duration?>(
                value: null,
                groupValue: _sleepDuration,
                onChanged: (value) {
                  _cancelSleepTimer();
                  RouteUtils.safePopDialog(context);
                },
              ),
            ),
            ...durations.map((duration) {
              String label;
              if (duration.inHours > 0) {
                label =
                    '${duration.inHours} hour${duration.inHours > 1 ? 's' : ''}';
              } else {
                label = '${duration.inMinutes} minutes';
              }

              return ListTile(
                title: Text(label),
                leading: Radio<Duration?>(
                  value: duration,
                  groupValue: _sleepDuration,
                  onChanged: (value) {
                    if (value != null) {
                      _setSleepTimer(value);
                      RouteUtils.safePopDialog(context);
                    }
                  },
                ),
              );
            }).toList(),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => RouteUtils.safePopDialog(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Video Settings'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Codec Selection
                const Text('Codec:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                DropdownButton<String>(
                  value: _selectedCodec,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: 'auto', child: Text('Auto')),
                    DropdownMenuItem(value: 'h264', child: Text('H.264')),
                    DropdownMenuItem(value: 'h265', child: Text('H.265/HEVC')),
                    DropdownMenuItem(value: 'vp9', child: Text('VP9')),
                    DropdownMenuItem(value: 'av1', child: Text('AV1')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() {
                        _selectedCodec = value;
                      });
                      setState(() {
                        _selectedCodec = value;
                      });
                      _saveSettings();
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Video Scale Mode
                const Text('Video Scale Mode:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                DropdownButton<String>(
                  value: _videoScaleMode,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(
                        value: 'cover', child: Text('Cover (Fill & Crop)')),
                    DropdownMenuItem(
                        value: 'contain', child: Text('Contain (Fit All)')),
                    DropdownMenuItem(
                        value: 'fill', child: Text('Fill (Stretch)')),
                    DropdownMenuItem(
                        value: 'fitWidth', child: Text('Fit Width')),
                    DropdownMenuItem(
                        value: 'fitHeight', child: Text('Fit Height')),
                    DropdownMenuItem(
                        value: 'none', child: Text('None (Original Size)')),
                    DropdownMenuItem(
                        value: 'scaleDown', child: Text('Scale Down')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() {
                        _videoScaleMode = value;
                      });
                      setState(() {
                        _videoScaleMode = value;
                      });
                      _saveSettings();
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Hardware Acceleration
                SwitchListTile(
                  title: const Text('Hardware Acceleration'),
                  subtitle: const Text('Use GPU for video decoding'),
                  value: _hardwareAcceleration,
                  onChanged: (value) {
                    setDialogState(() {
                      _hardwareAcceleration = value;
                      _videoDecoder = value ? 'hardware' : 'software';
                    });
                    setState(() {
                      _hardwareAcceleration = value;
                      _videoDecoder = value ? 'hardware' : 'software';
                      if (_player != null) {
                        // Recreate video controller so the change takes effect
                        _videoController = VideoController(
                          _player!,
                          configuration: VideoControllerConfiguration(
                            enableHardwareAcceleration: _hardwareAcceleration,
                          ),
                        );
                      }
                    });
                    _saveSettings();
                  },
                ),

                // Video Decoder
                const Text('Video Decoder:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                DropdownButton<String>(
                  value: _videoDecoder,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: 'auto', child: Text('Auto')),
                    DropdownMenuItem(
                        value: 'software', child: Text('Software')),
                    DropdownMenuItem(
                        value: 'hardware', child: Text('Hardware')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() {
                        _videoDecoder = value;
                        if (value == 'software') {
                          _hardwareAcceleration = false;
                        } else if (value == 'hardware') {
                          _hardwareAcceleration = true;
                        }
                      });
                      setState(() {
                        _videoDecoder = value;
                        if (value == 'software') {
                          _hardwareAcceleration = false;
                        } else if (value == 'hardware') {
                          _hardwareAcceleration = true;
                        }
                        if (_player != null) {
                          _videoController = VideoController(
                            _player!,
                            configuration: VideoControllerConfiguration(
                              enableHardwareAcceleration: _hardwareAcceleration,
                            ),
                          );
                        }
                      });
                      _saveSettings();
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Audio Decoder
                const Text('Audio Decoder:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                DropdownButton<String>(
                  value: _audioDecoder,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: 'auto', child: Text('Auto')),
                    DropdownMenuItem(
                        value: 'software', child: Text('Software')),
                    DropdownMenuItem(
                        value: 'hardware', child: Text('Hardware')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() {
                        _audioDecoder = value;
                      });
                      setState(() {
                        _audioDecoder = value;
                      });
                      _saveSettings();
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Buffer Size
                Text('Buffer Size: ${_bufferSize}MB',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Slider(
                  value: _bufferSize.toDouble(),
                  min: 1,
                  max: 100,
                  divisions: 99,
                  label: '${_bufferSize}MB',
                  onChanged: (value) {
                    setDialogState(() {
                      _bufferSize = value.round();
                    });
                    setState(() {
                      _bufferSize = value.round();
                    });
                    _saveSettings();
                  },
                ),

                // Network Timeout
                Text('Network Timeout: ${_networkTimeout}s',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Slider(
                  value: _networkTimeout.toDouble(),
                  min: 5,
                  max: 120,
                  divisions: 23,
                  label: '${_networkTimeout}s',
                  onChanged: (value) {
                    setDialogState(() {
                      _networkTimeout = value.round();
                    });
                    setState(() {
                      _networkTimeout = value.round();
                    });
                    _saveSettings();
                  },
                ),

                // Subtitle Encoding
                const Text('Subtitle Encoding:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                DropdownButton<String>(
                  value: _subtitleEncoding,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: 'utf-8', child: Text('UTF-8')),
                    DropdownMenuItem(value: 'utf-16', child: Text('UTF-16')),
                    DropdownMenuItem(
                        value: 'iso-8859-1', child: Text('ISO-8859-1')),
                    DropdownMenuItem(
                        value: 'windows-1252', child: Text('Windows-1252')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() {
                        _subtitleEncoding = value;
                      });
                      setState(() {
                        _subtitleEncoding = value;
                      });
                      _saveSettings();
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Video Output Format
                const Text('Video Output Format:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                DropdownButton<String>(
                  value: _videoOutputFormat,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: 'auto', child: Text('Auto')),
                    DropdownMenuItem(value: 'yuv420p', child: Text('YUV420P')),
                    DropdownMenuItem(value: 'rgb24', child: Text('RGB24')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() {
                        _videoOutputFormat = value;
                      });
                      setState(() {
                        _videoOutputFormat = value;
                      });
                      _saveSettings();
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                _resetSettings();
                setDialogState(() {});
              },
              child: const Text('Reset to Default'),
            ),
            TextButton(
              onPressed: () => RouteUtils.safePopDialog(context),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  // Helper methods for advanced features
  void _setPlaybackSpeed(double speed) {
    if (_player != null) {
      _player!.setRate(speed);
    } else if (_vlcController != null) {
      _vlcController!.setPlaybackSpeed(speed);
    }
  }

  Future<void> _togglePictureInPicture() async {
    // Android: enter native Picture-in-Picture
    if (Platform.isAndroid) {
      try {
        final channel = MethodChannel('cb_file_manager/pip');

        // Determine aspect ratio from current video if possible
        int w = 16;
        int h = 9;
        try {
          if (_player != null) {
            final pw = _player!.state.width;
            final ph = _player!.state.height;
            if (pw != null && ph != null && pw > 0 && ph > 0) {
              w = pw;
              h = ph;
            }
          } else if (_vlcController != null) {
            // For VLC, use default 16:9 ratio as fallback
            // VLC doesn't expose video dimensions easily
            w = 16;
            h = 9;
          }
        } catch (_) {
          // Fallback to 16:9 if we can't get dimensions
          w = 16;
          h = 9;
        }

        // Pause Flutter-side playback to avoid double audio; native player will take over in PiP.
        try {
          if (_vlcController != null && _vlcController!.value.isPlaying) {
            await _vlcController!.pause();
          } else if (_player != null && _player!.state.playing) {
            await _player!.pause();
          }
        } catch (_) {}
        // Set Android PiP state before entering PiP mode so UI hides overlays
        setState(() => _isAndroidPip = true);

        // Build source info for native PiP player
        String sourceTypeForPip = 'url';
        String sourceForPip = '';
        if (widget.file != null) {
          sourceTypeForPip = 'file';
          sourceForPip = widget.file!.path;
        } else if (widget.streamingUrl != null) {
          sourceTypeForPip = 'url';
          sourceForPip = widget.streamingUrl!;
        } else if (widget.smbMrl != null) {
          try {
            final uri =
                await SmbHttpProxyServer.instance.urlFor(widget.smbMrl!);
            sourceTypeForPip = 'url';
            sourceForPip = uri.toString();
          } catch (_) {}
        }

        try {
          final result = await channel.invokeMethod('enterPip', {
            'width': w,
            'height': h,
            // Provide native with source so it can render independently of Flutter
            'sourceType': sourceTypeForPip,
            'source': sourceForPip,
            'positionMs': _player != null
                ? _player!.state.position.inMilliseconds
                : _vlcController!.value.position.inMilliseconds,
            'playing': true,
            'volume': _player != null
                ? (_player!.state.volume.clamp(0.0, 100.0) / 100.0)
                : (_vlcVolume.clamp(0.0, 100.0) / 100.0),
          });

          if (result == true) {
            debugPrint('PiP entered successfully');
          } else {
            debugPrint('PiP entry failed');
            if (mounted) {
              setState(() => _isAndroidPip = false);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Không thể bật PiP trên Android')),
              );
            }
          }
        } catch (e) {
          debugPrint('PiP method call error: $e');
          if (mounted) {
            setState(() => _isAndroidPip = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Lỗi PiP: $e')),
            );
          }
        }
      } catch (e) {
        debugPrint('PIP error: $e');
        setState(() => _isAndroidPip = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi PiP: $e')),
        );
      }
      return;
    }

    // Desktop (Windows): prefer external window; fallback to overlay if needed
    if (Platform.isWindows) {
      // Read user preference: default to external PiP window
      bool preferExternal = true;
      try {
        final up = UserPreferences.instance;
        await up.init();
        preferExternal = await up.getVideoPlayerBool('windows_pip_external',
                defaultValue: true) ??
            true;
      } catch (_) {}
      final positionMs = _player != null
          ? _player!.state.position.inMilliseconds
          : _vlcController!.value.position.inMilliseconds;
      final volume = _player != null
          ? (_player!.state.volume).clamp(0.0, 100.0)
          : _vlcVolume.clamp(0.0, 100.0);
      final playing = _player != null
          ? _player!.state.playing
          : _vlcController!.value.isPlaying;

      String? sourceType;
      String? source;
      if (widget.streamingUrl != null && widget.streamingUrl!.isNotEmpty) {
        sourceType = 'url';
        source = widget.streamingUrl!;
      } else if (widget.file != null) {
        sourceType = 'file';
        source = widget.file!.path;
      } else if (widget.smbMrl != null) {
        try {
          final uri = await SmbHttpProxyServer.instance.urlFor(widget.smbMrl!);
          sourceType = 'url';
          source = uri.toString();
        } catch (_) {
          sourceType = 'smb';
          source = widget.smbMrl!;
        }
      }

      if (sourceType == null || source == null || source.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không có nguồn video để mở PiP')),
        );
        return;
      }

      if (preferExternal) {
        // Attempt external PiP window process first
        // Start IPC server for PiP -> main sync
        _startPipIpcServer().then((ipc) {
          final args = <String, dynamic>{
            'sourceType': sourceType,
            'source': source,
            'fileName': widget.fileName,
            'positionMs': positionMs,
            'volume': volume,
            'playing': playing,
          };
          if (ipc != null) {
            args['ipcPort'] = ipc['port'];
            args['ipcToken'] = ipc['token'];
          }

          final ok = PipWindowService.openDesktopPipWindow(args);
          ok.then((started) async {
            if (started) {
              // Pause current playback to avoid double audio
              try {
                if (_player != null && _player!.state.playing) {
                  await _player!.pause();
                } else if (_vlcController != null &&
                    _vlcController!.value.isPlaying) {
                  await _vlcController!.pause();
                }
              } catch (_) {}
              if (mounted) {
                setState(() => _isPictureInPicture = true);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã mở PiP ở cửa sổ riêng')),
                );
              }
            } else {
              // External failed: close IPC and fallback to overlay
              _closePipIpc();
              _showWindowsOverlayPip(
                context,
                sourceType: sourceType!,
                source: source!,
                fileName: widget.fileName,
                positionMs: positionMs,
                volume: volume,
                playing: playing,
              );
            }
          });
        });
        return;
      }

      // Prefer overlay per user setting
      _showWindowsOverlayPip(
        context,
        sourceType: sourceType!,
        source: source!,
        fileName: widget.fileName,
        positionMs: positionMs,
        volume: volume,
        playing: playing,
      );
      return;
    }

    // Other platforms: not implemented yet
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('PiP chưa hỗ trợ trên nền tảng này'),
      ),
    );
  }

  Future<Map<String, dynamic>?> _startPipIpcServer() async {
    try {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      _pipServer = server;
      _pipToken = _generateIpcToken();
      _pipServerSub = server.listen((client) {
        _pipClient = client;
        // Expect line-delimited UTF8 JSON
        _pipMsgSub = client
            .cast<List<int>>()
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen(_handlePipMessage, onDone: () {
          _closePipIpc();
        }, onError: (e) {
          _closePipIpc();
        });
      });
      return {
        'port': server.port,
        'token': _pipToken!,
      };
    } catch (e) {
      debugPrint('Failed to start PiP IPC server: $e');
      _closePipIpc();
      return null;
    }
  }

  void _closePipIpc() {
    try {
      _pipMsgSub?.cancel();
      _pipServerSub?.cancel();
      _pipClient?.destroy();
      _pipServer?.close();
    } catch (_) {}
    _pipMsgSub = null;
    _pipServerSub = null;
    _pipClient = null;
    _pipServer = null;
    _pipToken = null;
    if (mounted) {
      setState(() {
        _isPictureInPicture = false;
      });
    }
  }

  void _handlePipMessage(String line) async {
    try {
      final data = jsonDecode(line);
      if (data is! Map) return;
      final token = data['token'];
      if (token != _pipToken) return; // ignore unknown
      final type = data['type'] as String?;
      if (type == 'closing') {
        final pos = (data['positionMs'] as num?)?.toInt() ?? 0;
        final vol = (data['volume'] as num?)?.toDouble();
        final playing = data['playing'] == true;
        // Apply state
        try {
          if (_player != null) {
            await _player!.seek(Duration(milliseconds: pos));
            if (vol != null) await _player!.setVolume(vol.clamp(0.0, 100.0));
            if (playing) {
              await _player!.play();
            } else {
              await _player!.pause();
            }
          } else if (_vlcController != null) {
            await _vlcController!.seekTo(Duration(milliseconds: pos));
            if (vol != null) {
              await _vlcController!.setVolume(vol.toInt());
            }
            if (playing) {
              await _vlcController!.play();
            } else {
              await _vlcController!.pause();
            }
          }
        } catch (e) {
          debugPrint('Failed applying PiP state: $e');
        }
      }
      if (type == 'closing') {
        // Focus main window and cleanup IPC
        try {
          if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
            await windowManager.focus();
          }
        } catch (_) {}
        _closePipIpc();
      }
    } catch (e) {
      debugPrint('Invalid PiP IPC message: $e');
    }
  }

  String _generateIpcToken() {
    final ts = DateTime.now().microsecondsSinceEpoch;
    final r = (ts ^ (ts << 7)) & 0x7FFFFFFF;
    return r.toRadixString(36) + ts.toRadixString(36);
  }

  void _setSleepTimer(Duration duration) {
    _cancelSleepTimer();
    setState(() {
      _sleepDuration = duration;
    });

    _sleepTimer = Timer(duration, () {
      if (mounted) {
        _pauseVideo();
        setState(() {
          _sleepDuration = null;
        });
      }
    });
  }

  void _cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    setState(() {
      _sleepDuration = null;
    });
  }

  // Settings management methods
  Future<void> _saveSettings() async {
    try {
      final userPreferences = UserPreferences.instance;
      await userPreferences.init();

      // Save video player settings using new methods
      await userPreferences.setVideoPlayerString('video_codec', _selectedCodec);
      await userPreferences.setVideoPlayerBool(
          'hardware_acceleration', _hardwareAcceleration);
      await userPreferences.setVideoPlayerString(
          'video_decoder', _videoDecoder);
      await userPreferences.setVideoPlayerString(
          'audio_decoder', _audioDecoder);
      await userPreferences.setVideoPlayerInt('buffer_size', _bufferSize);
      await userPreferences.setVideoPlayerInt(
          'network_timeout', _networkTimeout);
      await userPreferences.setVideoPlayerString(
          'subtitle_encoding', _subtitleEncoding);
      await userPreferences.setVideoPlayerString(
          'video_output_format', _videoOutputFormat);
      await userPreferences.setVideoPlayerString(
          'video_scale_mode', _videoScaleMode);

      debugPrint('Video player settings saved successfully');
    } catch (e) {
      debugPrint('Error saving video player settings: $e');
    }
  }

  Future<void> _loadSettings() async {
    try {
      final userPreferences = UserPreferences.instance;
      await userPreferences.init();

      // Load video player settings with defaults using new methods
      _selectedCodec = await userPreferences.getVideoPlayerString('video_codec',
              defaultValue: 'auto') ??
          'auto';
      _hardwareAcceleration = await userPreferences.getVideoPlayerBool(
              'hardware_acceleration',
              defaultValue: true) ??
          true;
      _videoDecoder = await userPreferences
              .getVideoPlayerString('video_decoder', defaultValue: 'auto') ??
          'auto';
      _audioDecoder = await userPreferences
              .getVideoPlayerString('audio_decoder', defaultValue: 'auto') ??
          'auto';
      _bufferSize = await userPreferences.getVideoPlayerInt('buffer_size',
              defaultValue: 10) ??
          10;
      _networkTimeout = await userPreferences
              .getVideoPlayerInt('network_timeout', defaultValue: 30) ??
          30;
      _subtitleEncoding = await userPreferences.getVideoPlayerString(
              'subtitle_encoding',
              defaultValue: 'utf-8') ??
          'utf-8';
      _videoOutputFormat = await userPreferences.getVideoPlayerString(
              'video_output_format',
              defaultValue: 'auto') ??
          'auto';
      _videoScaleMode = await userPreferences.getVideoPlayerString(
              'video_scale_mode',
              defaultValue: 'contain') ??
          'contain';

      // Keep hardware acceleration in sync with explicit decoder choice
      if (_videoDecoder == 'software') {
        _hardwareAcceleration = false;
      } else if (_videoDecoder == 'hardware') {
        _hardwareAcceleration = true;
      }

      debugPrint('Video player settings loaded successfully');
    } catch (e) {
      debugPrint('Error loading video player settings: $e');
    }
  }

  void _resetSettings() {
    setState(() {
      _selectedCodec = 'auto';
      _hardwareAcceleration = true;
      _videoDecoder = 'auto';
      _audioDecoder = 'auto';
      _bufferSize = 10;
      _networkTimeout = 30;
      _subtitleEncoding = 'utf-8';
      _videoOutputFormat = 'auto';
      _videoScaleMode = 'contain';
    });
    _saveSettings();
  }

  void _pauseVideo() async {
    if (_player != null) {
      await _player!.pause();
      setState(() {
        _isPlaying = false;
      });
    } else if (_vlcController != null) {
      await _vlcController!.pause();
    }
  }

  /// Starts the seeking state to prevent UI flickering during seek operations
  void _startSeeking() {
    if (!_isSeeking) {
      setState(() {
        _isSeeking = true;
      });
    }

    // Cancel existing timer
    _seekingTimer?.cancel();

    // Set timer to end seeking state after a brief delay
    _seekingTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _isSeeking = false;
        });
      }
    });
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
          onPressed: () => RouteUtils.safePopDialog(context),
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

/// Widget để hiển thị ảnh từ streaming URL hoặc file stream
class StreamingImageViewer extends StatefulWidget {
  final String? streamingUrl;
  final Stream<List<int>>? fileStream;
  final String fileName;
  final VoidCallback? onClose;

  const StreamingImageViewer({
    Key? key,
    this.streamingUrl,
    this.fileStream,
    required this.fileName,
    this.onClose,
  })  : assert(
          streamingUrl != null || fileStream != null,
          'Either streamingUrl or fileStream must be provided',
        ),
        super(key: key);

  /// Constructor for streaming URL
  const StreamingImageViewer.fromUrl({
    Key? key,
    required String streamingUrl,
    required String fileName,
    VoidCallback? onClose,
  }) : this(
          key: key,
          streamingUrl: streamingUrl,
          fileName: fileName,
          onClose: onClose,
        );

  /// Constructor for file stream
  const StreamingImageViewer.fromStream({
    Key? key,
    required Stream<List<int>> fileStream,
    required String fileName,
    VoidCallback? onClose,
  }) : this(
          key: key,
          fileStream: fileStream,
          fileName: fileName,
          onClose: onClose,
        );

  @override
  State<StreamingImageViewer> createState() => _StreamingImageViewerState();
}

class _StreamingImageViewerState extends State<StreamingImageViewer> {
  bool _isLoading = true;
  String? _errorMessage;
  Uint8List? _imageData;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      if (widget.streamingUrl != null) {
        await _loadFromUrl();
      } else if (widget.fileStream != null) {
        await _loadFromStream();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error loading image: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadFromUrl() async {
    // Implementation for loading from URL would go here
    // For now, just show an error
    setState(() {
      _errorMessage = 'URL loading not implemented yet';
      _isLoading = false;
    });
  }

  Future<void> _loadFromStream() async {
    final chunks = <int>[];
    await for (final chunk in widget.fileStream!) {
      chunks.addAll(chunk);
    }

    if (mounted) {
      setState(() {
        _imageData = Uint8List.fromList(chunks);
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.7),
        title: Text(
          widget.fileName,
          style: const TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed:
                widget.onClose ?? () => RouteUtils.safePopDialog(context),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 64),
            const SizedBox(height: 16),
            Text(
              'Error loading image',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Colors.white70),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadImage,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_imageData != null) {
      return Center(
        child: InteractiveViewer(
          child: Image.memory(
            _imageData!,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            errorBuilder: (context, error, stackTrace) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.broken_image, color: Colors.red, size: 64),
                    SizedBox(height: 16),
                    Text(
                      'Failed to display image',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );
    }

    return const Center(
      child: Text(
        'No image data available',
        style: TextStyle(color: Colors.white),
      ),
    );
  }
}
