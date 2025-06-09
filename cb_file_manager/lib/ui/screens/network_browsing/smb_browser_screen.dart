import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:eva_icons_flutter/eva_icons_flutter.dart';
import 'package:path/path.dart'
    as path_utils; // Aliased to avoid conflict with 'path' in _openSavedConnection
import 'package:url_launcher/url_launcher.dart';

import '../../../bloc/network_browsing/network_browsing_bloc.dart';
import '../../../bloc/network_browsing/network_browsing_event.dart';
import '../../../bloc/network_browsing/network_browsing_state.dart';
import '../../../services/network_browsing/network_discovery_service.dart';
import '../../../services/network_browsing/network_service_registry.dart'; // Added import for registry
import '../../tab_manager/tab_manager.dart';
import '../../utils/fluent_background.dart';
import '../system_screen.dart';
import 'network_connection_dialog.dart';

/// Screen to browse SMB servers in the local network
class SMBBrowserScreen extends StatefulWidget {
  /// The tab ID this screen belongs to
  final String tabId;

  const SMBBrowserScreen({
    Key? key,
    required this.tabId,
  }) : super(key: key);

  @override
  State<SMBBrowserScreen> createState() => _SMBBrowserScreenState();
}

class _SMBBrowserScreenState extends State<SMBBrowserScreen> {
  final NetworkDiscoveryService _discoveryService = NetworkDiscoveryService();
  final NetworkServiceRegistry _registry =
      NetworkServiceRegistry(); // Added registry instance
  final List<NetworkDevice> _discoveredDevices = [];
  bool _isScanning = false;
  bool _showScanPermissionWarning = false;

  // Thêm bloc local để không phụ thuộc vào context
  late NetworkBrowsingBloc _networkBloc;
  bool _isLocalBloc = false;

  @override
  void initState() {
    super.initState();

    // Thử lấy bloc từ context hoặc tạo mới nếu không tìm thấy
    try {
      _networkBloc =
          BlocProvider.of<NetworkBrowsingBloc>(context, listen: false);
      _isLocalBloc = false;
    } catch (e) {
      debugPrint(
          'NetworkBrowsingBloc không tìm thấy trong context, tạo mới: $e');
      _networkBloc = NetworkBrowsingBloc();
      _isLocalBloc = true;
    }

    _checkNetworkDiscovery();
  }

  @override
  void dispose() {
    // Đảm bảo đóng bloc nếu là local
    if (_isLocalBloc) {
      _networkBloc.close();
    }

    // Ensure we stop any ongoing network scan
    _discoveryService.cancelScan();
    super.dispose();
  }

  Future<void> _checkNetworkDiscovery() async {
    // Mặc định hiển thị cảnh báo trên Windows vì thường phải bật Network Discovery
    if (Platform.isWindows) {
      setState(() {
        _showScanPermissionWarning = true;
      });
    }

    // Bắt đầu quét mạng
    _startNetworkScan();
  }

