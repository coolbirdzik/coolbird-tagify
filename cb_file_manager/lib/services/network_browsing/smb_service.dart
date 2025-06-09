import 'dart:io';
import 'dart:typed_data'; // Required for smb_connect
import 'package:flutter/material.dart';
import 'package:eva_icons_flutter/eva_icons_flutter.dart';
import 'package:path/path.dart' as p; // Aliased to avoid conflict
import 'package:smb_connect/smb_connect.dart'; // Added smb_connect import

import 'network_service_base.dart';

/// Service for SMB (Server Message Block) network file access
class SMBService implements NetworkServiceBase {
  static const String _smbScheme = 'smb'; // Just the scheme

  // Store SmbConnect instances keyed by host (e.g., "server_ip_or_hostname")
  // A single SmbService instance might be reused by NetworkServiceRegistry if it deems it appropriate,
  // but NetworkServiceRegistry manages connections by their full base path (smb://host/share).
  // This SmbService class itself will primarily operate on one connection at a time,
  // established via the `connect` method. The SmbConnect object is stored per instance.
  SmbConnect? _smbConnection;
  String _connectedHost = ''; // e.g., "server.example.com"
  String _connectedShare = ''; // e.g., "shareName"
  String _username = '';
  String _domain = '';
  // No longer storing _currentPath here as it's managed by NetworkBrowsingBloc via tabPath

  @override
  String get serviceName => 'SMB';

  @override
  String get serviceDescription => 'Windows Shared Folders (SMB)';

  @override
  IconData get serviceIcon => EvaIcons.folder;

  @override
  bool isAvailable() => true;

  @override
  bool get isConnected => _smbConnection != null;

  // basePath should represent the root of the connected share.
  @override
  String get basePath => '$_smbScheme://$_connectedHost/$_connectedShare';

  // Parse a host string to extract server and share
  // Input can be in format: server or server/share
  Map<String, String> _parseHostAndShare(String hostInput) {
    final String normalized =
        hostInput.trim().replaceAll(RegExp(r'[/\\]+'), '/');

    // Check if we have a server/share format
    if (normalized.contains('/')) {
      final parts = normalized.split('/');
      return {
        'host': parts[0],
        'share': parts.length > 1 ? parts[1] : '',
      };
    } else {
      // Just the server name, no share
      return {
        'host': normalized,
        'share': '', // Empty share means we'll just list all shares
      };
    }
  }

  // Helper to extract the remote path relative to the share from a full tabPath
  // tabPath example: #network/SMB/encoded_server/shareName/optional/subfolder/
  // smb_connect expects paths like: /shareName/optional/subfolder/
  String _getSmbPathFromTabPath(String tabPath) {
    debugPrint("SMBService: Converting tab path to SMB path: '$tabPath'");

    if (!tabPath.startsWith('#network/$_smbScheme/')) {
      debugPrint("SMBService: Path does not start with the expected prefix.");
      return '/';
    }

    final parts = tabPath.split('/');
    debugPrint("SMBService: Path parts: $parts (length: ${parts.length})");

    // Expected format: #network/smb/host/share/folder/
    // split -> ["#network", "smb", "host", "share", "folder", ""]
    // parts[0] = "#network", parts[1] = "smb", parts[2] = "host", parts[3] = "share"
    if (parts.length < 5) {
      // Not deep enough to be inside a share.
      debugPrint(
          "SMBService: Path is not inside a share, returning root. Parts length: ${parts.length}");
      return '/';
    }

    // According to smb_connect documentation, the path should be:
    // For share "public": "/public/"
    // For subfolder in share "public": "/public/subfolder/"
    //
    // parts[3] is the share name, parts[4] onwards are subfolders
    // For "#network/smb/host/share/", we want "/share/"
    // For "#network/smb/host/share/subfolder/", we want "/share/subfolder/"

    String shareName = parts[3];
    String smbPath = '/$shareName';

    // Add subfolders if any (parts[4] onwards)
    if (parts.length > 5) {
      // parts[4] onwards are subfolders, but exclude empty parts
      final subfolders = parts.sublist(4).where((p) => p.isNotEmpty);
      if (subfolders.isNotEmpty) {
        smbPath += '/${subfolders.join('/')}';
      }
    }

    // Always add trailing slash for directories (which SMB paths should be for listing)
    if (!smbPath.endsWith('/')) {
      smbPath += '/';
    }

    // Sanitize any double slashes that might have been created.
    smbPath = smbPath.replaceAll('//', '/');

    debugPrint("SMBService: Share: '$shareName', Final SMB path: '$smbPath'");
    return smbPath;
  }

