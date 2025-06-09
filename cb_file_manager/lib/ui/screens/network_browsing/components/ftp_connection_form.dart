import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cb_file_manager/services/network_browsing/ftp_client/ftp_client.dart';
import 'package:cb_file_manager/bloc/network_browsing/network_browsing_bloc.dart';
import 'package:cb_file_manager/bloc/network_browsing/network_browsing_event.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class FtpConnectionForm extends StatefulWidget {
  const FtpConnectionForm({Key? key}) : super(key: key);

  @override
  _FtpConnectionFormState createState() => _FtpConnectionFormState();
}

class _FtpConnectionFormState extends State<FtpConnectionForm> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _hostController = TextEditingController();
  final TextEditingController _portController =
      TextEditingController(text: '21');
  final TextEditingController _usernameController =
      TextEditingController(text: 'anonymous');
  final TextEditingController _passwordController =
      TextEditingController(text: 'anonymous@');

  bool _isLoading = false;
  bool _usePassiveMode = true; // Default to passive mode
  String? _connectionError;

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _connectionError = null;
    });

    final host = _hostController.text;
    final port = int.tryParse(_portController.text) ?? 21;
    final username = _usernameController.text;
    final password = _passwordController.text;

    try {
      final ftpClient = FtpClient(
        host: host,
        port: port,
        username: username,
        password: password,
      );

      await ftpClient.connect();

      // Set passive mode based on selection
      await ftpClient.setPassiveMode(_usePassiveMode);

      // Try to list directory to verify connection works
      try {
        final files = await ftpClient.listDirectory();
        debugPrint(
            'FTP: Successfully listed ${files.length} files/directories');
      } catch (e) {
        debugPrint('FTP: Error listing directory: $e');
        // If listing fails, try toggling passive mode
        await ftpClient.togglePassiveMode();

        // Try listing again
        try {
          final files = await ftpClient.listDirectory();
          debugPrint(
              'FTP: Successfully listed ${files.length} files/directories after toggling passive mode');
          // Update passive mode to match what worked
          setState(() {
            _usePassiveMode = !_usePassiveMode;
          });
        } catch (e2) {
          debugPrint('FTP: Error listing directory after toggling mode: $e2');
          // Continue anyway, we'll show the error in the UI if needed
        }
      }

      // Continue with successful connection
      if (context.mounted) {
        context.read<NetworkBrowsingBloc>().add(
              NetworkConnectionRequested(
                serviceName: 'FTP',
                host: host,
                username: username,
                password: password,
                port: port,
                additionalOptions: {
                  'usePassiveMode': _usePassiveMode,
                },
              ),
            );
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() {
        _connectionError = 'Connection failed: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _hostController,
            decoration: const InputDecoration(
              labelText: 'Host',
              hintText: 'ftp.example.com',
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a host';
              }
              return null;
            },
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _portController,
            decoration: const InputDecoration(
              labelText: 'Port',
              hintText: '21',
            ),
            keyboardType: TextInputType.number,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a port';
              }
              final port = int.tryParse(value);
              if (port == null || port <= 0 || port > 65535) {
                return 'Please enter a valid port number';
              }
              return null;
            },
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _usernameController,
            decoration: const InputDecoration(
              labelText: 'Username',
              hintText: 'anonymous',
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _passwordController,
            decoration: const InputDecoration(
              labelText: 'Password',
              hintText: 'anonymous@',
            ),
            obscureText: true,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('Connection Mode:'),
              const SizedBox(width: 8),
              Expanded(
                child: SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: true,
                      label: Text('Passive'),
                      icon: Icon(Icons.security),
                    ),
                    ButtonSegment(
                      value: false,
                      label: Text('Active'),
                      icon: Icon(Icons.settings_ethernet),
                    ),
                  ],
                  selected: {_usePassiveMode},
                  onSelectionChanged: (Set<bool> selection) {
                    setState(() {
                      _usePassiveMode = selection.first;
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_connectionError != null)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _connectionError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed:
                    _isLoading ? null : () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _isLoading ? null : _connect,
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Connect'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