  Future<void> _startNetworkScan() async {
    if (_isScanning) return;

    setState(() {
      _isScanning = true;
    });

    try {
      final devices = await _discoveryService.scanNetwork();
      if (mounted) {
        setState(() {
          _discoveredDevices.clear();
          _discoveredDevices.addAll(devices);
          _isScanning = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Network scan failed: $e')),
        );
      }
    }
  }

  Future<void> _openWindowsNetworkSettings() async {
    // Mở cài đặt Network Discovery trên Windows
    if (Platform.isWindows) {
      try {
        bool opened = false;

        // Phương pháp 1: Sử dụng url_launcher để mở URI ms-settings
        try {
          final Uri settingsUri = Uri.parse('ms-settings:network');
          if (await canLaunchUrl(settingsUri)) {
            await launchUrl(settingsUri);
            opened = true;
            debugPrint('Successfully opened ms-settings:network');
          }
        } catch (e) {
          debugPrint('Failed to launch ms-settings:network: $e');
        }

        if (!opened) {
          // Phương pháp 2: Mở Internet Settings Control Panel
          try {
            await Process.run(
                'rundll32.exe', ['shell32.dll,Control_RunDLL', 'ncpa.cpl']);
            opened = true;
            debugPrint('Successfully opened network connections');
          } catch (e) {
            debugPrint('Failed to open ncpa.cpl: $e');
          }
        }

        if (!opened) {
          // Phương pháp 3: Thử shell execute với explorer
          try {
            await Process.run('explorer.exe', [
              'shell:::{26EE0668-A00A-44D7-9371-BEB064C98683}\\0\\::{7007ACC7-3202-11D1-AAD2-00805FC1270E}'
            ]);
            opened = true;
            debugPrint('Successfully opened network shell');
          } catch (e) {
            debugPrint('Failed to open shell: $e');
          }
        }

        if (!opened) {
          // Phương pháp 4: Thử mở với cmd
          try {
            await Process.run(
                'cmd.exe', ['/c', 'start', 'control', 'ncpa.cpl']);
            opened = true;
            debugPrint('Successfully opened ncpa.cpl through cmd');
          } catch (e) {
            debugPrint('Failed to open through cmd: $e');
          }
        }

        // Thông báo cho người dùng
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(opened
                ? 'Đã mở cài đặt mạng'
                : 'Không thể mở cài đặt mạng, vui lòng mở thủ công'),
            duration: const Duration(seconds: 2),
          ),
        );
      } catch (e) {
        debugPrint('Error opening network settings: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể mở cài đặt mạng: $e')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Cài đặt mạng chỉ có thể mở trên Windows')),
      );
    }
  }

  void _connectToSMBServer(String ipAddress, String name) {
    showDialog<String?>(
      context: context,
      builder: (dialogContext) => BlocProvider.value(
        value: _networkBloc, // Use the bloc instance from SMBBrowserScreen
        child: NetworkConnectionDialog(
          initialService: 'SMB',
          initialHost: ipAddress,
        ),
      ),
    ).then((connectionPath) {
      // connectionPath should now be the #network/... path from NetworkConnectionDialog
      if (connectionPath != null && connectionPath.startsWith('#network/')) {
        final tabBloc = BlocProvider.of<TabManagerBloc>(context, listen: false);

        // Use a more descriptive name for the tab, e.g., from the connection path or the discovered name
        String tabName = name; // Default to discovered name
        try {
          // Try to extract a better name from the path, e.g. host/share
          final pathParts = connectionPath.split('/');
          if (pathParts.length >= 4) {
            // Format is #network/smb/host/Sshare/...
            final host = Uri.decodeComponent(pathParts[2]);
            final share = pathParts[3].startsWith('S')
                ? Uri.decodeComponent(pathParts[3].substring(1))
                : pathParts[3];
            tabName = '$host/$share';
          }
        } catch (_) {
          // Keep default name if parsing fails
        }

        debugPrint('Opening SMB connection in tab with path: $connectionPath');

        // Create a new tab with the connection path
        tabBloc.add(AddTab(
          path: connectionPath, // This is the #network/... path
          name: tabName,
          switchToTab: true,
        ));
      } else {
        // Handle cases where connectionPath is null (dialog cancelled) or not the expected format
        if (connectionPath != null) {
          debugPrint(
              'SMBBrowserScreen: Received unexpected connection path: $connectionPath');
        }
      }
    });
  }

  void _openSavedConnection(String nativeServicePath) {
    // nativeServicePath is like smb://host/share
    final String? tabPath =
        _registry.getTabPathForNativeServiceBasePath(nativeServicePath);

    if (tabPath != null) {
      final tabBloc = BlocProvider.of<TabManagerBloc>(context, listen: false);
      // Derive a user-friendly name for the tab from the native path
      String tabName = 'SMB Share';
      try {
        Uri parsedNativePath = Uri.parse(nativeServicePath);
        String host = parsedNativePath.host;
        String sharePath = parsedNativePath.path.startsWith('/')
            ? parsedNativePath.path.substring(1)
            : parsedNativePath.path;
        tabName = sharePath.isNotEmpty ? '$host/$sharePath' : host;
      } catch (_) {
        // use default name if parsing fails
      }

      debugPrint('Opening saved SMB connection in tab with path: $tabPath');

      // Create a new tab for the existing connection
      tabBloc.add(AddTab(
        path: tabPath, // Use the transformed #network/... path
        name: tabName,
        switchToTab: true,
      ));
    } else {
      debugPrint(
          'SMBBrowserScreen: Could not get tab path for native service path: $nativeServicePath');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Could not open connection: $nativeServicePath')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SystemScreen(
      title: 'SMB Network',
      systemId: '#smb',
      icon: EvaIcons.monitor,
      showAppBar: true,
      actions: [
        // Nút làm mới
        IconButton(
          icon: _isScanning
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Icon(EvaIcons.refresh),
          onPressed: _isScanning ? null : _startNetworkScan,
          tooltip: 'Refresh',
        ),
        // Nút kết nối mới
        IconButton(
          icon: const Icon(EvaIcons.plus),
          onPressed: () {
            // Hiển thị dialog kết nối mới
            showDialog(
              context: context,
              builder: (dialogContext) => BlocProvider.value(
                value: _networkBloc,
                child: const NetworkConnectionDialog(initialService: 'SMB'),
              ),
            );
          },
          tooltip: 'Add Connection',
        ),
      ],
      child: BlocProvider.value(
        value: _networkBloc,
        child: BlocBuilder<NetworkBrowsingBloc, NetworkBrowsingState>(
          bloc: _networkBloc,
          builder: (context, state) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Hiển thị cảnh báo bật Network Discovery nếu cần
                if (_showScanPermissionWarning)
                  FluentBackground(
                    blurAmount: 8.0,
                    opacity: 0.7,
                    backgroundColor:
                        Theme.of(context).colorScheme.surface.withOpacity(0.5),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        children: [
                          const Icon(EvaIcons.alertCircleOutline,
                              color: Colors.orange),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'Network discovery may not be enabled',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  'Enable network discovery in Windows settings to scan for SMB servers',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          OutlinedButton(
                            onPressed: _openWindowsNetworkSettings,
                            child: const Text('Open Settings'),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Connections Section
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Active Connections',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        'SMB servers you are connected to',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),

                // Active connections list
                _buildActiveConnections(state.connections),

                const Divider(height: 32),

                // Discovered Devices Section
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Discovered SMB Servers',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            Text(
                              'Servers discovered on your local network',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      if (_isScanning)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                ),

                // Discovered devices list
                _buildDiscoveredDevices(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildActiveConnections(Map<String, dynamic>? connections) {
    // Filter only SMB connections
    final smbConnections = connections?.entries
            .where((entry) => entry.key.startsWith('smb://'))
            .toList() ??
        [];

    if (smbConnections.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.0),
        child: Text('No active SMB connections'),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: smbConnections.length,
      itemBuilder: (context, index) {
        final entry = smbConnections[index];
        final path = entry.key;

        // Extract server name from path
        final serverName = path.replaceFirst('smb://', '').split('/').first;

        return ListTile(
          leading: const Icon(EvaIcons.monitor, color: Colors.blue),
          title: Text(serverName),
          subtitle: Text(path),
          trailing: IconButton(
            icon: const Icon(EvaIcons.closeCircle, color: Colors.red),
            onPressed: () {
              // Disconnect from this server
              _networkBloc.add(NetworkDisconnectRequested(path));
            },
            tooltip: 'Disconnect',
          ),
          onTap: () => _openSavedConnection(path),
        );
      },
    );
  }

  Widget _buildDiscoveredDevices() {
    if (_discoveredDevices.isEmpty) {
      if (_isScanning) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Text('Scanning for SMB servers...'),
          ),
        );
      }

      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(EvaIcons.wifiOff, size: 48, color: Colors.grey),
              const SizedBox(height: 16),
              const Text('No SMB servers found'),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _startNetworkScan,
                child: const Text('Scan Again'),
              ),
            ],
          ),
        ),
      );
    }

    return Expanded(
      child: ListView.builder(
        itemCount: _discoveredDevices.length,
        itemBuilder: (context, index) {
          final device = _discoveredDevices[index];

          return ListTile(
            leading: const Icon(EvaIcons.monitor, color: Colors.blue),
            title: Text(device.name),
            subtitle: Text(device.ipAddress),
            trailing: const Icon(EvaIcons.arrowForward),
            onTap: () => _connectToSMBServer(device.ipAddress, device.name),
          );
        },
      ),
    );
  }
}