  @override
  Future<ConnectionResult> connect({
    required String host,
    required String username,
    String? password,
    int? port,
    Map<String, dynamic>? additionalOptions,
  }) async {
    debugPrint(
        "SMBService: Starting connection to: '$host' with username: '$username'");
    if (port != null && port != 445) {
      debugPrint(
          "SMBService: Note - custom port $port specified but smb_connect library uses default port 445");
    }
    await disconnect();

    final trimmedHost = host.trim();
    debugPrint("SMBService: Trimmed host: '$trimmedHost'");

    final hostShareMap = _parseHostAndShare(trimmedHost);
    final serverHost = hostShareMap['host']!;
    final shareName = hostShareMap['share']!;

    debugPrint(
        "SMBService: Extracted serverHost: '$serverHost', shareName: '$shareName'");

    if (serverHost.isEmpty) {
      debugPrint("SMBService: Server address is empty! Cannot connect.");
      return ConnectionResult(
          success: false,
          errorMessage:
              'Server address cannot be empty. Please ensure the server name or IP is provided before the "/".');
    }

    _domain = additionalOptions?['domain'] as String? ?? '';
    _username = username;

    debugPrint("SMBService: Using domain: '$_domain'");

    try {
      debugPrint(
          "SMBService: Attempting SmbConnect.connectAuth to host: '$serverHost'");

      // Connect to the SMB server
      SmbConnect connection = await SmbConnect.connectAuth(
        host: serverHost,
        domain: _domain,
        username: _username,
        password: password ?? '',
      );

      debugPrint(
          "SMBService: Connected to SMB server '$serverHost' successfully");

      // Setup the connection
      _smbConnection = connection;
      _connectedHost = serverHost;

      // If a share was specified in the host string, we'll set it as current share
      if (shareName.isNotEmpty) {
        _connectedShare = shareName;

        // Try to access the share to validate it
        try {
          SmbFile shareFile = await connection.file('/$shareName');
          if (shareFile.isDirectory != true) {
            debugPrint(
                "SMBService: '/$shareName' is not a directory! Keeping connection without specific share.");
            _connectedShare = '';
          }
        } catch (e) {
          debugPrint("SMBService: Error accessing share '$shareName': $e");
          _connectedShare = '';
        }
      } else {
        // No specific share, we'll connect to the server root
        _connectedShare = '';
      }

      // If we have a connected share, use it in the path
      String connectedPath = '$_smbScheme://$_connectedHost';
      if (_connectedShare.isNotEmpty) {
        connectedPath += '/$_connectedShare';
      }

      debugPrint("SMBService: Connection established to: $connectedPath");
      return ConnectionResult(
        success: true,
        connectedPath: connectedPath,
      );
    } catch (connectionError) {
      debugPrint("SMBService: Server connection failed: $connectionError");
      return ConnectionResult(
          success: false,
          errorMessage: 'SMB Connection failed: $connectionError');
    }
  }

  @override
  Future<void> disconnect() async {
    if (_smbConnection != null) {
      await _smbConnection!.close();
    }
    _smbConnection = null;
    _connectedHost = '';
    _connectedShare = '';
    _username = '';
    _domain = '';
  }

