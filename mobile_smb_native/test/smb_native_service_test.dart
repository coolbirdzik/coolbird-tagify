import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_smb_native/src/smb_platform_service.dart';
import 'package:mobile_smb_native/src/models/smb_connection_config.dart';

void main() {
  group('SmbPlatformService Tests', () {
    late SmbPlatformService service;

    setUp(() {
      service = SmbPlatformService.instance;
    });

    test('should be singleton', () {
      final service1 = SmbPlatformService.instance;
      final service2 = SmbPlatformService.instance;
      expect(service1, same(service2));
    });
    
    test('should provide platform status', () {
      final status = service.getPlatformStatus();
      expect(status, isA<Map<String, dynamic>>());
      expect(status.containsKey('platform'), isTrue);
      expect(status.containsKey('nativeAvailable'), isTrue);
      expect(status.containsKey('supportLevel'), isTrue);
    });
    
    test('should provide platform error message', () {
      final message = service.getPlatformErrorMessage();
      expect(message, isA<String>());
      expect(message.isNotEmpty, isTrue);
    });

    test('should start disconnected', () {
      expect(service.isConnected, isFalse);
    });

    group('Connection Config Validation', () {
      test('should validate valid config', () {
        final config = SmbConnectionConfig(
          host: '192.168.1.100',
          shareName: 'shared',
          username: 'testuser',
          password: 'testpass',
        );
        
        expect(config.host, equals('192.168.1.100'));
        expect(config.shareName, equals('shared'));
        expect(config.username, equals('testuser'));
        expect(config.password, equals('testpass'));
      });

      test('should handle empty credentials', () {
        final config = SmbConnectionConfig(
          host: '192.168.1.100',
          shareName: 'public',
          username: '',
          password: '',
        );
        
        expect(config.username, equals(''));
        expect(config.password, equals(''));
      });
    });

    // Note: These tests require a real SMB server to run
    // They are commented out to avoid test failures in CI/CD
    /*
    group('SMB Operations', () {
      final testConfig = SmbConnectionConfig(
        host: '192.168.1.100',
        shareName: 'testshare',
        username: 'testuser',
        password: 'testpass',
      );

      test('should connect to SMB server', () async {
        final result = await service.connect(testConfig);
        expect(result, isTrue);
        expect(service.isConnected, isTrue);
        
        // Clean up
        await service.disconnect();
      });

      test('should list directory contents', () async {
        await service.connect(testConfig);
        
        final files = await service.listDirectory('/');
        expect(files, isNotNull);
        expect(files, isA<List<SmbFileInfo>>());
        
        await service.disconnect();
      });

      test('should stream file data', () async {
        await service.connect(testConfig);
        
        final stream = service.streamFile('/test.txt');
        expect(stream, isNotNull);
        
        int totalBytes = 0;
        await for (final chunk in stream!) {
          totalBytes += chunk.length;
          expect(chunk, isA<List<int>>());
        }
        
        expect(totalBytes, greaterThan(0));
        
        await service.disconnect();
      });
    });
    */
  });
}