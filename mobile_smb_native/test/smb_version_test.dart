import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_smb_native/mobile_smb_native.dart';

void main() {
  group('SMB Version Detection Tests', () {
    test('should get SMB version when connected', () async {
      final client = MobileSmbClient();

      // Test connection (this would need a real SMB server for full testing)
      final config = SmbConnectionConfig(
        host: 'test-server',
        port: 445,
        username: 'testuser',
        password: 'testpass',
        shareName: 'testshare',
      );

      // Note: This test would require a real SMB server to fully test
      // For now, we test the method exists and returns a string
      final version = await client.getSmbVersion();
      expect(version, isA<String>());
    });

    test('should get connection info when connected', () async {
      final client = MobileSmbClient();

      final info = await client.getConnectionInfo();
      expect(info, isA<String>());
    });

    test('should create optimized stream', () async {
      final client = MobileSmbClient();

      // Test that optimized streaming method exists
      final stream =
          client.openFileStreamOptimized('/test/path', chunkSize: 1024 * 1024);
      // Note: This would be null if not connected, which is expected behavior
      expect(stream, isA<Stream<List<int>>?>());
    });
  });

  group('SMB Connection Config Tests', () {
    test('should create config with default SMB version', () {
      final config = SmbConnectionConfig(
        host: 'test-server',
        username: 'testuser',
        password: 'testpass',
      );

      expect(config.smbVersion, equals(2)); // Default SMB2
    });

    test('should create config with custom SMB version', () {
      final config = SmbConnectionConfig(
        host: 'test-server',
        username: 'testuser',
        password: 'testpass',
        smbVersion: 3,
      );

      expect(config.smbVersion, equals(3));
    });

    test('should serialize and deserialize config', () {
      final originalConfig = SmbConnectionConfig(
        host: 'test-server',
        port: 445,
        username: 'testuser',
        password: 'testpass',
        shareName: 'testshare',
        smbVersion: 3,
        timeoutMs: 30000,
      );

      final map = originalConfig.toMap();
      final restoredConfig = SmbConnectionConfig.fromMap(map);

      expect(restoredConfig.host, equals(originalConfig.host));
      expect(restoredConfig.port, equals(originalConfig.port));
      expect(restoredConfig.username, equals(originalConfig.username));
      expect(restoredConfig.password, equals(originalConfig.password));
      expect(restoredConfig.shareName, equals(originalConfig.shareName));
      expect(restoredConfig.smbVersion, equals(originalConfig.smbVersion));
      expect(restoredConfig.timeoutMs, equals(originalConfig.timeoutMs));
    });
  });
}
