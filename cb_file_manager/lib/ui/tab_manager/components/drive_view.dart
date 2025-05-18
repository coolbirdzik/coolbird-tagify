import 'dart:io';
import 'dart:ffi';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cb_file_manager/helpers/filesystem_utils.dart';
import 'package:win32/win32.dart' as win32;
import 'package:ffi/ffi.dart';

import '../tab_manager.dart';
import '../../screens/folder_list/folder_list_bloc.dart';
import '../../screens/folder_list/folder_list_event.dart';

/// Component for displaying the drive list view with storage information
class DriveView extends StatelessWidget {
  final String tabId;
  final Function(String) onPathChanged;
  final FolderListBloc folderListBloc;
  final VoidCallback? onBackButtonPressed; // Add this parameter
  final VoidCallback? onForwardButtonPressed; // Add this parameter

  const DriveView({
    Key? key,
    required this.tabId,
    required this.onPathChanged,
    required this.folderListBloc,
    this.onBackButtonPressed, // Add this parameter
    this.onForwardButtonPressed, // Add this parameter
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Wrap the entire view with a Listener for mouse events
    return Listener(
      onPointerDown: (PointerDownEvent event) {
        // Mouse button 4 is usually the back button (button value is 8)
        if (event.buttons == 8 && onBackButtonPressed != null) {
          onBackButtonPressed!();
        }
        // Mouse button 5 is usually the forward button (button value is 16)
        else if (event.buttons == 16 && onForwardButtonPressed != null) {
          onForwardButtonPressed!();
        }
      },
      child: FutureBuilder<List<Directory>>(
        future: getAllWindowsDrives(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final drives = snapshot.data ?? [];
          if (drives.isEmpty) {
            return const Center(child: Text('Không tìm thấy ổ đĩa nào!'));
          }

          return Container(
            padding: const EdgeInsets.all(16.0),
            child: ListView.builder(
              itemCount: drives.length,
              itemBuilder: (context, index) {
                final drive = drives[index];
                final isDarkMode =
                    Theme.of(context).brightness == Brightness.dark;

                return Card(
                  margin: const EdgeInsets.only(bottom: 16.0),
                  color: isDarkMode ? Colors.grey[850] : Colors.white,
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: FutureBuilder<Map<String, dynamic>>(
                      future: _getDriveSpaceInfo(drive.path),
                      builder: (context, spaceSnapshot) {
                        // Default values
                        double usageRatio = 0.0;
                        String totalStr = '';
                        String freeStr = '';
                        String usedStr = '';

                        if (spaceSnapshot.hasData) {
                          final data = spaceSnapshot.data!;
                          usageRatio = data['usageRatio'] as double;
                          totalStr = data['totalStr'] as String;
                          freeStr = data['freeStr'] as String;
                          usedStr = data['usedStr'] as String;
                        }

                        // Define colors based on theme and usage
                        Color progressColor = usageRatio > 0.9
                            ? Colors.red
                            : (usageRatio > 0.7
                                ? Colors.orange
                                : Theme.of(context).colorScheme.primary);

                        Color progressBackgroundColor =
                            isDarkMode ? Colors.grey[800]! : Colors.grey[200]!;

                        Color textColor =
                            isDarkMode ? Colors.grey[300]! : Colors.grey[700]!;

                        Color headerTextColor =
                            isDarkMode ? Colors.white : Colors.black87;

                        Color usedColor = progressColor;

                        Color subtitleColor =
                            isDarkMode ? Colors.grey[400]! : Colors.grey[600]!;

                        return InkWell(
                          onTap: () {
                            context
                                .read<TabManagerBloc>()
                                .add(UpdateTabPath(tabId, drive.path));
                            context
                                .read<TabManagerBloc>()
                                .add(UpdateTabName(tabId, drive.path));
                            onPathChanged(drive.path);
                            folderListBloc.add(FolderListLoad(drive.path));
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Drive title and icon
                              Row(
                                children: [
                                  const Icon(Icons.storage, size: 36),
                                  const SizedBox(width: 12),
                                  FutureBuilder<String>(
                                    future: getDriveLabel(drive.path),
                                    builder: (context, labelSnapshot) {
                                      String displayText = drive.path;
                                      if (labelSnapshot.hasData &&
                                          labelSnapshot.data!.isNotEmpty) {
                                        displayText =
                                            '${drive.path} (${labelSnapshot.data})';
                                      }
                                      return Expanded(
                                        child: Text(
                                          displayText,
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: headerTextColor,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      );
                                    },
                                  ),
                                  const Icon(Icons.arrow_forward_ios, size: 16),
                                ],
                              ),
                              const SizedBox(height: 20),

                              // Progress bar
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: LinearProgressIndicator(
                                  value: usageRatio,
                                  backgroundColor: progressBackgroundColor,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      progressColor),
                                  minHeight: 12,
                                ),
                              ),

                              // Storage information
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Đã dùng: $usedStr',
                                      style: TextStyle(
                                          color: usedColor,
                                          fontWeight: FontWeight.w500),
                                    ),
                                    Text(
                                      'Còn trống: $freeStr',
                                      style: TextStyle(color: textColor),
                                    ),
                                  ],
                                ),
                              ),

                              Text(
                                'Tổng: $totalStr',
                                style: TextStyle(
                                    color: subtitleColor, fontSize: 12),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<Map<String, dynamic>> _getDriveSpaceInfo(String drivePath) async {
    try {
      final drive = drivePath.endsWith('\\') ? drivePath : '$drivePath\\';
      final lpFreeBytesAvailable = calloc.allocate<Uint64>(sizeOf<Uint64>());
      final lpTotalNumberOfBytes = calloc.allocate<Uint64>(sizeOf<Uint64>());
      final lpTotalNumberOfFreeBytes =
          calloc.allocate<Uint64>(sizeOf<Uint64>());

      final result = win32.GetDiskFreeSpaceEx(
        drive.toNativeUtf16(),
        lpFreeBytesAvailable,
        lpTotalNumberOfBytes,
        lpTotalNumberOfFreeBytes,
      );

      String totalStr = '';
      String freeStr = '';
      String usedStr = '';
      int totalBytes = 0;
      int freeBytes = 0;
      int usedBytes = 0;
      double usageRatio = 0.0;

      if (result != 0) {
        totalBytes = lpTotalNumberOfBytes.value;
        freeBytes = lpFreeBytesAvailable.value;
        usedBytes = totalBytes - freeBytes;

        totalStr = _formatSize(totalBytes);
        freeStr = _formatSize(freeBytes);
        usedStr = _formatSize(usedBytes);
        usageRatio = totalBytes > 0 ? usedBytes / totalBytes : 0;
      }

      // Free allocated memory
      calloc.free(lpFreeBytesAvailable);
      calloc.free(lpTotalNumberOfBytes);
      calloc.free(lpTotalNumberOfFreeBytes);

      return {
        'totalStr': totalStr,
        'freeStr': freeStr,
        'usedStr': usedStr,
        'total': totalBytes,
        'free': freeBytes,
        'used': usedBytes,
        'usageRatio': usageRatio,
      };
    } catch (e) {
      debugPrint('Error getting drive space info: $e');
      return {
        'totalStr': '',
        'freeStr': '',
        'usedStr': '',
        'total': 0,
        'free': 0,
        'used': 0,
        'usageRatio': 0.0,
      };
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
