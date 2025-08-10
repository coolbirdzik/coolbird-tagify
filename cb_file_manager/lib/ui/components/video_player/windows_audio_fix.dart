import 'package:flutter/material.dart';
import 'dart:io';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A utility class to help diagnose and fix Windows audio issues with MediaKit
class WindowsAudioFix extends StatefulWidget {
  final Function(Map<String, dynamic>)? onAudioConfigSelected;

  const WindowsAudioFix({
    Key? key,
    this.onAudioConfigSelected,
  }) : super(key: key);

  @override
  State<WindowsAudioFix> createState() => _WindowsAudioFixState();
}

class _WindowsAudioFixState extends State<WindowsAudioFix> {
  Player? _testPlayer;
  bool _isTestingAudio = false;
  String _currentOutput = 'Unknown';
  String _testStatus = 'Not started';
  int _currentIndex = 0;
  bool _hasFoundWorkingConfig = false;

  // List of audio outputs to try
  final List<String> _audioOutputs = [
    'wasapi',
    'winmm',
    'openal',
    'sdl',
    'dsound',
    'pcm'
  ];

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    // Check if we have a saved working audio config
    final prefs = await SharedPreferences.getInstance();
    final savedOutput = prefs.getString('windows_working_audio_output');

    if (savedOutput != null) {
      setState(() {
        _currentOutput = savedOutput;
        _testStatus = 'Using previously working output: $savedOutput';
        _hasFoundWorkingConfig = true;
      });

      // Notify parent with the working config
      _applyAudioConfig(savedOutput);
    }
  }

  void _applyAudioConfig(String audioOutput) {
    // Sử dụng cài đặt mặc định - không áp dụng cài đặt tùy chỉnh nào
    final audioConfig = {
      'ao': audioOutput,
    };

    if (widget.onAudioConfigSelected != null) {
      widget.onAudioConfigSelected!(audioConfig);
    }
  }

  Future<void> _testAudioOutput(String output) async {
    setState(() {
      _testStatus = 'Testing audio output: $output';
      _isTestingAudio = true;
      _currentOutput = output;
    });

    try {
      // Clean up previous test player if it exists
      _testPlayer?.dispose();

      // Create a new test player
      _testPlayer = Player();

      // Try to play a short silence for testing
      // This tests if the audio system initializes without errors
      await _testPlayer!.open(
        Media(
          'asset:///assets/sounds/test.mp3',
          extras: {
            'ao': output,
            'audio': 'yes',
            'volume': '100',
          },
        ),
      );

      // Wait a bit to see if playing works
      await Future.delayed(const Duration(milliseconds: 500));

      // If we didn't crash, consider this output working
      setState(() {
        _testStatus = 'Audio output $output seems to be working!';
        _isTestingAudio = false;
        _hasFoundWorkingConfig = true;
      });

      // Save this working output
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('windows_working_audio_output', output);

      // Notify parent with the working config
      _applyAudioConfig(output);
    } catch (e) {
      setState(() {
        _testStatus = 'Audio output $output failed: $e';
        _isTestingAudio = false;
      });

      // Try the next output if available
      _tryNextOutput();
    } finally {
      _testPlayer?.dispose();
      _testPlayer = null;
    }
  }

  void _tryNextOutput() {
    if (_currentIndex < _audioOutputs.length - 1) {
      _currentIndex++;
      _testAudioOutput(_audioOutputs[_currentIndex]);
    } else {
      setState(() {
        _testStatus = 'All audio outputs tested, none worked!';
      });
    }
  }

  @override
  void dispose() {
    _testPlayer?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Windows Audio Troubleshooter',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        Text('Current audio output: $_currentOutput',
            style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 8),
        Text(_testStatus, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 16),
        if (_hasFoundWorkingConfig)
          ElevatedButton(
            onPressed: () {
              _applyAudioConfig(_currentOutput);
              Navigator.of(context).pop();
            },
            child: const Text('Use this audio configuration'),
          )
        else
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: _isTestingAudio
                    ? null
                    : () {
                        _currentIndex = 0;
                        _testAudioOutput(_audioOutputs[_currentIndex]);
                      },
                child: const Text('Test Audio Outputs'),
              ),
              const SizedBox(width: 16),
              TextButton(
                onPressed: _isTestingAudio
                    ? null
                    : () {
                        Navigator.of(context).pop();
                      },
                child: const Text('Close'),
              ),
            ],
          ),
        if (_isTestingAudio)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 8),
                Text('Testing $_currentOutput output...'),
              ],
            ),
          ),
        const SizedBox(height: 16),
        const Text('If audio still doesn\'t work after testing:',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const Padding(
          padding: EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('1. Check Windows sound settings'),
              Text('2. Make sure no other app is using audio exclusively'),
              Text('3. Update your audio drivers'),
              Text('4. Try running the app as administrator'),
              Text('5. Restart your computer to reset audio system'),
            ],
          ),
        ),
      ],
    );
  }
}

/// A button that shows the Windows audio fix dialog
class WindowsAudioFixButton extends StatelessWidget {
  final Function(Map<String, dynamic>)? onAudioConfigSelected;

  const WindowsAudioFixButton({
    Key? key,
    this.onAudioConfigSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Only show on Windows
    if (!Platform.isWindows) {
      return const SizedBox.shrink();
    }

    return IconButton(
      icon: const Icon(Icons.audio_file),
      tooltip: 'Fix Windows Audio',
      onPressed: () {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Windows Audio Fix'),
            content: SizedBox(
              width: 450,
              child: WindowsAudioFix(
                onAudioConfigSelected: onAudioConfigSelected,
              ),
            ),
          ),
        );
      },
    );
  }
}