  @override
  Future<List<FileSystemEntity>> listDirectory(String tabPath) async {
    debugPrint("--- SMBService: Listing directory for tabPath: '$tabPath' ---");

    if (!isConnected) {
      debugPrint("SMBService: Error - Not connected.");
      throw Exception('Not connected to SMB server');
    }

    final pathParts = tabPath.split('/');
    debugPrint(
        "SMBService: listDirectory pathParts: $pathParts (length: ${pathParts.length})");
    // #network/smb/host/ -> length 4, after split: ["#network", "smb", "host", ""]
    // #network/smb/host/share/ -> length 5, after split: ["#network", "smb", "host", "share", ""]
    // A request to list shares is at the host level, before a share is selected.

    // Actually, let's be more specific about what constitutes a root level request
    // pathParts[0] = "#network", pathParts[1] = "smb", pathParts[2] = "host"
    // If we only have these 3 parts + empty string at end, then we're at host level
    final bool isRootLevelRequest = pathParts.length <= 4;
    debugPrint(
        "SMBService: isRootLevelRequest: $isRootLevelRequest (pathParts.length: ${pathParts.length})");

    if (isRootLevelRequest) {
      debugPrint("SMBService: Request is for root level, listing shares.");
      try {
        final List<SmbFile> shares = await _smbConnection!.listShares();
        debugPrint("SMBService: Found ${shares.length} shares.");

        final List<FileSystemEntity> result = [];
        for (var share in shares) {
          final String sharePath = share.path;
          final String shareName =
              sharePath.startsWith('/') ? sharePath.substring(1) : sharePath;

          if (shareName == "IPC\$" || shareName.endsWith("\$")) {
            continue;
          }

          final String shareTabPath =
              "#network/$_smbScheme/${Uri.encodeComponent(_connectedHost)}/$shareName/";
          result.add(Directory(shareTabPath));
          debugPrint(
              "SMBService: Added share: '$shareName', path: '$shareTabPath'");
        }
        return result;
      } catch (e) {
        debugPrint("SMBService: Error listing shares: $e");
        throw Exception('Error listing SMB shares: $e');
      }
    } else {
      // Listing content of a share or its subfolder.
      final smbPath = _getSmbPathFromTabPath(tabPath);
      debugPrint("SMBService: Converted to SMB path for listing: '$smbPath'");

      try {
        debugPrint("SMBService: Getting SmbFile for folder: '$smbPath'");

        // Following the exact pattern from smb_connect documentation:
        // SmbFile folder = await connect.file("/public/");
        // List<SmbFile> files = await connect.listFiles(folder);
        SmbFile folder = await _smbConnection!.file(smbPath);

        debugPrint(
            "SMBService: SmbFile created. Path: '${folder.path}', isDirectory: ${folder.isDirectory}, Exists: ${folder.isExists}");

        // For debugging, let's also check what type of object we got
        debugPrint("SMBService: folder.runtimeType: ${folder.runtimeType}");

        // Simply try to list files directly without checking properties first
        // as the smb_connect library might handle this internally
        final List<SmbFile> smbFiles = await _smbConnection!.listFiles(folder);
        debugPrint(
            "SMBService: Successfully listed ${smbFiles.length} items inside '$smbPath'");

        final List<FileSystemEntity> entities = [];
        for (var smbFile in smbFiles) {
          final String itemName = smbFile.name;
          debugPrint(
              "SMBService: Processing item: '$itemName', isDirectory: ${smbFile.isDirectory}");

          if (itemName == "." || itemName == "..") {
            continue;
          }

          String baseTabPath = tabPath.endsWith('/') ? tabPath : '$tabPath/';
          String entityTabPath =
              p.join(baseTabPath, itemName).replaceAll('\\', '/');

          if (smbFile.isDirectory == true && !entityTabPath.endsWith('/')) {
            entityTabPath += '/';
            entities.add(Directory(entityTabPath));
            debugPrint("SMBService: Added directory: '$entityTabPath'");
          } else {
            entities.add(File(entityTabPath));
            debugPrint("SMBService: Added file: '$entityTabPath'");
          }
        }

        debugPrint("SMBService: Returning ${entities.length} entities");
        return entities;
      } catch (e) {
        debugPrint(
            "SMBService: Error listing directory for SMB path '$smbPath'. Error: $e");
        debugPrint("SMBService: Error type: ${e.runtimeType}");
        throw Exception("Error listing SMB directory '$smbPath': $e");
      }
    }
  }

