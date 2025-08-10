import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:eva_icons_flutter/eva_icons_flutter.dart';
import 'package:flutter/foundation.dart';

import '../../../bloc/network_browsing/network_browsing_bloc.dart';
import '../../../bloc/network_browsing/network_browsing_event.dart';
import '../../../bloc/network_browsing/network_browsing_state.dart';
import '../../../services/network_browsing/smb_service.dart';
// Removed smb_connect import - using mobile_smb_native instead
import '../../../services/network_credentials_service.dart';
import '../../../models/database/network_credentials.dart';

/// Dialog for entering network connection details
class NetworkConnectionDialog extends StatefulWidget {
  /// Initial service to select in the dropdown
  final String? initialService;

  /// Initial host to fill in the host field
  final String? initialHost;

  /// Callback when connection is requested
  final Function(String connectionPath, String tabName)? onConnectionRequested;

  const NetworkConnectionDialog({
    Key? key,
    this.initialService,
    this.initialHost,
    this.onConnectionRequested,
  }) : super(key: key);

  @override
  State<NetworkConnectionDialog> createState() =>
      _NetworkConnectionDialogState();
}

class _NetworkConnectionDialogState extends State<NetworkConnectionDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _selectedService;
  final _hostController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _portController = TextEditingController();
  bool _showPassword = false;
  bool _useSSL = true;
  String? _domain;

  // For SMB share selection
  bool _connectingToServer = false;
  bool _showingShareSelector = false;
  List<String> _availableShares = [];
  String? _selectedShare;
  bool _sharesLoading = false;

  // Thêm biến để lưu thông tin đăng nhập
  bool _saveCredentials = true;

  // Lưu trữ danh sách các host đã lưu để autocomplete
  List<String> _savedHosts = [];
  // Lưu trữ các thông tin đăng nhập đã lưu để điền tự động
  List<NetworkCredentials> _savedCredentials = [];

  // Local bloc for handling connection logic
  late NetworkBrowsingBloc _localBloc;

  @override
  void initState() {
    super.initState();
    debugPrint(
        'NetworkConnectionDialog: initState() called on platform: ${Platform.operatingSystem}');
    _selectedService = widget.initialService ?? 'SMB';
    _localBloc = NetworkBrowsingBloc();

    // Set the host if provided
    if (widget.initialHost != null) {
      _hostController.text = widget.initialHost!;
      debugPrint(
          'NetworkConnectionDialog: Initial host set to: ${widget.initialHost}');
    } else {
      debugPrint('NetworkConnectionDialog: No initial host provided');
    }

    // Set default ports based on service
    _updateDefaultPort();

    // Load saved hosts immediately
    _loadSavedHosts(); // Load saved hosts for autocomplete

    // Đảm bảo host controller đã được thiết lập trước khi tải thông tin đăng nhập
    // Trên mobile, cần thêm delay dài hơn để đảm bảo giá trị đã được cập nhật
    Future.delayed(const Duration(milliseconds: 500), () {
      debugPrint(
          'NetworkConnectionDialog: Before loading credentials, host is: ${_hostController.text}');
      _loadSavedCredentials();
    });

    // Listen to connection results
    _localBloc.stream.listen((state) {
      if (state.lastSuccessfullyConnectedPath != null &&
          widget.onConnectionRequested != null) {
        final connectionPath = state.lastSuccessfullyConnectedPath!;
        final tabName = _getTabNameFromPath(connectionPath);
        widget.onConnectionRequested!(connectionPath, tabName);
        Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    _hostController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _portController.dispose();
    _localBloc.close();
    super.dispose();
  }

  String _getTabNameFromPath(String path) {
    try {
      if (path.startsWith('#network/')) {
        final parts = path.split('/');
        if (parts.length >= 4) {
          final service = parts[1].toUpperCase();
          final host = Uri.decodeComponent(parts[2]);
          if (parts.length >= 4) {
            final share = Uri.decodeComponent(parts[3]);
            return '$host/$share';
          }
          return host;
        }
      }
    } catch (e) {
      debugPrint('Error parsing path for tab name: $e');
    }
    return 'Network Connection';
  }

  // Tải thông tin đăng nhập đã lưu
  Future<void> _loadSavedCredentials() async {
    // Đợi một chút để đảm bảo UI đã hiển thị
    await Future.delayed(const Duration(milliseconds: 100));

    try {
      final hostToSearch = _hostController.text.trim();
      debugPrint(
          'NetworkConnectionDialog: Loading saved credentials for host: "$hostToSearch", service: $_selectedService, platform: ${Platform.operatingSystem}');

      if (hostToSearch.isEmpty) {
        debugPrint(
            'NetworkConnectionDialog: Host is empty, skipping credential load');
        return;
      }

      // Chuẩn hóa host giống như trong NetworkCredentialsService
      final normalizedHost = hostToSearch
          .replaceAll(RegExp(r'^[a-z]+://'), '')
          .replaceAll(RegExp(r':\d+$'), '');
      debugPrint('NetworkConnectionDialog: Normalized host: "$normalizedHost"');

      // Tìm thông tin đăng nhập đã lưu cho dịch vụ hiện tại
      final credentials = NetworkCredentialsService().findCredentials(
        serviceType: _selectedService,
        host: hostToSearch,
      );

      debugPrint(
          'NetworkConnectionDialog: Credentials search result: ${credentials != null ? "FOUND" : "NOT FOUND"}');
      if (credentials != null) {
        debugPrint(
            'NetworkConnectionDialog: Found credentials details - host: ${credentials.host}, username: ${credentials.username}, domain: ${credentials.domain}, port: ${credentials.port}');
      }

      if (credentials != null && mounted) {
        debugPrint(
            'NetworkConnectionDialog: Applying saved credentials for $hostToSearch - username: ${credentials.username}');
        setState(() {
          _hostController.text = credentials.host;
          _usernameController.text = credentials.username;
          _passwordController.text = credentials.password;

          if (credentials.port != null) {
            _portController.text = credentials.port.toString();
          }

          if (_selectedService == 'SMB' && credentials.domain != null) {
            _domain = credentials.domain;
          }
        });

        // Kiểm tra sau khi cập nhật
        debugPrint(
            'NetworkConnectionDialog: After update - Username controller: "${_usernameController.text}", Password set: ${_passwordController.text.isNotEmpty}');
      } else {
        debugPrint(
            'NetworkConnectionDialog: No saved credentials found for host: "$hostToSearch"');

        // Kiểm tra tất cả thông tin đăng nhập đã lưu để debug
        final allCredentials = NetworkCredentialsService()
            .getCredentialsByServiceType(_selectedService);
        debugPrint(
            'NetworkConnectionDialog: Found ${allCredentials.length} saved credentials for service "$_selectedService":');
        for (var cred in allCredentials) {
          debugPrint(
              '  - Host: "${cred.host}", Username: "${cred.username}", Domain: "${cred.domain}", Port: ${cred.port}');
        }
      }
    } catch (e) {
      debugPrint(
          'NetworkConnectionDialog: Error loading saved credentials: $e');
    }
  }

  // Tải danh sách host đã lưu để autocomplete
  Future<void> _loadSavedHosts() async {
    try {
      // Lấy tất cả thông tin đăng nhập cho dịch vụ hiện tại
      _savedCredentials = NetworkCredentialsService()
          .getCredentialsByServiceType(_selectedService);

      // Trích xuất danh sách các host
      Set<String> hostSet = {};
      for (var credential in _savedCredentials) {
        hostSet.add(credential.host);
      }

      if (mounted) {
        setState(() {
          _savedHosts = hostSet.toList();
          debugPrint(
              'Loaded ${_savedHosts.length} saved hosts for $_selectedService');
        });
      }
    } catch (e) {
      debugPrint('Error loading saved hosts: $e');
    }
  }

  Future<void> _deleteSavedHost(String host) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Saved Connection?'),
        content: Text(
            'Are you sure you want to delete the saved connection for "$host"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Find the credentials to get the ID
        final credsToDelete = NetworkCredentialsService().findCredentials(
          serviceType: _selectedService,
          host: host,
        );

        if (credsToDelete != null) {
          await NetworkCredentialsService().deleteCredentials(credsToDelete.id);
          // Reload hosts to update the UI
          await _loadSavedHosts();

          // Clear the form if the deleted host was the one being shown
          if (_hostController.text == host) {
            _hostController.clear();
            _usernameController.clear();
            _passwordController.clear();
            _domain = null;
            _updateDefaultPort();
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Connection for "$host" deleted.')),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content:
                      Text('Could not find connection for "$host" to delete.'),
                  backgroundColor: Colors.orange),
            );
          }
        }
      } catch (e) {
        debugPrint('Error deleting host: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting connection: $e')),
          );
        }
      }
    }
  }

  // Tự động điền thông tin đăng nhập khi chọn host
  void _autoFillCredentials(String selectedHost) {
    try {
      // Tìm thông tin đăng nhập cho host được chọn
      final matchingCredential = _savedCredentials.firstWhere(
        (cred) => cred.host == selectedHost,
        orElse: () => throw Exception('No matching credential found'),
      );

      if (mounted) {
        setState(() {
          _usernameController.text = matchingCredential.username;
          _passwordController.text = matchingCredential.password;

          if (matchingCredential.port != null) {
            _portController.text = matchingCredential.port.toString();
          } else {
            _updateDefaultPort();
          }

          if (_selectedService == 'SMB' && matchingCredential.domain != null) {
            _domain = matchingCredential.domain;
          }
        });
      }
    } catch (e) {
      debugPrint('Error auto-filling credentials: $e');
      // If no matching credential is found, just update the port
      _updateDefaultPort();
    }
  }

  void _updateDefaultPort() {
    switch (_selectedService) {
      case 'SMB':
        _portController.text = '445';
        break;
      case 'FTP':
        _portController.text = '21';
        break;
      case 'WebDAV':
        _portController.text = _useSSL ? '443' : '80';
        break;
      default:
        _portController.text = '';
    }
  }

  // Helper function to connect to SMB server and get shares
  Future<void> _connectToServerAndListShares() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _connectingToServer = true;
      _showingShareSelector = false; // Không hiện dialog chọn share
    });

    try {
      final serverAddress = _hostController.text.trim();
      final username = _usernameController.text.trim();
      final password = _passwordController.text;
      final domain = _domain ?? '';

      debugPrint(
          'NetworkConnectionDialog: Connecting to SMB server: $serverAddress, username: $username, platform: ${Platform.operatingSystem}');
      debugPrint(
          'NetworkConnectionDialog: _saveCredentials value: $_saveCredentials');

      // Kết nối trực tiếp với SMB server mà không cần chọn share
      // Tạo event kết nối với server (không cần share)
      final event = NetworkConnectionRequested(
        serviceName: _selectedService,
        host: serverAddress, // Chỉ kết nối tới server, không kèm share
        username: username,
        password: password,
        port: _portController.text.isNotEmpty
            ? int.tryParse(_portController.text)
            : null,
        additionalOptions: {
          if (_domain != null) 'domain': _domain,
        },
      );

      _localBloc.add(event);

      // Lưu thông tin đăng nhập nếu được chọn
      debugPrint(
          'NetworkConnectionDialog: Should save credentials? $_saveCredentials');
      if (_saveCredentials) {
        debugPrint(
            'NetworkConnectionDialog: Saving credentials for SMB - host: $serverAddress, username: $username');
        await NetworkCredentialsService().saveCredentials(
          serviceType: _selectedService,
          host: serverAddress,
          username: username,
          password: password,
          port: _portController.text.isNotEmpty
              ? int.tryParse(_portController.text)
              : null,
          domain: _domain,
        );
        debugPrint('NetworkConnectionDialog: Credentials saved successfully');
      } else {
        debugPrint(
            'NetworkConnectionDialog: Not saving credentials because _saveCredentials is false');
      }
    } catch (e) {
      debugPrint('Error connecting to server: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connection failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _connectingToServer = false;
        });
      }
    }
  }

  // Helper to convert technical errors to readable messages
  String _getReadableConnectionError(dynamic error, String server) {
    final errorStr = error.toString().toLowerCase();

    if (errorStr.contains('timed out') || errorStr.contains('timeout')) {
      return 'Connection timed out. Server "$server" is not responding.';
    } else if (errorStr.contains('authentication') ||
        errorStr.contains('login') ||
        errorStr.contains('password') ||
        errorStr.contains('access denied')) {
      return 'Authentication failed. Please check your username and password.';
    } else if (errorStr.contains('host not found') ||
        errorStr.contains('unknown host') ||
        errorStr.contains('no such host')) {
      return 'Cannot find server "$server". Check the server address and your network connection.';
    } else if (errorStr.contains('permission') || errorStr.contains('denied')) {
      return 'Permission denied. You may not have access to this server.';
    } else if (errorStr.contains('network') ||
        errorStr.contains('connection')) {
      return 'Network error. Check your connection and that the SMB server is running.';
    } else {
      return 'Connection failed: $error';
    }
  }

  // Handle the final connection with selected share
  void _connectWithSelectedShare() {
    if (_selectedShare == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a share'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Extract share name from path (typically /shareName)
    final sharePath = _selectedShare!;
    final shareName =
        sharePath.startsWith('/') ? sharePath.substring(1) : sharePath;

    // Construct host/share format
    final serverAddress = _hostController.text.trim();
    final fullAddress = '$serverAddress/$shareName';

    debugPrint('Connecting to: $fullAddress');

    // Clear any existing connection path
    _localBloc.add(const NetworkClearLastConnectedPath());

    // Create connection request event
    final event = NetworkConnectionRequested(
      serviceName: _selectedService,
      host: fullAddress, // Now using server/share format
      username: _usernameController.text.trim(),
      password: _passwordController.text,
      port: _portController.text.isNotEmpty
          ? int.tryParse(_portController.text)
          : null,
      additionalOptions: {
        if (_domain != null) 'domain': _domain,
      },
    );

    // Show loading indicator
    setState(() {
      _connectingToServer = true;
    });

    // Send the connection request through BLoC
    _localBloc.add(event);
  }

  void _onServiceTypeChanged(String? value) {
    if (value == null) return;

    setState(() {
      _selectedService = value;
      _updateDefaultPort();
    });

    // Clear fields when switching service type
    _passwordController.clear();

    // Load saved credentials for the selected service
    _loadSavedCredentials();

    // Also reload saved hosts for autocomplete
    _loadSavedHosts();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _localBloc,
      child: BlocBuilder<NetworkBrowsingBloc, NetworkBrowsingState>(
        bloc: _localBloc,
        builder: (context, state) {
          final isLoading = state.isLoading || _connectingToServer;

          // Không còn cần dialog chọn share nữa vì shares sẽ hiển thị như thư mục
          return AlertDialog(
            title: Text('Connect to $_selectedService Server'),
            content: SizedBox(
              width: 400,
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Service Selection Dropdown
                      DropdownButtonFormField<String>(
                        value: _selectedService,
                        decoration: const InputDecoration(
                          labelText: 'Service Type',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'SMB', child: Text('SMB')),
                          DropdownMenuItem(value: 'FTP', child: Text('FTP')),
                          DropdownMenuItem(
                              value: 'WebDAV', child: Text('WebDAV')),
                        ],
                        onChanged: isLoading
                            ? null
                            : (value) {
                                setState(() {
                                  _selectedService = value!;
                                  _updateDefaultPort();
                                  _loadSavedHosts();
                                });
                              },
                      ),

                      const SizedBox(height: 16),

                      // Host Field with Autocomplete
                      Autocomplete<String>(
                        fieldViewBuilder:
                            (context, controller, focusNode, onFieldSubmitted) {
                          // Sync the controller with our _hostController
                          if (controller.text != _hostController.text) {
                            controller.text = _hostController.text;
                          }
                          _hostController.addListener(() {
                            if (controller.text != _hostController.text) {
                              controller.text = _hostController.text;
                            }
                          });

                          return TextFormField(
                            controller: controller,
                            focusNode: focusNode,
                            enabled: !isLoading,
                            decoration: const InputDecoration(
                              labelText: 'Host',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (value) {
                              _hostController.text = value;
                              _loadSavedCredentials();
                            },
                            onFieldSubmitted: (value) {
                              onFieldSubmitted();
                            },
                          );
                        },
                        optionsBuilder: (TextEditingValue textEditingValue) {
                          if (textEditingValue.text.isEmpty) {
                            return _savedHosts;
                          }
                          return _savedHosts.where((option) => option
                              .toLowerCase()
                              .contains(textEditingValue.text.toLowerCase()));
                        },
                        onSelected: (String option) {
                          _hostController.text = option;
                          _loadSavedCredentials();
                        },
                        optionsViewBuilder: (context, onSelected, options) {
                          return Material(
                            elevation: 4.0,
                            child: ListView.builder(
                              padding: EdgeInsets.zero,
                              itemCount: options.length,
                              shrinkWrap: true,
                              itemBuilder: (BuildContext context, int index) {
                                final option = options.elementAt(index);
                                return ListTile(
                                  title: Text(option),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon:
                                            const Icon(EvaIcons.edit, size: 16),
                                        onPressed: () {
                                          // Stop dropdown from closing
                                          Navigator.of(context).pop();
                                          _deleteSavedHost(option);
                                        },
                                        tooltip: 'Delete Saved Connection',
                                      ),
                                    ],
                                  ),
                                  onTap: () {
                                    onSelected(option);
                                  },
                                );
                              },
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 16),

                      // Username Field
                      TextFormField(
                        controller: _usernameController,
                        enabled: !isLoading,
                        decoration: const InputDecoration(
                          labelText: 'Username',
                          border: OutlineInputBorder(),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Password Field
                      TextFormField(
                        controller: _passwordController,
                        enabled: !isLoading,
                        obscureText: !_showPassword,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _showPassword ? EvaIcons.eye : EvaIcons.eyeOff,
                            ),
                            onPressed: isLoading
                                ? null
                                : () {
                                    setState(() {
                                      _showPassword = !_showPassword;
                                    });
                                  },
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Port Field
                      TextFormField(
                        controller: _portController,
                        enabled: !isLoading,
                        decoration: const InputDecoration(
                          labelText: 'Port (optional)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),

                      // Show additional options based on selected service
                      if (_selectedService == 'WebDAV') ...[
                        const SizedBox(height: 16),

                        // SSL Checkbox
                        CheckboxListTile(
                          title: const Text('Use SSL/TLS'),
                          value: _useSSL,
                          onChanged: isLoading
                              ? null
                              : (value) {
                                  setState(() {
                                    _useSSL = value ?? true;
                                    if (_portController.text == '443' ||
                                        _portController.text == '80') {
                                      _portController.text =
                                          _useSSL ? '443' : '80';
                                    }
                                  });
                                },
                        ),
                      ],

                      if (_selectedService == 'SMB') ...[
                        const SizedBox(height: 16),

                        // Domain Field
                        TextFormField(
                          enabled: !isLoading,
                          decoration: const InputDecoration(
                            labelText: 'Domain (optional)',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (value) {
                            _domain = value.isEmpty ? null : value;
                          },
                        ),
                      ],

                      const SizedBox(height: 16),

                      // Save Credentials Checkbox
                      CheckboxListTile(
                        title: const Text('Save credentials'),
                        subtitle: const Text(
                            'Store login details for future connections'),
                        value: _saveCredentials,
                        onChanged: isLoading
                            ? null
                            : (value) {
                                setState(() {
                                  _saveCredentials = value ?? true;
                                });
                              },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isLoading ? null : () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isLoading
                    ? null
                    : _selectedService == 'SMB'
                        ? _connectToServerAndListShares
                        : () {
                            if (_formKey.currentState!.validate()) {
                              _localBloc
                                  .add(const NetworkClearLastConnectedPath());

                              final host = _hostController.text.trim();
                              final username = _usernameController.text.trim();
                              final password = _passwordController.text;
                              final port = _portController.text.isNotEmpty
                                  ? int.tryParse(_portController.text)
                                  : null;

                              final event = NetworkConnectionRequested(
                                serviceName: _selectedService,
                                host: host,
                                username: username,
                                password: password,
                                port: port,
                                additionalOptions: {
                                  if (_selectedService == 'WebDAV')
                                    'useSSL': _useSSL,
                                  if (_selectedService == 'SMB' &&
                                      _domain != null)
                                    'domain': _domain,
                                },
                              );
                              _localBloc.add(event);

                              // Lưu thông tin đăng nhập nếu được chọn
                              if (_saveCredentials) {
                                NetworkCredentialsService().saveCredentials(
                                  serviceType: _selectedService,
                                  host: host,
                                  username: username,
                                  password: password,
                                  port: port,
                                  domain: _domain,
                                  additionalOptions: {
                                    if (_selectedService == 'WebDAV')
                                      'useSSL': _useSSL,
                                  },
                                );
                              }
                            }
                          },
                child: isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(_selectedService == 'SMB' ? 'Connect' : 'Connect'),
              ),
            ],
          );
        },
      ),
    );
  }
}
