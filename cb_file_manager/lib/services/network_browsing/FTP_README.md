# FTP Service for CB File Hub

This implementation uses the `ftpconnect` package to provide FTP functionality for the CB File Hub.

## Dependencies

The FTP service depends on the `ftpconnect` package. It's configured in `pubspec.yaml` to use the latest version from GitHub:

```yaml
ftpconnect:
  git:
    url: https://github.com/salim-lachdhaf/ftpconnect.git
    ref: master
```

## Features

The FTP service provides the following features:

- Connect to FTP servers with username/password authentication
- Browse directories on FTP servers
- Download files from FTP servers
- Upload files to FTP servers
- Create, delete, and rename files and directories
- Supports both active and passive FTP modes

## Usage Example

```dart
import 'package:cb_file_manager/services/network_browsing/ftp_service.dart';

// Create an instance of FTP service
final ftpService = FTPService();

// Connect to an FTP server
final result = await ftpService.connect(
  host: 'ftp.example.com',
  username: 'user',
  password: 'password',
  port: 21,
);

if (result.success) {
  // List directory contents
  final files = await ftpService.listDirectory('/');

  // Download a file
  if (files.isNotEmpty) {
    final remoteFile = files.first;
    await ftpService.getFile(
      remoteFile.path,
      '/path/to/local/file.txt',
    );
  }

  // Disconnect when done
  await ftpService.disconnect();
} else {
  print('Connection failed: ${result.errorMessage}');
}
```

## Error Handling

The FTP service provides detailed error messages for common issues:

- Connection failures
- Authentication errors
- Permission issues
- File transfer problems

## Implementation Notes

This service implements the `NetworkServiceBase` interface, allowing it to be used interchangeably with other network services like SMB or WebDAV in the CB File Hub.