  @override
  Future<File> getFile(String remoteTabPath, String localPath) async {
    if (!isConnected) throw Exception('Not connected to SMB server.');
    final smbPath = _getSmbPathFromTabPath(remoteTabPath);

    try {
      SmbFile remoteSmbFile = await _smbConnection!.file(smbPath);
      if (remoteSmbFile.isDirectory == true) {
        throw Exception('$smbPath is a directory, not a file.');
      }
      if (remoteSmbFile.isExists != true) {
        throw Exception('Remote file $smbPath does not exist.');
      }

      Stream<Uint8List> reader = await _smbConnection!.openRead(remoteSmbFile);
      final localFile = File(localPath);
      final sink = localFile.openWrite();

      // Manual pipe
      await reader.listen((data) {
        sink.add(data);
      }).asFuture();
      await sink.flush();
      await sink.close();

      return localFile;
    } catch (e) {
      throw Exception('Error downloading SMB file $smbPath: $e');
    }
  }

  @override
  Future<bool> putFile(String localPath, String remoteTabPath) async {
    if (!isConnected) throw Exception('Not connected to SMB server.');
    // remoteTabPath is the destination path for the file on the server, including the filename.
    // e.g., #network/SMB/host/Sshare/folder/uploadedFile.txt
    final smbPath = _getSmbPathFromTabPath(remoteTabPath);

    try {
      final localFile = File(localPath); // Using dart:io:File
      if (!await localFile.exists()) {
        throw Exception('Local file $localPath does not exist.');
      }

      // Check if destination already exists and is a directory
      try {
        SmbFile destCheck = await _smbConnection!.file(smbPath);
        if (destCheck.isExists == true && destCheck.isDirectory == true) {
          throw Exception('Cannot overwrite a directory $smbPath with a file.');
        }
      } catch (e) {
        // If smbConnection.file() throws because path doesn't exist, that's fine, we are creating it.
        // Otherwise, rethrow if it's a different unexpected error.
        if (!e.toString().toLowerCase().contains("does not exist") &&
            !e.toString().toLowerCase().contains("not found")) {
          // A more specific check for smb_connect's non-existence error might be needed.
          // For now, this is a heuristic.
          print(
              "Pre-upload check for $smbPath encountered: $e. Proceeding with upload attempt.");
        }
      }

      // smb_connect's createFile will create the file object representation,
      // and openWrite will handle actual file creation on the server.
      SmbFile remoteSmbFile = await _smbConnection!.createFile(smbPath);
      var writer =
          await _smbConnection!.openWrite(remoteSmbFile); // smb_connect IOSink

      Stream<List<int>> localFileStream = localFile.openRead();

      await localFileStream.forEach((chunk) {
        writer.add(chunk);
      });

      await writer.flush();
      await writer.close();

      return true;
    } catch (e) {
      // Attempt to clean up partially created file on error
      print('Upload failed for $smbPath. Attempting to delete partial file.');
      try {
        SmbFile? fileToDelete = await _smbConnection?.file(smbPath);
        if (fileToDelete?.isExists == true) {
          await _smbConnection!.delete(fileToDelete!);
          print(
              'Successfully deleted partial file $smbPath after failed upload.');
        }
      } catch (deleteError) {
        print(
            "Error cleaning up partially uploaded file $smbPath: $deleteError. The file might not exist or another issue occurred.");
      }
      throw Exception('Error uploading file to SMB $smbPath: $e');
    }
  }

