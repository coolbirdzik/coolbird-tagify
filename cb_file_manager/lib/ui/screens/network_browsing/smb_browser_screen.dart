import 'dart:io';
import 'dart:async';
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
import '../../../services/network_browsing/mobile_smb_service.dart'; // Added import for mobile SMB service
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

class _SMBBrowserScreenState extends State<SMBBrowserScreen>
    with AutomaticKeepAliveClientMixin {
  final NetworkDiscoveryService _discoveryService = NetworkDiscoveryService();
  final NetworkServiceRegistry _registry =
      NetworkServiceRegistry(); // Added registry instance

  // Sử dụng static cache để giữ state khi widget bị dispose
  static final List<NetworkDevice> _cachedDiscoveredDevices = [];
  static bool _cachedHasScanned = false;
  static bool _cachedIsScanning = false;

  final List<NetworkDevice> _discoveredDevices = [];
  bool _isScanning = false;
  bool _hasScanned = false; // Thêm flag để track đã scan chưa
  bool _showScanPermissionWarning = false;
  StreamSubscription<NetworkDevice>? _deviceStreamSubscription;

  // Thêm bloc local để không phụ thuộc vào context
  late NetworkBrowsingBloc _networkBloc;
  bool _isLocalBloc = false;

  // SMB version tracking
  String _smbVersion = 'Unknown';
  String _connectionInfo = 'Not connected';
  bool _isLoadingVersion = false;

  // AutomaticKeepAliveClientMixin implementation
  @override
  bool get wantKeepAlive => true;

  // Method để sync state với cache
  void _syncStateWithCache() {
    _isScanning = _cachedIsScanning;
    _hasScanned = _cachedHasScanned;
    _discoveredDevices.clear();
    _discoveredDevices.addAll(_cachedDiscoveredDevices);
  }

  // Method để update cache từ current state
  void _updateCacheFromState() {
    _cachedIsScanning = _isScanning;
    _cachedHasScanned = _hasScanned;
    _cachedDiscoveredDevices.clear();
    _cachedDiscoveredDevices.addAll(_discoveredDevices);
  }

  @override
  void initState() {
    super.initState();

    // Restore cached state
    _syncStateWithCache();

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

    // Thêm listener để refresh UI khi có connection mới
    _networkBloc.stream.listen((state) {
      if (mounted) {
        setState(() {
          // Force rebuild để cập nhật active connections
        });
        // Update SMB version info when connections change
        _updateSmbVersionInfo();
      }
    });

    // Update SMB version info on init
    _updateSmbVersionInfo();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Sync state với cache khi dependencies thay đổi
    _syncStateWithCache();
  }

  @override
  void dispose() {
    // Đảm bảo đóng bloc nếu là local
    if (_isLocalBloc) {
      _networkBloc.close();
    }

    // Ensure we stop any ongoing network scan
    _discoveryService.cancelScan();
    _deviceStreamSubscription?.cancel();
    super.dispose();
  }

  // Method để clear cache khi cần thiết
  static void clearCache() {
    _cachedDiscoveredDevices.clear();
    _cachedHasScanned = false;
    _cachedIsScanning = false;
  }

  Future<void> _checkNetworkDiscovery() async {
    // Mặc định hiển thị cảnh báo trên Windows vì thường phải bật Network Discovery
    if (Platform.isWindows) {
      setState(() {
        _showScanPermissionWarning = true;
      });
    }

    // Chỉ scan nếu chưa scan bao giờ
    if (!_hasScanned) {
      _startNetworkScan();
    }
  }

  Future<void> _startNetworkScan() async {
    if (_isScanning) return;

    setState(() {
      _isScanning = true;
      // Chỉ clear devices nếu đây là lần scan đầu tiên hoặc manual refresh
      if (!_hasScanned) {
        _discoveredDevices.clear();
        _cachedDiscoveredDevices.clear();
      }
      _updateCacheFromState();
    });

    // Subscribe to device stream for real-time updates
    _deviceStreamSubscription?.cancel();
    _deviceStreamSubscription = _discoveryService.deviceStream.listen((device) {
      if (mounted) {
        setState(() {
          // Add device if not already in list
          if (!_discoveredDevices.any((d) => d.ipAddress == device.ipAddress)) {
            _discoveredDevices.add(device);
            _cachedDiscoveredDevices.add(device);
          }
        });
      }
    });

    try {
      // Start the scan - devices will be added to the list via stream
      await _discoveryService.scanNetwork();

      if (mounted) {
        setState(() {
          _isScanning = false;
          _hasScanned = true; // Đánh dấu đã scan
          _updateCacheFromState();
        });

        // Start SMB version detection for discovered devices
        _detectSmbVersionsForDevices();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isScanning = false;
          _updateCacheFromState();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Network scan failed: $e')),
        );
      }
    } finally {
      _deviceStreamSubscription?.cancel();
    }
  }

  // Method để reset scan state và scan lại từ đầu
  Future<void> _resetAndScan() async {
    setState(() {
      _hasScanned = false;
      _discoveredDevices.clear();
      _cachedDiscoveredDevices.clear();
      _updateCacheFromState();
    });
    await _startNetworkScan();
  }

  /// Get SMB version and connection info for display
  Future<void> _updateSmbVersionInfo() async {
    if (_isLoadingVersion) return;

    setState(() {
      _isLoadingVersion = true;
    });

    try {
      // Get SMB service from registry
      final smbService = _registry.getServiceByName('SMB');
      if (smbService != null && smbService is MobileSMBService) {
        // Try to get SMB version from mobile service
        final version = await smbService.getSmbVersion();
        final info = await smbService.getConnectionInfo();

        if (mounted) {
          setState(() {
            _smbVersion = version;
            _connectionInfo = info;
          });
        }
      }
    } catch (e) {
      debugPrint('Failed to get SMB version info: $e');
      if (mounted) {
        setState(() {
          _smbVersion = 'Unknown';
          _connectionInfo = 'Connection info unavailable';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingVersion = false;
        });
      }
    }
  }

  /// Detect SMB versions for discovered devices
  Future<void> _detectSmbVersionsForDevices() async {
    if (_discoveredDevices.isEmpty) return;

    try {
      for (final device in _discoveredDevices) {
        // Try to detect SMB version for each device
        // This is a placeholder implementation
        // In a real implementation, you would attempt to connect to each device
        // and determine its SMB version
        debugPrint('Detecting SMB version for device: ${device.name}');
      }
    } catch (e) {
      debugPrint('Error detecting SMB versions: $e');
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
    }
  }

  void _connectToSMBServer(String ipAddress, String deviceName) {
    // Lấy TabManagerBloc từ context trước khi mở dialog
    final tabBloc = BlocProvider.of<TabManagerBloc>(context, listen: false);

    showDialog<String?>(
      context: context,
      builder: (context) => NetworkConnectionDialog(
        initialService: 'SMB',
        initialHost: ipAddress,
        onConnectionRequested: (connectionPath, tabName) {
          if (connectionPath != null &&
              connectionPath.startsWith('#network/')) {
            debugPrint(
                'Opening SMB connection in tab with path: $connectionPath');

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
        },
      ),
    );
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
      tabBloc.add(AddTab(
        path: tabPath,
        name: tabName,
        switchToTab: true,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Call super.build to ensure keepAlive is managed
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
          onPressed: _isScanning ? null : _resetAndScan,
          tooltip: 'Refresh',
        ),
        // Nút kết nối mới
        IconButton(
          icon: const Icon(EvaIcons.plus),
          onPressed: () {
            // Lấy TabManagerBloc từ context trước khi mở dialog
            final tabBloc =
                BlocProvider.of<TabManagerBloc>(context, listen: false);

            // Hiển thị dialog kết nối mới
            showDialog<String?>(
              context: context,
              builder: (dialogContext) => NetworkConnectionDialog(
                initialService: 'SMB',
                onConnectionRequested: (connectionPath, tabName) {
                  if (connectionPath != null &&
                      connectionPath.startsWith('#network/')) {
                    debugPrint(
                        'Opening new SMB connection in tab with path: $connectionPath');
                    tabBloc.add(AddTab(
                      path: connectionPath,
                      name: tabName,
                      switchToTab: true,
                    ));
                  }
                },
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
                      const SizedBox(height: 8),
                      // SMB Version Info
                      Container(
                        padding: const EdgeInsets.all(12.0),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceVariant
                              .withOpacity(0.3),
                          borderRadius: BorderRadius.circular(8.0),
                          border: Border.all(
                            color: Theme.of(context)
                                .colorScheme
                                .outline
                                .withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              EvaIcons.infoOutline,
                              size: 16,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'SMB Version: $_smbVersion',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w500,
                                        ),
                                  ),
                                  if (_connectionInfo != 'Not connected')
                                    Text(
                                      _connectionInfo,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),
                            if (_isLoadingVersion)
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            else
                              IconButton(
                                icon: const Icon(EvaIcons.refreshOutline,
                                    size: 16),
                                onPressed: _updateSmbVersionInfo,
                                tooltip: 'Refresh SMB version info',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                          ],
                        ),
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
    // Lấy active connections trực tiếp từ registry thay vì từ state
    final activeConnections = _registry.activeConnections;

    // Debug: Log connections để kiểm tra
    debugPrint(
        'SMBBrowserScreen: Active connections from registry: ${activeConnections.keys}');

    // Filter only SMB connections
    final smbConnections = activeConnections.entries
        .where((entry) => entry.key.startsWith('smb://'))
        .toList();

    debugPrint(
        'SMBBrowserScreen: SMB connections found: ${smbConnections.length}');

    if (smbConnections.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Row(
            children: [
              Icon(EvaIcons.info, color: Colors.grey[600], size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'No active SMB connections',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
                      ),
                    ),
                    Text(
                      'Connect to an SMB server to see it here',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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
        final sharePath = path.replaceFirst('smb://$serverName/', '');

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(EvaIcons.monitor, color: Colors.blue, size: 20),
            ),
            title: Text(
              serverName,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sharePath.isNotEmpty ? 'Share: $sharePath' : 'Root share',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Connected',
                    style: TextStyle(fontSize: 10, color: Colors.green),
                  ),
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(EvaIcons.arrowForward, color: Colors.blue),
                  onPressed: () => _openSavedConnection(path),
                  tooltip: 'Open Connection',
                ),
                IconButton(
                  icon: const Icon(EvaIcons.closeCircle, color: Colors.red),
                  onPressed: () {
                    // Disconnect from this server
                    _networkBloc.add(NetworkDisconnectRequested(path));
                  },
                  tooltip: 'Disconnect',
                ),
              ],
            ),
            onTap: () => _openSavedConnection(path),
          ),
        );
      },
    );
  }

  Widget _buildDiscoveredDevices() {
    if (_discoveredDevices.isEmpty) {
      if (_isScanning) {
        return Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Scanning for SMB servers...',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Devices will appear here as they are discovered',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'This may take a few moments',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        );
      }

      // Nếu đã scan nhưng không tìm thấy gì
      if (_hasScanned) {
        return Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(EvaIcons.wifiOff, size: 48, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('No SMB servers found'),
                  const SizedBox(height: 8),
                  const Text(
                    'Try scanning again or check your network settings',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _resetAndScan,
                    icon: const Icon(EvaIcons.refresh, size: 16),
                    label: const Text('Scan Again'),
                  ),
                ],
              ),
            ),
          ),
        );
      }

      // Nếu chưa scan bao giờ
      return Expanded(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(EvaIcons.search, size: 48, color: Colors.grey),
                const SizedBox(height: 16),
                const Text('Ready to scan'),
                const SizedBox(height: 8),
                const Text(
                  'Click the refresh button to start scanning for SMB servers',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _resetAndScan,
                  icon: const Icon(EvaIcons.refresh, size: 16),
                  label: const Text('Start Scan'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Expanded(
      child: Column(
        children: [
          // Header with device count and scan status
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                Text(
                  'Found ${_discoveredDevices.length} device${_discoveredDevices.length == 1 ? '' : 's'}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
                const Spacer(),
                if (_isScanning)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 1),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Scanning...',
                        style: TextStyle(fontSize: 12, color: Colors.blue),
                      ),
                    ],
                  )
                else if (_hasScanned)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Scan Complete',
                      style: TextStyle(fontSize: 10, color: Colors.green),
                    ),
                  ),
              ],
            ),
          ),

          // Device list
          Expanded(
            child: ListView.builder(
              itemCount: _discoveredDevices.length,
              itemBuilder: (context, index) {
                final device = _discoveredDevices[index];

                return Card(
                  margin: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 4.0),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(EvaIcons.monitor,
                          color: Colors.blue, size: 20),
                    ),
                    title: Text(
                      device.name,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          device.ipAddress,
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                        if (device.hasSmbPort || device.hasNetbiosPort)
                          Row(
                            children: [
                              if (device.hasSmbPort)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'SMB',
                                    style: TextStyle(
                                        fontSize: 10, color: Colors.green),
                                  ),
                                ),
                              if (device.hasSmbPort && device.hasNetbiosPort)
                                const SizedBox(width: 4),
                              if (device.hasNetbiosPort)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'NetBIOS',
                                    style: TextStyle(
                                        fontSize: 10, color: Colors.orange),
                                  ),
                                ),
                            ],
                          ),
                        if (device.smbVersion != null)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'SMB ${device.smbVersion}',
                              style: const TextStyle(
                                  fontSize: 10, color: Colors.blue),
                            ),
                          ),
                      ],
                    ),
                    trailing:
                        const Icon(EvaIcons.arrowForward, color: Colors.blue),
                    onTap: () =>
                        _connectToSMBServer(device.ipAddress, device.name),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
