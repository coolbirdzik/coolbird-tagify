import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;

import 'package:flutter_vlc_player/flutter_vlc_player.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'dart:typed_data';
import 'dart:async';
import '../../../helpers/file_type_helper.dart';
import '../../components/stream_speed_indicator.dart';
import '../../components/buffer_info_widget.dart';
import '../../components/video_player/common_controls_overlay.dart';

/// Widget để phát media từ streaming URL hoặc file stream
class StreamingMediaPlayer extends StatefulWidget {
  final String? streamingUrl;
  final String? smbMrl; // SMB MRL for direct streaming
  final Stream<List<int>>? fileStream;
  final String fileName;
  final FileType fileType;
  final VoidCallback? onClose;

  const StreamingMediaPlayer({
    Key? key,
    this.streamingUrl,
    this.smbMrl,
    this.fileStream,
    required this.fileName,
    required this.fileType,
    this.onClose,
  })  : assert(
          streamingUrl != null || smbMrl != null || fileStream != null,
          'Either streamingUrl, smbMrl or fileStream must be provided',
        ),
        super(key: key);

  /// Constructor for streaming URL
  const StreamingMediaPlayer.fromUrl({
    Key? key,
    required String streamingUrl,
    required String fileName,
    required FileType fileType,
    VoidCallback? onClose,
  }) : this(
          key: key,
          streamingUrl: streamingUrl,
          fileName: fileName,
          fileType: fileType,
          onClose: onClose,
        );

  /// Constructor for file stream
  const StreamingMediaPlayer.fromStream({
    Key? key,
    required Stream<List<int>> fileStream,
    required String fileName,
    required FileType fileType,
    VoidCallback? onClose,
  }) : this(
          key: key,
          fileStream: fileStream,
          fileName: fileName,
          fileType: fileType,
          onClose: onClose,
        );

  /// Constructor for SMB MRL
  const StreamingMediaPlayer.fromSmbMrl({
    Key? key,
    required String smbMrl,
    required String fileName,
    required FileType fileType,
    VoidCallback? onClose,
  }) : this(
          key: key,
          smbMrl: smbMrl,
          fileName: fileName,
          fileType: fileType,
          onClose: onClose,
        );

  @override
  State<StreamingMediaPlayer> createState() => _StreamingMediaPlayerState();
}