  @override
  Future<bool> deleteFile(String tabPath) async {
    if (!isConnected) throw Exception('Not connected to SMB server.');
    final smbPath = _getSmbPathFromTabPath(tabPath);
    try {
      SmbFile fileToDelete = await _smbConnection!.file(smbPath);
      if (fileToDelete.isExists == true) {
        // It might be a directory, or not exist. delete() handles both.
        // For clarity, one might check type or let delete() fail if wrong type for "deleteFile"
        // return false; // Or throw if strict about it being a file
      }
      await _smbConnection!.delete(fileToDelete);
      return true;
    } catch (e) {
      print('Error deleting SMB file $smbPath: $e');
      return false;
    }
  }

  @override
  Future<bool> createDirectory(String tabPath) async {
    if (!isConnected) {
      throw Exception('Not connected to SMB server for path: $tabPath');
    }
    // tabPath is the path of the new directory to be created.
    // e.g., #network/SMB/host/Sshare/newFolder/
    // Ensure tabPath for smb_connect does not have a trailing slash if createFolder expects exact name
    // The _getSmbPathFromTabPath should handle normalization.
    // SmbConnect.createFolder takes the full path of the folder to create.
    String smbPath = _getSmbPathFromTabPath(tabPath);
    // createFolder expects the path to the folder, e.g. /shareName/newFolder
    // If tabPath was #network/.../Sshare/newFolder/, _getSmbPathFromTabPath should produce /shareName/newFolder

    try {
      // Remove trailing slash for createFolder if smb_connect expects exact name
      String effectiveSmbPath = smbPath;
      if (effectiveSmbPath.endsWith('/') && effectiveSmbPath.length > 1) {
        // Keep root "/" if that's the path
        effectiveSmbPath =
            effectiveSmbPath.substring(0, effectiveSmbPath.length - 1);
      }

      // Check if path already exists and is a file
      try {
        SmbFile destCheck = await _smbConnection!.file(effectiveSmbPath);
        if (destCheck.isExists == true && destCheck.isDirectory != true) {
          throw Exception(
              'A file already exists at $effectiveSmbPath, cannot create directory.');
        }
        if (destCheck.isExists == true && destCheck.isDirectory == true) {
          // already exists as dir
          print("Directory $effectiveSmbPath already exists.");
          return true; // Idempotent
        }
      } catch (e) {
        // If .file() throws, it might be because it doesn't exist, which is good for createFolder.
        // Log other errors if necessary.
        if (!e.toString().toLowerCase().contains("does not exist") &&
            !e.toString().toLowerCase().contains("not found")) {
          print(
              "Pre-createDirectory check for $effectiveSmbPath encountered: $e. Proceeding with create attempt.");
        }
      }

      await _smbConnection!.createFolder(effectiveSmbPath);
      return true;
    } catch (e) {
      throw Exception('Error creating SMB directory $smbPath: $e');
    }
  }

  @override
  Future<bool> delete(String tabPath, {bool recursive = false}) async {
    if (!isConnected) {
      throw Exception('Not connected to SMB server for path: $tabPath');
    }
    final smbPath = _getSmbPathFromTabPath(tabPath);

    try {
      // smb_connect's delete takes an SmbFile object.
      // We need to get this object first using its path.
      SmbFile fileOrFolderToDelete = await _smbConnection!.file(smbPath);

      // Check if it exists before trying to delete
      if (fileOrFolderToDelete.isExists != true) {
        print("Entity $smbPath does not exist. Nothing to delete.");
        return true; // Or true, depending on desired idempotency semantics
      }

      // Use isDirectory for the recursive check warning
      if (recursive && fileOrFolderToDelete.isDirectory == true) {
        print(
            "Warning: Recursive delete for SMB folders is dependent on server behavior or may not delete contents if folder is not empty.");
      }

      await _smbConnection!.delete(fileOrFolderToDelete);
      return true;
    } catch (e) {
      throw Exception(
          'Error deleting SMB entity $smbPath: $e. If it is a non-empty folder, it might need to be emptied first.');
    }
  }

