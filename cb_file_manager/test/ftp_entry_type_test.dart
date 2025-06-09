import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FTP Entry Type Parsing Tests', () {
    test('should correctly identify file types', () {
      // Test cases for file type detection
      List<String> fileTypes = [
        'file',
        'ftpentrytype.file',
        'FILE',
        'FTPENTRYTYPE.FILE'
      ];

      for (String entryType in fileTypes) {
        String normalizedType = entryType.toLowerCase();
        bool isFile =
            normalizedType == "file" || normalizedType.endsWith(".file");
        expect(isFile, true, reason: 'Should identify $entryType as file');
      }
    });

    test('should correctly identify directory types', () {
      // Test cases for directory type detection
      List<String> dirTypes = [
        'dir',
        'ftpentrytype.dir',
        'DIR',
        'FTPENTRYTYPE.DIR'
      ];

      for (String entryType in dirTypes) {
        String normalizedType = entryType.toLowerCase();
        bool isDirectory =
            normalizedType == "dir" || normalizedType.endsWith(".dir");
        expect(isDirectory, true,
            reason: 'Should identify $entryType as directory');
      }
    });

    test('should not identify unknown types', () {
      // Test cases for unknown types
      List<String> unknownTypes = [
        'unknown',
        'ftpentrytype.unknown',
        'link',
        'socket'
      ];

      for (String entryType in unknownTypes) {
        String normalizedType = entryType.toLowerCase();
        bool isFile =
            normalizedType == "file" || normalizedType.endsWith(".file");
        bool isDirectory =
            normalizedType == "dir" || normalizedType.endsWith(".dir");
        expect(isFile, false, reason: 'Should not identify $entryType as file');
        expect(isDirectory, false,
            reason: 'Should not identify $entryType as directory');
      }
    });

    test('should handle edge cases', () {
      // Test edge cases
      expect('file'.endsWith('.file'), false);
      expect('ftpentrytype.file'.endsWith('.file'), true);
      expect('dir'.endsWith('.dir'), false);
      expect('ftpentrytype.dir'.endsWith('.dir'), true);
    });
  });
}