class _StreamingMediaPlayerState extends State<StreamingMediaPlayer> {
  Player? _player;
  VideoController? _videoController;
  bool _isLoading = true;
  String? _errorMessage;
  bool _showSpeedIndicator = false;
  Stream<List<int>>? _currentStream;
  StreamController<List<int>>? _streamController;
  int _totalBytesBuffered = 0;
  int _chunkCountBuffered = 0;
  bool _useFlutterVlc = false;
  VlcPlayerController? _vlcController;
  // VLC state (single definition)
  bool _vlcListenerAttached = false;
  bool _vlcPlaying = false;
  Duration _vlcPosition = Duration.zero;
  Duration _vlcDuration = Duration.zero;
  double _vlcVolume = 70.0;
  bool _vlcMuted = false;
  bool _isFullScreen = false;
  bool _showControls = true;
  Timer? _hideControlsTimer;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _isFullScreen) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  void _showControlsWithTimer() {
    if (!mounted) return;
    setState(() {
      _showControls = true;
    });
    _startHideControlsTimer();
  }

  Future<void> _toggleFullScreen() async {
    setState(() {
      _isFullScreen = !_isFullScreen;
    });
    if (_isFullScreen) {
      _showControlsWithTimer();
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  Widget _buildVlcControlsOverlay() {
    final pos = _vlcPosition;
    final dur = _vlcDuration.inMilliseconds > 0
        ? _vlcDuration
        : const Duration(seconds: 1);
    final progress = dur.inMilliseconds > 0
        ? (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    String fmt(Duration d) {
      String two(int n) => n.toString().padLeft(2, '0');
      return '${two(d.inHours)}:${two(d.inMinutes.remainder(60))}:${two(d.inSeconds.remainder(60))}';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withOpacity(0.8),
            Colors.black.withOpacity(0.3),
            Colors.transparent,
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(fmt(pos),
                  style: const TextStyle(color: Colors.white, fontSize: 12)),
              Expanded(
                child: Slider(
                  value: progress,
                  onChanged: (v) async {
                    final targetMs = (dur.inMilliseconds * v).toInt();
                    await _vlcController
                        ?.seekTo(Duration(milliseconds: targetMs));
                  },
                  activeColor: Colors.redAccent,
                  inactiveColor: Colors.white30,
                ),
              ),
              Text(fmt(_vlcDuration),
                  style: const TextStyle(color: Colors.white, fontSize: 12)),
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: Icon(_vlcPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white, size: 30),
                onPressed: () async {
                  if (_vlcPlaying) {
                    await _vlcController?.pause();
                  } else {
                    await _vlcController?.play();
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _initializePlayer() async {
    try {
      // If on Android and an SMB MRL is provided, prefer flutter_vlc_player (direct LibVLC)
      if (!kIsWeb && Platform.isAndroid && widget.smbMrl != null) {
        _useFlutterVlc = true;
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Chỉ khởi tạo player nếu chưa tồn tại
      if (_player == null) {
        // Configure player with options for better SMB streaming
        _player = Player(
          configuration: PlayerConfiguration(
            // Increase buffer size for better streaming performance
            bufferSize: 10 * 1024 * 1024, // 10MB buffer
            // Add SMB-specific options to player configuration
            // Note: media_kit may not support all these options directly
          ),
        );
        _videoController = VideoController(_player!);

        // Lắng nghe trạng thái player
        _player!.stream.buffering.listen((buffering) {
          if (mounted) {
            setState(() {
              _isLoading = buffering;
            });
          }
        });

        _player!.stream.error.listen((error) {
          debugPrint('StreamingMediaPlayer: Player error received: $error');
          if (mounted) {
            setState(() {
              _errorMessage = 'Player error: $error';
              _isLoading = false;
            });
          }
        });
      }

      // Mở media từ streaming URL, SMB MRL hoặc file stream
      if (widget.streamingUrl != null) {
        await _player!.open(Media(widget.streamingUrl!));
      } else if (widget.smbMrl != null) {
        // Streaming trực tiếp từ SMB MRL như VLC
        debugPrint(
            'StreamingMediaPlayer: Opening SMB MRL directly: ${widget.smbMrl}');

        // Test SMB URL format
        _testSmbUrlFormat(widget.smbMrl!);

        // Create Media with options to allow unsafe playlists for SMB
        // Try different approaches for media_kit options
        final media = Media(
          widget.smbMrl!,
          // Try passing options as httpHeaders for SMB
          httpHeaders: {
            'User-Agent': 'VLC/3.0.0 LibVLC/3.0.0',
          },
          // Also try extras with different format
          extras: {
            'load-unsafe-playlists': '',
            'network-caching': '3000',
            'file-caching': '3000',
          },
        );

        try {
          await _player!.open(media);
          debugPrint('StreamingMediaPlayer: SMB MRL opened successfully');
        } catch (e) {
          debugPrint('StreamingMediaPlayer: Direct SMB failed: $e');
          debugPrint('StreamingMediaPlayer: Falling back to HTTP proxy...');

          // Fallback to HTTP proxy if direct SMB fails
          await _openWithHttpProxy();
        }
      } else if (widget.fileStream != null) {
        // Tạo broadcast stream để có thể listen nhiều lần
        _streamController = StreamController<List<int>>.broadcast();
        _currentStream = _streamController!.stream;

        debugPrint('StreamingMediaPlayer: Starting to buffer stream...');

        // Tạo temporary file từ stream với improved buffering
        final tempFile =
            await _createTempFileFromStreamImproved(widget.fileStream!);

        debugPrint(
            'StreamingMediaPlayer: Stream buffering completed, opening media player...');
        await _player!.open(Media(tempFile.path));

        debugPrint('StreamingMediaPlayer: Media player opened successfully');
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('StreamingMediaPlayer: Exception during initialization: $e');
      debugPrint('StreamingMediaPlayer: Stack trace: ${StackTrace.current}');
      if (mounted) {
        setState(() {
          _errorMessage = 'Error initializing player: $e';
          _isLoading = false;
        });
      }
    }
  }

  // Deprecated simple stream-to-file helper (unused)

  Future<File> _createTempFileFromStreamImproved(
      Stream<List<int>> stream) async {
    final tempDir = Directory.systemTemp;
    final tempFile = File(
      '${tempDir.path}/temp_media_${DateTime.now().millisecondsSinceEpoch}',
    );

    final sink = tempFile.openWrite();
    int totalBytes = 0;
    int chunkCount = 0;
    Timer? updateTimer;

    try {
      // Start periodic UI updates instead of calling setState for every chunk
      updateTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
        if (mounted) {
          setState(() {
            _totalBytesBuffered = totalBytes;
            _chunkCountBuffered = chunkCount;
          });
        }
      });

      // Add timeout protection
      bool hasReceivedData = false;

      await for (final chunk in stream) {
        hasReceivedData = true;
        // track last data time if needed

        if (chunk.isEmpty) {
          debugPrint(
              'StreamingMediaPlayer: WARNING - Received empty chunk at position $chunkCount');
          continue;
        }

        sink.add(chunk);
        totalBytes += chunk.length;
        chunkCount++;

        // Broadcast chunk to UI widgets
        _streamController!.add(chunk);

        // Log progress for debugging
        if (chunkCount % 10 == 0) {
          debugPrint(
              'StreamingMediaPlayer: Buffered ${chunkCount} chunks, ${(totalBytes / 1024 / 1024).toStringAsFixed(2)} MB');
        }

        // Ensure data is flushed to disk periodically
        if (chunkCount % 50 == 0) {
          await sink.flush();
          debugPrint(
              'StreamingMediaPlayer: Flushed to disk at chunk $chunkCount');
        }
      }

      await sink.close();
      updateTimer?.cancel();

      // Final UI update
      if (mounted) {
        setState(() {
          _totalBytesBuffered = totalBytes;
          _chunkCountBuffered = chunkCount;
        });
      }

      debugPrint(
          'StreamingMediaPlayer: Successfully buffered ${chunkCount} chunks, ${(totalBytes / 1024 / 1024).toStringAsFixed(2)} MB total');

      if (!hasReceivedData) {
        debugPrint(
            'StreamingMediaPlayer: WARNING - No data received from stream!');
      }

      // Verify file size
      final fileSize = await tempFile.length();
      debugPrint(
          'StreamingMediaPlayer: Final file size: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB');

      if (fileSize != totalBytes) {
        debugPrint(
            'StreamingMediaPlayer: WARNING - File size mismatch! Expected: $totalBytes, Actual: $fileSize');
      }

      return tempFile;
    } catch (e) {
      await sink.close();
      updateTimer?.cancel();
      debugPrint('StreamingMediaPlayer: Error buffering stream: $e');
      debugPrint(
          'StreamingMediaPlayer: Error occurred at chunk $chunkCount, total bytes: $totalBytes');
      rethrow;
    }
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
  void dispose() {
    try {
      _vlcController?.dispose();
    } catch (_) {}
    _hideControlsTimer?.cancel();
    _player?.dispose();
    _streamController?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.7),
        title: Text(
          widget.fileName,
          style: const TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // Speed indicator toggle
          if (widget.fileStream != null)
            IconButton(
              icon: Icon(
                _showSpeedIndicator ? Icons.speed : Icons.speed_outlined,
                color: Colors.white,
              ),
              onPressed: () {
                setState(() {
                  _showSpeedIndicator = !_showSpeedIndicator;
                });
              },
              tooltip: 'Toggle Speed Indicator',
            ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: widget.onClose ?? () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: _buildPlayerBody(),
    );
  }

  Widget _buildPlayerBody() {
    if (_errorMessage != null) {
      return _buildErrorWidget();
    }

    if (_isLoading) {
      return _buildLoadingWidget();
    }

    return _buildPlayer();
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 64),
          const SizedBox(height: 16),
          Text(
            'Error playing media',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _errorMessage = null;
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
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            widget.fileName,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayer() {
    if (widget.fileType == FileType.video) {
      return _buildVideoPlayer();
    } else {
      return _buildAudioPlayer();
    }
  }

  Widget _buildVideoPlayer() {
    if (_useFlutterVlc && widget.smbMrl != null) {
      // Render flutter_vlc_player directly for smb:// playback on Android
      final original = widget.smbMrl!;
      final uri = Uri.parse(original);
      final creds =
          uri.userInfo.isNotEmpty ? uri.userInfo.split(':') : const <String>[];
      final user = creds.isNotEmpty ? Uri.decodeComponent(creds[0]) : null;
      final pwd = creds.length > 1 ? Uri.decodeComponent(creds[1]) : null;
      // Strip credentials from URL to avoid '@' interfering with host parsing
      final cleanUrl = uri.replace(userInfo: '').toString();

      _vlcController ??= VlcPlayerController.network(
        cleanUrl,
        hwAcc: HwAcc.full,
        autoPlay: true,
        options: VlcPlayerOptions(
          advanced: VlcAdvancedOptions([
            '--network-caching=2000',
          ]),
          extras: [
            if (user != null) '--smb-user=$user',
            if (pwd != null) '--smb-pwd=$pwd',
          ],
        ),
      );
      if (!_vlcListenerAttached) {
        _vlcListenerAttached = true;
        _vlcController!.addListener(() {
          final v = _vlcController!.value;
          if (!mounted) return;
          setState(() {
            _vlcPlaying = v.isPlaying;
            _vlcPosition = v.position ?? Duration.zero;
            _vlcDuration = v.duration ?? Duration.zero;
          });
        });
      }

      return Stack(
        children: [
          GestureDetector(
            onTap: () {
              if (_isFullScreen) _showControlsWithTimer();
            },
            onDoubleTap: _toggleFullScreen,
            child: Center(
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: VlcPlayer(
                  controller: _vlcController!,
                  aspectRatio: 16 / 9,
                  placeholder: const Center(child: CircularProgressIndicator()),
                ),
              ),
            ),
          ),
          if (!_isFullScreen || _showControls)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: CommonVideoControlsOverlay(
                position: _vlcPosition,
                duration: _vlcDuration,
                isPlaying: _vlcPlaying,
                onPlayPause: () async {
                  if (_vlcPlaying) {
                    await _vlcController?.pause();
                  } else {
                    await _vlcController?.play();
                  }
                },
                onSeek: (v) async {
                  final targetMs = (_vlcDuration.inMilliseconds * v).toInt();
                  await _vlcController
                      ?.seekTo(Duration(milliseconds: targetMs));
                },
                hasPrev: false,
                hasNext: false,
                onPrev: null,
                onNext: null,
                volume: _vlcVolume,
                onVolumeChange: (val) async {
                  setState(() {
                    _vlcVolume = val;
                    _vlcMuted = val <= 0.1;
                  });
                  await _vlcController?.setVolume(val.toInt());
                },
                onToggleFullscreen: _toggleFullScreen,
                onScreenshot: null,
              ),
            ),
        ],
      );
    }

    return Stack(
      children: [
        Center(
          child: AspectRatio(
            aspectRatio: 16 / 9, // Default aspect ratio
            child: Video(
              controller: _videoController!,
              controls: AdaptiveVideoControls,
            ),
          ),
        ),
        // Speed indicator overlay
        if (_showSpeedIndicator && _currentStream != null)
          Positioned(
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
                // Debug info
                Container(
                  width: 200,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.black.withOpacity(0.9),
                        Colors.black.withOpacity(0.7),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.orange.withOpacity(0.5),
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
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                        ),
                      ),
                      Text(
                        'Chunks: $_chunkCountBuffered',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                        ),
                      ),
                      Text(
                        'Stream Active: ${_streamController != null ? "Yes" : "No"}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                        ),
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

  Widget _buildAudioPlayer() {
    return Stack(
      children: [
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Audio visualization placeholder
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
                style: Theme.of(
                  context,
                ).textTheme.headlineSmall?.copyWith(color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              // Audio controls
              _buildAudioControls(),
            ],
          ),
        ),
        // Speed indicator overlay for audio
        if (_showSpeedIndicator && _currentStream != null)
          Positioned(
            top: 16,
            right: 16,
            child: Column(
              children: [
                StreamSpeedIndicator(
                  stream: _currentStream,
                  label: 'Audio Stream',
                ),
                const SizedBox(height: 12),
                BufferInfoWidget(
                  stream: _currentStream,
                  label: 'Buffer Info',
                ),
                const SizedBox(height: 12),
                // Debug info for audio
                Container(
                  width: 200,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.black.withOpacity(0.9),
                        Colors.black.withOpacity(0.7),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.orange.withOpacity(0.5),
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
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                        ),
                      ),
                      Text(
                        'Chunks: $_chunkCountBuffered',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                        ),
                      ),
                      Text(
                        'Stream Active: ${_streamController != null ? "Yes" : "No"}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                        ),
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
              icon: const Icon(
                Icons.skip_previous,
                color: Colors.white,
                size: 32,
              ),
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

  /// Test SMB URL format for media_kit compatibility
  void _testSmbUrlFormat(String url) {
    debugPrint('=== StreamingMediaPlayer SMB URL Test ===');
    debugPrint('URL: $url');

    // Check if URL starts with smb://
    if (!url.startsWith('smb://')) {
      debugPrint('❌ ERROR: URL does not start with smb://');
      return;
    }

    // Parse URL components
    try {
      final uri = Uri.parse(url);
      debugPrint('✅ URL parsing successful');
      debugPrint('Scheme: ${uri.scheme}');
      debugPrint('Host: ${uri.host}');
      debugPrint('Port: ${uri.port}');
      debugPrint('Path: ${uri.path}');
      debugPrint('User info: ${uri.userInfo}');

      // Check for special characters in path
      final path = uri.path;
      if (path.contains('%')) {
        debugPrint('⚠️ WARNING: URL contains encoded characters');
        debugPrint('Decoded path: ${Uri.decodeComponent(path)}');
      }

      // Check for credentials
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

    debugPrint('=== End StreamingMediaPlayer SMB URL Test ===');
  }

  /// Fallback method to open SMB via HTTP proxy
  Future<void> _openWithHttpProxy() async {
    try {
      debugPrint('StreamingMediaPlayer: Opening SMB via HTTP proxy...');

      // For now, just show an error message
      // In a real implementation, you would start an HTTP proxy server
      // and stream the SMB content through it

      if (mounted) {
        setState(() {
          _errorMessage =
              'Direct SMB streaming failed. HTTP proxy fallback not implemented yet.';
          _isLoading = false;
        });
      }

      debugPrint('StreamingMediaPlayer: HTTP proxy fallback not implemented');
    } catch (e) {
      debugPrint('StreamingMediaPlayer: HTTP proxy error: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'HTTP proxy error: $e';
          _isLoading = false;
        });
      }
    }
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
  Uint8List? _imageData;
  bool _isLoading = true;
  String? _errorMessage;
  List<int> chunks =
      <int>[]; // Đưa chunks ra ngoài phạm vi hàm để có thể truy cập từ build

  @override
  void initState() {
    super.initState();
    if (widget.streamingUrl != null) {
      debugPrint(
        'StreamingImageViewer: Loading image from ${widget.streamingUrl}',
      );
      _isLoading = false;
    } else {
      debugPrint('StreamingImageViewer: Loading image from stream');
      _loadImageFromStream(widget.fileStream!);
    }
  }

  void _loadImageFromStream(Stream<List<int>> stream) async {
    try {
      debugPrint('StreamingImageViewer: Loading image from stream');
      chunks.clear(); // Xóa dữ liệu cũ nếu có
      bool hasSetImage = false;

      // Đặt timeout để tránh treo vô hạn - tăng lên 120 giây (2 phút)
      final timeout = Timer(const Duration(seconds: 120), () {
        if (mounted && _isLoading) {
          debugPrint(
            'StreamingImageViewer: Stream loading timeout after 120 seconds',
          );
          setState(() {
            if (chunks.isNotEmpty) {
              _imageData = Uint8List.fromList(chunks);
              _isLoading = false;
              debugPrint(
                'StreamingImageViewer: Displaying partial image after timeout (${chunks.length} bytes)',
              );
            } else {
              _errorMessage =
                  'Hết thời gian chờ (120 giây) khi tải ảnh. Vui lòng thử lại hoặc tải file về máy để xem.';
              _isLoading = false;
            }
          });
        }
      });

      // Hiển thị tiến trình tải ảnh ngay cả khi chưa có đủ dữ liệu

      // Hiển thị tiến trình tải ảnh ngay cả khi chưa có đủ dữ liệu

      try {
        await for (final chunk in stream) {
          setState(() {
            chunks.addAll(chunk);
          });
          debugPrint(
            'StreamingImageViewer: Received chunk of ${chunk.length} bytes, total: ${chunks.length}',
          );

          // Hiển thị ảnh ngay khi có đủ dữ liệu (tăng lên 256KB để phù hợp với chunk size lớn hơn)
          if (!hasSetImage && chunks.length > 256 * 1024) {
            hasSetImage = true;
            if (mounted) {
              setState(() {
                _imageData = Uint8List.fromList(chunks);
                _isLoading = false;
              });
              debugPrint(
                'StreamingImageViewer: Displaying initial image (${chunks.length} bytes)',
              );
            }
          }

          // Cập nhật ảnh thường xuyên hơn (sau mỗi 512KB dữ liệu mới)
          if (hasSetImage &&
              chunks.length % (512 * 1024) < chunk.length &&
              mounted) {
            setState(() {
              _imageData = Uint8List.fromList(chunks);
            });
            debugPrint(
              'StreamingImageViewer: Updated image with more data (${chunks.length} bytes)',
            );
          }

          // Thêm cập nhật theo thời gian để đảm bảo UI luôn được cập nhật
          if (hasSetImage && mounted && chunks.isNotEmpty) {
            // Cập nhật UI mỗi 5 chunks để tránh quá nhiều rebuild với chunk size lớn hơn
            if (chunks.length % 5 == 0 ||
                chunks.length > (_imageData?.length ?? 0) + 256000) {
              setState(() {
                _imageData = Uint8List.fromList(chunks);
              });
              debugPrint(
                'StreamingImageViewer: Periodic update with more data (${chunks.length} bytes)',
              );
            }
          }
        }

        // Khi stream hoàn thành, hiển thị ảnh cuối cùng
        if (mounted) {
          setState(() {
            _imageData = Uint8List.fromList(chunks);
            _isLoading = false;
          });
          debugPrint(
            'StreamingImageViewer: Stream completed, displaying final image (${chunks.length} bytes)',
          );
        }
      } finally {
        timeout.cancel();
      }
    } catch (e) {
      debugPrint('StreamingImageViewer: Error loading image from stream: $e');
      if (mounted) {
        setState(() {
          // Nếu đã có dữ liệu ảnh, hiển thị ảnh đó dù không hoàn chỉnh
          if (chunks.isNotEmpty && _imageData == null) {
            _imageData = Uint8List.fromList(chunks);
            _errorMessage = 'Ảnh có thể không hoàn chỉnh. Lỗi: $e';
          } else {
            _errorMessage = 'Lỗi khi tải ảnh: $e';
          }
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.7),
        title: Text(
          widget.fileName,
          style: const TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_isLoading && chunks.isNotEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  '${(chunks.length / 1024).toStringAsFixed(0)} KB',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _isLoading = true;
                _errorMessage = null;
                _imageData = null;
              });
              if (widget.fileStream != null) {
                _loadImageFromStream(widget.fileStream!);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: widget.onClose ?? () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: Colors.white),
                  const SizedBox(height: 16),
                  Text(
                    'Đang tải: ${(chunks.length / 1024).toStringAsFixed(0)} KB',
                    style: const TextStyle(color: Colors.white),
                  ),
                  if (chunks.isNotEmpty && chunks.length > 20 * 1024)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Container(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.8,
                          maxHeight: MediaQuery.of(context).size.height * 0.5,
                        ),
                        child: Image.memory(
                          Uint8List.fromList(chunks),
                          fit: BoxFit.contain,
                          frameBuilder:
                              (context, child, frame, wasSynchronouslyLoaded) {
                            return Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Colors.white30,
                                  width: 1,
                                ),
                              ),
                              child: child,
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            debugPrint(
                              'StreamingImageViewer: Error displaying partial image: $error',
                            );
                            return const Text(
                              'Đang tải ảnh...',
                              style: TextStyle(color: Colors.white70),
                            );
                          },
                        ),
                      ),
                    ),
                ],
              ),
            )
          : _errorMessage != null
              ? _buildErrorWidget('Error loading image', _errorMessage!)
              : Center(child: InteractiveViewer(child: _buildImage())),
    );
  }

  Widget _buildImage() {
    if (_imageData != null) {
      // Hiển thị ảnh từ stream data
      return Image.memory(
        _imageData!,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          debugPrint(
            'StreamingImageViewer: Error displaying image from memory: $error',
          );
          return _buildErrorWidget(
            'Error displaying image from stream',
            error.toString(),
          );
        },
      );
    } else if (widget.streamingUrl != null) {
      // Hiển thị ảnh từ URL
      return Image.network(
        widget.streamingUrl!,
        fit: BoxFit.contain,
        headers: {
          'User-Agent': 'CoolBird File Manager',
          'Accept': 'image/*,*/*;q=0.8',
          'Cache-Control': 'no-cache',
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) {
            debugPrint('StreamingImageViewer: Image loaded successfully');
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _isLoading = false;
                  _errorMessage = null;
                });
              }
            });
            return child;
          }

          final progress = loadingProgress.expectedTotalBytes != null
              ? loadingProgress.cumulativeBytesLoaded /
                  loadingProgress.expectedTotalBytes!
              : null;

          debugPrint(
            'StreamingImageViewer: Loading progress: ${(progress ?? 0) * 100}%',
          );

          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(value: progress, color: Colors.white),
                const SizedBox(height: 16),
                const Text(
                  'Loading image...',
                  style: TextStyle(color: Colors.white),
                ),
                if (progress != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${(progress * 100).toStringAsFixed(1)}%',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
                const SizedBox(height: 16),
                Text(
                  'URL: ${widget.streamingUrl}',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          debugPrint('StreamingImageViewer: Error loading image: $error');
          debugPrint('StreamingImageViewer: Stack trace: $stackTrace');

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _isLoading = false;
                _errorMessage = error.toString();
              });
            }
          });

          return _buildErrorWidget('Error loading image', error.toString());
        },
      );
    } else {
      // Fallback nếu không có URL hoặc data
      return _buildErrorWidget(
        'No image source',
        'Neither URL nor stream data available',
      );
    }
  }

  Widget _buildErrorWidget(String title, String errorMessage) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 64),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 16),
            if (widget.streamingUrl != null) ...[
              Text(
                'URL: ${widget.streamingUrl}',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
            ],
            Text(
              'Error: $errorMessage',
              style: const TextStyle(color: Colors.red, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            if (chunks.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text(
                  'Đã tải ${(chunks.length / 1024).toStringAsFixed(0)} KB',
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            if (chunks.isNotEmpty && chunks.length > 20 * 1024)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.7,
                    maxHeight: MediaQuery.of(context).size.height * 0.4,
                  ),
                  child: Image.memory(
                    Uint8List.fromList(chunks),
                    fit: BoxFit.contain,
                    frameBuilder:
                        (context, child, frame, wasSynchronouslyLoaded) {
                      return Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.red.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: child,
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return const Text(
                        'Không thể hiển thị ảnh đã tải',
                        style: TextStyle(color: Colors.white70),
                      );
                    },
                  ),
                ),
              ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _errorMessage = null;
                  _imageData = null;
                });
                if (widget.fileStream != null) {
                  _loadImageFromStream(widget.fileStream!);
                }
              },
              label: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
  }
}