  @override
  Future<bool> rename(String oldTabPath, String newTabPath) async {
    if (!isConnected) {
      throw Exception('Not connected to SMB server.');
    }
    final oldSmbPath = _getSmbPathFromTabPath(oldTabPath);
    final newSmbPath = _getSmbPathFromTabPath(newTabPath);

    // smb_connect.rename(SmbFile file, String newName)
    // newName is the full new path, e.g. /shareName/newFilename.txt or /shareName/newFolderName

    // For smb_connect, newName for rename should be just the new name within the same directory,
    // or the full path if moving across directories (which rename also supports).
    // The `smb_connect` README says `await connect.rename(file, "/public/test1.txt");`
    // This implies newName is the full new path.

    try {
      SmbFile oldFileEntity = await _smbConnection!.file(oldSmbPath);
      if (oldFileEntity.isExists != true) {
        throw Exception("Source entity $oldSmbPath does not exist for rename.");
      }

      // Check if target exists and is a directory if old is a file, or vice versa
      try {
        SmbFile targetCheck = await _smbConnection!.file(newSmbPath);
        if (targetCheck.isExists == true) {
          // Basic check: if old is dir, new must be dir. If old is file, new must be file.
          // More complex logic (e.g. overwriting file with file) might be desired by smb_connect's rename.
          // For now, we prevent renaming if target exists and is of a different "general" type.
          if (oldFileEntity.isDirectory == true &&
              targetCheck.isDirectory != true) {
            throw Exception(
                "Cannot rename directory $oldSmbPath to an existing file $newSmbPath");
          }
          if (oldFileEntity.isDirectory != true &&
              targetCheck.isDirectory == true) {
            throw Exception(
                "Cannot rename file $oldSmbPath to an existing directory $newSmbPath");
          }
          // If types are compatible, smb_connect's rename might overwrite or fail, depending on server.
        }
      } catch (e) {
        // If newSmbPath doesn't exist, that's good.
        if (!e.toString().toLowerCase().contains("does not exist") &&
            !e.toString().toLowerCase().contains("not found")) {
          print(
              "Pre-rename check for target $newSmbPath encountered: $e. Proceeding with rename attempt.");
        }
      }

      await _smbConnection!.rename(oldFileEntity, newSmbPath);
      return true;
    } catch (e) {
      throw Exception(
          'Error renaming SMB entity from $oldSmbPath to $newSmbPath: $e');
    }
  }

  // Implementation for NetworkServiceBase.deleteDirectory
  @override
  Future<bool> deleteDirectory(String tabPath, {bool recursive = false}) async {
    // This service's `delete` method handles both files and directories.
    return delete(tabPath, recursive: recursive);
  }

  @override
  Future<File> getFileWithProgress(String remotePath, String localPath,
      void Function(double progress)? onProgress) async {
    // For SMB, we don't have a progress-based implementation yet
    // Just call the regular method and simulate progress updates
    if (onProgress != null) {
      // Start with 0%
      onProgress(0.0);

      // Simulate progress to show activity
      for (int i = 1; i <= 9; i++) {
        await Future.delayed(const Duration(milliseconds: 200));
        onProgress(i / 10);
      }
    }

    final result = await getFile(remotePath, localPath);

    // Complete with 100%
    if (onProgress != null) {
      onProgress(1.0);
    }

    return result;
  }

  @override
  Future<bool> putFileWithProgress(String localPath, String remotePath,
      void Function(double progress)? onProgress) async {
    // For SMB, we don't have a progress-based implementation yet
    // Just call the regular method and simulate progress updates
    if (onProgress != null) {
      // Start with 0%
      onProgress(0.0);

      // Simulate progress to show activity
      for (int i = 1; i <= 9; i++) {
        await Future.delayed(const Duration(milliseconds: 200));
        onProgress(i / 10);
      }
    }

    final result = await putFile(localPath, remotePath);

    // Complete with 100%
    if (onProgress != null) {
      onProgress(1.0);
    }

    return result;
  }
}
