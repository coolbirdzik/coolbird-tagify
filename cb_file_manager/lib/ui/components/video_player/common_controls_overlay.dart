import 'package:flutter/material.dart';

class CommonVideoControlsOverlay extends StatelessWidget {
  final Duration position;
  final Duration duration;
  final bool isPlaying;
  final VoidCallback onPlayPause;
  final ValueChanged<double> onSeek; // 0.0..1.0
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final bool hasPrev;
  final bool hasNext;
  final double? volume; // 0..100 (optional)
  final ValueChanged<double>? onVolumeChange; // 0..100 (optional)
  final VoidCallback? onToggleFullscreen;
  final VoidCallback? onScreenshot;

  const CommonVideoControlsOverlay({
    Key? key,
    required this.position,
    required this.duration,
    required this.isPlaying,
    required this.onPlayPause,
    required this.onSeek,
    this.onPrev,
    this.onNext,
    this.hasPrev = false,
    this.hasNext = false,
    this.volume,
    this.onVolumeChange,
    this.onToggleFullscreen,
    this.onScreenshot,
  }) : super(key: key);

  String _fmt(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inHours)}:${two(d.inMinutes.remainder(60))}:${two(d.inSeconds.remainder(60))}';
  }

  @override
  Widget build(BuildContext context) {
    final safeDuration =
        duration.inMilliseconds > 0 ? duration : const Duration(seconds: 1);
    final progress =
        (position.inMilliseconds / safeDuration.inMilliseconds).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withValues(alpha: 0.85),
                Colors.black.withValues(alpha: 0.5),
            Colors.transparent,
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(_fmt(position),
                  style: const TextStyle(color: Colors.white, fontSize: 12)),
              Expanded(
                child: Slider(
                  value: progress,
                  onChanged: onSeek,
                  activeColor: Colors.redAccent,
                  inactiveColor: Colors.white30,
                ),
              ),
              Text(_fmt(duration),
                  style: const TextStyle(color: Colors.white, fontSize: 12)),
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: Icon(hasPrev ? Icons.skip_previous : Icons.skip_previous,
                    color: hasPrev ? Colors.white : Colors.white24, size: 26),
                onPressed: hasPrev ? onPrev : null,
              ),
              IconButton(
                icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white, size: 32),
                onPressed: onPlayPause,
              ),
              IconButton(
                icon: Icon(hasNext ? Icons.skip_next : Icons.skip_next,
                    color: hasNext ? Colors.white : Colors.white24, size: 26),
                onPressed: hasNext ? onNext : null,
              ),
              const Spacer(),
              if (onScreenshot != null)
                IconButton(
                  icon: const Icon(Icons.photo_camera,
                      color: Colors.white, size: 22),
                  onPressed: onScreenshot,
                ),
              if (onVolumeChange != null)
                Row(
                  children: [
                    const Icon(Icons.volume_up, color: Colors.white, size: 18),
                    SizedBox(
                      width: 100,
                      child: Slider(
                        value: (volume ?? 70).clamp(0, 100),
                        min: 0,
                        max: 100,
                        onChanged: onVolumeChange,
                        activeColor: Colors.white,
                        inactiveColor: Colors.white30,
                      ),
                    ),
                  ],
                ),
              if (onToggleFullscreen != null)
                IconButton(
                  icon: const Icon(Icons.fullscreen,
                      color: Colors.white, size: 22),
                  onPressed: onToggleFullscreen,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
