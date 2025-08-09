import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile_smb_native/mobile_smb_native.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SMB Native Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'SMB Native Demo'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final _hostController = TextEditingController(text: '192.168.1.100');
  final _shareController = TextEditingController(text: 'shared');
  final _usernameController = TextEditingController(text: 'user');
  final _passwordController = TextEditingController(text: 'password');
  final _pathController = TextEditingController(text: '/');
  
  final _smbService = SmbPlatformService.instance;
  bool _isConnected = false;
  bool _isLoading = false;
  List<SmbFile> _files = [];
  String _status = 'Disconnected';
  double _downloadProgress = 0.0;
  Map<String, dynamic> _platformStatus = {};

  @override
  void initState() {
    super.initState();
    _updatePlatformStatus();
  }

  @override
  void dispose() {
    _hostController.dispose();
    _shareController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _pathController.dispose();
    super.dispose();
  }

  void _updatePlatformStatus() {
    setState(() {
      _platformStatus = _smbService.getPlatformStatus();
    });
  }

  Future<void> _connect() async {
    setState(() {
      _isLoading = true;
      _status = 'Connecting...';
    });

    try {
      final config = SmbConnectionConfig(
        host: _hostController.text,
        shareName: _shareController.text,
        username: _usernameController.text,
        password: _passwordController.text,
      );

      final connected = await _smbService.connect(config);
      setState(() {
        _isConnected = connected;
        _status = connected ? 'Connected' : 'Connection failed';
      });

      if (connected) {
        await _listDirectory();
      }
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _disconnect() async {
    setState(() {
      _isLoading = true;
      _status = 'Disconnecting...';
    });

    try {
      await _smbService.disconnect();
      setState(() {
        _isConnected = false;
        _status = 'Disconnected';
        _files.clear();
      });
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _listDirectory() async {
    if (!_isConnected) return;

    setState(() {
      _isLoading = true;
      _status = 'Loading directory...';
    });

    try {
      final files = await _smbService.listDirectory(_pathController.text);
      setState(() {
        _files = files;
        _status = 'Found ${files.length} items';
      });
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _downloadFile(SmbFile file) async {
    if (file.isDirectory) {
      // Navigate to directory
      _pathController.text = '${_pathController.text}/${file.name}'.replaceAll('//', '/');
      await _listDirectory();
      return;
    }

    setState(() {
      _downloadProgress = 0.0;
      _status = 'Downloading ${file.name}...';
    });

    try {
      final filePath = '${_pathController.text}/${file.name}'.replaceAll('//', '/');
      final stream = _smbService.streamFileWithProgress(
        filePath,
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              _downloadProgress = progress;
              _status = 'Downloading ${file.name}... ${(progress * 100).toStringAsFixed(1)}%';
            });
          }
        },
      );
      
      final chunks = <int>[];
      await for (final chunk in stream) {
        chunks.addAll(chunk.data);
        // Progress is already updated via onProgress callback
      }
      
      setState(() {
        _status = 'Download completed: ${chunks.length} bytes';
        _downloadProgress = 1.0;
      });
    } catch (e) {
      setState(() {
        _status = 'Download error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Platform Status
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Platform Status',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text('Platform: ${_platformStatus['platform'] ?? 'Unknown'}'),
                    Text('Native Available: ${_platformStatus['nativeAvailable'] ?? false}'),
                    Text('Support Level: ${_platformStatus['supportLevel'] ?? 'unknown'}'),
                    if (!(_platformStatus['nativeAvailable'] ?? false))
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          _smbService.getPlatformErrorMessage(),
                          style: TextStyle(color: Colors.orange[700]),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // Connection form
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    TextField(
                      controller: _hostController,
                      decoration: const InputDecoration(labelText: 'Host'),
                    ),
                    TextField(
                      controller: _shareController,
                      decoration: const InputDecoration(labelText: 'Share Name'),
                    ),
                    TextField(
                      controller: _usernameController,
                      decoration: const InputDecoration(labelText: 'Username'),
                    ),
                    TextField(
                      controller: _passwordController,
                      decoration: const InputDecoration(labelText: 'Password'),
                      obscureText: true,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: (_isLoading || !(_platformStatus['nativeAvailable'] ?? false)) ? null : (_isConnected ? _disconnect : _connect),
                            child: Text(_isConnected ? 'Disconnect' : 'Connect'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            // Status and path
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text('Status: $_status'),
                    if (_downloadProgress > 0 && _downloadProgress < 1)
                      LinearProgressIndicator(value: _downloadProgress),
                    const SizedBox(height: 8),
                    if (_isConnected) ...[
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _pathController,
                              decoration: const InputDecoration(labelText: 'Path'),
                            ),
                          ),
                          IconButton(
                            onPressed: (_platformStatus['nativeAvailable'] ?? false) ? _listDirectory : null,
                            icon: const Icon(Icons.refresh),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            
            // File list
            if (_isConnected)
              Expanded(
                child: Card(
                  child: ListView.builder(
                    itemCount: _files.length,
                    itemBuilder: (context, index) {
                      final file = _files[index];
                      return ListTile(
                        leading: Icon(
                          file.isDirectory ? Icons.folder : Icons.insert_drive_file,
                        ),
                        title: Text(file.name),
                        subtitle: Text(
                          file.isDirectory 
                              ? 'Directory' 
                              : '${file.size} bytes - ${file.lastModified}',
                        ),
                        onTap: (_platformStatus['nativeAvailable'] ?? false) ? () => _downloadFile(file) : null,
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}