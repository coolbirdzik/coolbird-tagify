import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// A service for discovering network devices and services
class NetworkDiscoveryService {
  static const int _smbPort = 445; // Standard SMB port
  static const int _netbiosPort =
      139; // NetBIOS port used by older SMB implementations
  static const int _timeoutMilliseconds = 200; // Socket connection timeout

  /// Singleton instance
  static final NetworkDiscoveryService _instance =
      NetworkDiscoveryService._internal();

  /// Factory constructor to return the singleton instance
  factory NetworkDiscoveryService() => _instance;

  /// Private constructor
  NetworkDiscoveryService._internal();

  /// Stream controller for discovered devices
  final StreamController<NetworkDevice> _deviceStreamController =
      StreamController<NetworkDevice>.broadcast();

  /// Stream of discovered devices
  Stream<NetworkDevice> get deviceStream => _deviceStreamController.stream;

  /// Status of the current scan
  bool _isScanning = false;

  /// Check if a scan is currently in progress
  bool get isScanning => _isScanning;

  /// List of discovered devices from the most recent scan
  final List<NetworkDevice> _discoveredDevices = [];

  /// Get the list of discovered devices
  List<NetworkDevice> get discoveredDevices =>
      List.unmodifiable(_discoveredDevices);

  /// Scan the local network for SMB devices
  Future<List<NetworkDevice>> scanNetwork() async {
    if (_isScanning) {
      return _discoveredDevices; // Return current list if already scanning
    }

    _isScanning = true;
    _discoveredDevices.clear();
    final futures = <Future>[];
    final scannedSubnets = <String>{};

    try {
      // Get all local IP addresses from all network interfaces
      final localIps = await _getAllLocalIps();

      if (localIps.isEmpty) {
        debugPrint(
            'NetworkDiscoveryService: Could not get any local IP address');
        _isScanning = false;
        return _discoveredDevices;
      }

      for (final ip in localIps) {
        // Extract the subnet (e.g., from 192.168.1.5 to 192.168.1)
        final ipParts = ip.split('.');
        if (ipParts.length != 4) {
          debugPrint('NetworkDiscoveryService: Invalid IP format: $ip');
          continue; // Skip to the next IP
        }

        final subnet = '${ipParts[0]}.${ipParts[1]}.${ipParts[2]}';

        // Check if this subnet has already been scanned
        if (scannedSubnets.contains(subnet)) {
          continue;
        }
        scannedSubnets.add(subnet);

        // Scan the subnet for devices with SMB ports open
        for (int i = 1; i <= 254; i++) {
          final host = '$subnet.$i';
          futures.add(_scanHost(host));
        }
      }

      // Wait for all scans to complete
      await Future.wait(futures);
    } catch (e) {
      debugPrint('NetworkDiscoveryService: Error during network scan: $e');
    } finally {
      _isScanning = false;
    }

    return _discoveredDevices;
  }

  /// Cancel an ongoing scan
  void cancelScan() {
    _isScanning = false;
  }

  /// Scan a specific host for SMB ports
  Future<void> _scanHost(String host) async {
    if (!_isScanning) return; // Check if scan was canceled

    // Try to connect to SMB port
    bool isSmbPort = await _isPortOpen(host, _smbPort);
    bool isNetbiosPort = false;

    // If SMB port is closed, try NetBIOS port
    if (!isSmbPort) {
      isNetbiosPort = await _isPortOpen(host, _netbiosPort);
    }

    // If either port is open, add the device to the list
    if (isSmbPort || isNetbiosPort) {
      debugPrint('NetworkDiscoveryService: Found SMB device at $host');

      // Prevent adding duplicate devices
      if (_discoveredDevices.any((device) => device.ipAddress == host)) {
        return;
      }

      // Try to get the hostname
      String? deviceName = await _getHostnameByIp(host);

      final device = NetworkDevice(
        ipAddress: host,
        name: deviceName ?? 'Unknown',
        type: NetworkDeviceType.smb,
        hasSmbPort: isSmbPort,
        hasNetbiosPort: isNetbiosPort,
      );

      _discoveredDevices.add(device);
      _deviceStreamController.add(device);
    }
  }

  /// Check if a port is open on a host
  Future<bool> _isPortOpen(String host, int port) async {
    try {
      final socket = await Socket.connect(host, port,
          timeout: const Duration(milliseconds: _timeoutMilliseconds));

      await socket.close();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Try to get hostname for an IP address
  Future<String?> _getHostnameByIp(String ipAddress) async {
    try {
      // This is a simple implementation that may not work in all environments
      // In a real implementation, you might use NetBIOS name service or NBNS queries
      final result = await InternetAddress(ipAddress).reverse();
      return result.host;
    } catch (e) {
      return null;
    }
  }

  /// Get all local IPv4 addresses from all available network interfaces.
  Future<List<String>> _getAllLocalIps() async {
    final List<String> ips = [];
    try {
      // Look for all non-loopback, non-link-local IPv4 addresses.
      final interfaces = await NetworkInterface.list(
          type: InternetAddressType.IPv4,
          includeLoopback: false,
          includeLinkLocal: false);

      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          ips.add(addr.address);
        }
      }
    } catch (e) {
      debugPrint("NetworkDiscoveryService: Error getting local IPs: $e");
    }
    return ips;
  }

  /// Dispose the service and close streams
  void dispose() {
    _deviceStreamController.close();
  }
}

/// Represents a discovered network device
class NetworkDevice {
  final String ipAddress;
  final String name;
  final NetworkDeviceType type;
  final bool hasSmbPort;
  final bool hasNetbiosPort;

  NetworkDevice({
    required this.ipAddress,
    required this.name,
    required this.type,
    this.hasSmbPort = false,
    this.hasNetbiosPort = false,
  });

  @override
  String toString() {
    return '$name ($ipAddress)';
  }
}

/// Types of network devices
enum NetworkDeviceType {
  smb,
  ftp,
  webdav,
  unknown,
}
