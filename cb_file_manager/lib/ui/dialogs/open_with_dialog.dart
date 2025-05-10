import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cb_file_manager/helpers/external_app_helper.dart';
import 'package:file_picker/file_picker.dart';

class OpenWithDialog extends StatefulWidget {
  final String filePath;

  const OpenWithDialog({Key? key, required this.filePath}) : super(key: key);

  @override
  State<OpenWithDialog> createState() => _OpenWithDialogState();
}

class _OpenWithDialogState extends State<OpenWithDialog> {
  late Future<List<AppInfo>> _appsFuture;
  bool _loadingIcons = false;

  @override
  void initState() {
    super.initState();
    _appsFuture = ExternalAppHelper.getInstalledAppsForFile(widget.filePath);
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.open_in_new,
                    color: isDarkMode ? Colors.white70 : Colors.black87),
                const SizedBox(width: 8),
                Text(
                  'Open with',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                if (_loadingIcons) ...[
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: isDarkMode ? Colors.white70 : Colors.blue,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            FutureBuilder<List<AppInfo>>(
              future: _appsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Text(
                        'Error loading applications',
                        style: TextStyle(
                          color: isDarkMode ? Colors.red[300] : Colors.red,
                        ),
                      ),
                    ),
                  );
                }

                final apps = snapshot.data ?? [];

                if (apps.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Text(
                        'No applications found for this file type',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                return Container(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: apps.length,
                          itemBuilder: (context, index) {
                            final app = apps[index];
                            return ListTile(
                              leading: app.icon,
                              title: Text(app.appName),
                              onTap: () async {
                                setState(() {
                                  _loadingIcons = true;
                                });

                                Navigator.pop(context);

                                if (app.packageName == 'shell_open') {
                                  // Use Process.start for Windows shell execution
                                  if (Platform.isWindows) {
                                    final process = await Process.start(
                                        'explorer', [widget.filePath]);
                                    await process.exitCode;
                                  }
                                } else {
                                  await ExternalAppHelper.openFileWithApp(
                                      widget.filePath, app.packageName);
                                }

                                if (mounted) {
                                  setState(() {
                                    _loadingIcons = false;
                                  });
                                }
                              },
                            );
                          },
                        ),
                      ),
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.more_horiz),
                        title: const Text('Choose another app...'),
                        onTap: () async {
                          // Close the dialog
                          Navigator.pop(context);

                          // Use file_picker to select an executable
                          if (Platform.isWindows) {
                            FilePickerResult? result =
                                await FilePicker.platform.pickFiles(
                              type: FileType.custom,
                              allowedExtensions: ['exe'],
                              dialogTitle:
                                  'Select an application to open this file',
                            );

                            if (result != null &&
                                result.files.single.path != null) {
                              final appPath = result.files.single.path!;
                              await ExternalAppHelper.openFileWithApp(
                                  widget.filePath, appPath);
                            }
                          } else if (Platform.isAndroid) {
                            // On Android, we can use the system's app chooser
                            await ExternalAppHelper.openWithSystemChooser(
                                widget.filePath);
                          }
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
