import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cb_file_manager/services/streaming/streaming_speed_monitor.dart';

/// Widget overlay hiển thị thông tin tốc độ stream trên video player
class StreamingSpeedOverlay extends StatefulWidget {
  final bool showSpeedInfo;
  final VoidCallback? onToggleSpeedInfo;
  final Color? backgroundColor;
  final Color? textColor;
  final Duration autoHideDuration;

  const StreamingSpeedOverlay({
    Key? key,
    this.showSpeedInfo = true,
    this.onToggleSpeedInfo,
    this.backgroundColor,
    this.textColor,
    this.autoHideDuration = const Duration(seconds: 5),
  }) : super(key: key);

  @override
  State<StreamingSpeedOverlay> createState() => _StreamingSpeedOverlayState();
}

class _StreamingSpeedOverlayState extends State<StreamingSpeedOverlay>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  StreamSubscription<StreamingSpeedInfo>? _speedSubscription;
  StreamingSpeedInfo? _currentSpeedInfo;
  Timer? _autoHideTimer;
  bool _isVisible = true;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, -1),
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeInOut,
    ));

    _startListening();
    _startAutoHideTimer();
  }

  @override
  void dispose() {
    _speedSubscription?.cancel();
    _autoHideTimer?.cancel();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  void _startListening() {
    final monitor = StreamingSpeedMonitor();
    _speedSubscription = monitor.speedStream.listen((speedInfo) {
      if (mounted) {
        setState(() {
          _currentSpeedInfo = speedInfo;
        });
        _resetAutoHideTimer();
      }
    });
  }

  void _startAutoHideTimer() {
    _autoHideTimer = Timer(widget.autoHideDuration, () {
      if (mounted) {
        _hideOverlay();
      }
    });
  }

  void _resetAutoHideTimer() {
    _autoHideTimer?.cancel();
    if (_isVisible) {
      _startAutoHideTimer();
    }
  }

  void _hideOverlay() {
    if (mounted && _isVisible) {
      setState(() {
        _isVisible = false;
      });
      _fadeController.forward();
      _slideController.forward();
    }
  }

  void _showOverlay() {
    if (mounted && !_isVisible) {
      setState(() {
        _isVisible = true;
      });
      _fadeController.reverse();
      _slideController.reverse();
      _startAutoHideTimer();
    }
  }

  void _toggleOverlay() {
    if (_isVisible) {
      _hideOverlay();
    } else {
      _showOverlay();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.showSpeedInfo) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: 16,
      right: 16,
      child: GestureDetector(
        onTap: _toggleOverlay,
        child: AnimatedBuilder(
          animation: Listenable.merge([_fadeController, _slideController]),
          builder: (context, child) {
            return SlideTransition(
              position: _slideAnimation,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: _buildSpeedInfoCard(),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSpeedInfoCard() {
    final bgColor = widget.backgroundColor ?? Colors.black.withValues(alpha: 0.8);
    final textColor = widget.textColor ?? Colors.white;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.speed,
                color: textColor,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                'Tốc độ Stream',
                style: TextStyle(
                  color: textColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: widget.onToggleSpeedInfo,
                child: Icon(
                  Icons.close,
                  color: textColor.withValues(alpha: 0.7),
                  size: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_currentSpeedInfo != null) ...[
            _buildSpeedRow('Hiện tại:',
                _currentSpeedInfo!.formattedCurrentSpeed, textColor),
            const SizedBox(height: 4),
            _buildSpeedRow('Trung bình:',
                _currentSpeedInfo!.formattedAverageSpeed, textColor),
            const SizedBox(height: 4),
            _buildSpeedRow(
                'Đã tải:', _currentSpeedInfo!.formattedTotalBytes, textColor),
            const SizedBox(height: 4),
            _buildSpeedRow('Thời gian:',
                _formatDuration(_currentSpeedInfo!.elapsedTime), textColor),
          ] else ...[
            _buildSpeedRow('Trạng thái:', 'Đang tải...', textColor),
            const SizedBox(height: 4),
            _buildSpeedRow('Tốc độ:', 'Chờ dữ liệu...', textColor),
          ],
        ],
      ),
    );
  }

  Widget _buildSpeedRow(String label, String value, Color textColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 60,
          child: Text(
            label,
            style: TextStyle(
              color: textColor.withValues(alpha: 0.8),
              fontSize: 10,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: textColor,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

/// Widget button để toggle hiển thị thông tin tốc độ
class StreamingSpeedToggleButton extends StatelessWidget {
  final bool isVisible;
  final VoidCallback onToggle;
  final Color? backgroundColor;
  final Color? iconColor;

  const StreamingSpeedToggleButton({
    Key? key,
    required this.isVisible,
    required this.onToggle,
    this.backgroundColor,
    this.iconColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bgColor = backgroundColor ?? Colors.black.withValues(alpha: 0.6);
    final iconColor = this.iconColor ?? Colors.white;

    return GestureDetector(
      onTap: onToggle,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Icon(
          isVisible ? Icons.speed : Icons.speed_outlined,
          color: iconColor,
          size: 20,
        ),
      ),
    );
  }
}
