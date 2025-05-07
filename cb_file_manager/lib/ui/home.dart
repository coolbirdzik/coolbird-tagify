import 'package:flutter/material.dart';
import 'package:cb_file_manager/ui/utils/base_screen.dart';
import 'package:cb_file_manager/ui/home/local_home.dart';
import 'package:cb_file_manager/ui/screens/folder_list/folder_list_screen.dart';
import 'package:cb_file_manager/helpers/user_preferences.dart';
import 'utils/route.dart';
import 'package:cb_file_manager/main.dart' show goHome;
import 'dart:io';

class MyHomePage extends StatefulWidget {
  final String title;

  const MyHomePage({Key? key, required this.title}) : super(key: key);

  @override
  MyHomePageState createState() => MyHomePageState();
}

// Changed from private (_MyHomePageState) to public (MyHomePageState)
// so it can be accessed with a global key
class MyHomePageState extends State<MyHomePage> {
  String? _lastAccessedFolder;

  @override
  void initState() {
    super.initState();
    _loadLastFolder();
  }

  Future<void> _loadLastFolder() async {
    final prefs = UserPreferences.instance;
    await prefs.init();
    final lastFolder = await prefs.getLastAccessedFolder();
    setState(() {
      _lastAccessedFolder = lastFolder;
    });
  }

  // Check if there's a saved folder and navigate to it safely
  Future<void> _checkLastFolderAndNavigate() async {
    try {
      final UserPreferences prefs = UserPreferences.instance;
      await prefs.init();
      final String? lastFolder = await prefs.getLastAccessedFolder();

      if (lastFolder != null && mounted) {
        // Verify directory exists and is accessible before navigating
        final directory = Directory(lastFolder);
        if (await directory.exists()) {
          // Navigate to the last opened folder - with extra safety checks
          try {
            // Use pushReplacement instead of pop operations that might cause empty stack issues
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => FolderListScreen(path: lastFolder),
              ),
            );
          } catch (e) {
            print('Error navigating to last folder: $e');
            // Clear the problematic saved path if navigation fails
            await prefs.clearLastAccessedFolder();
          }
        } else {
          // If directory no longer exists, clear the preference
          print('Last accessed directory does not exist: $lastFolder');
          await prefs.clearLastAccessedFolder();
        }
      }
    } catch (e) {
      print('Error in _checkLastFolderAndNavigate: $e');
      // Stay on home screen if there's any error
    }
  }

  // Method that can be called from the global key
  void resetToHome() {
    if (mounted) {
      try {
        // Check if there are routes to pop before attempting to pop
        if (Navigator.of(context).canPop()) {
          // Clear any existing navigation stack back to this home page
          Navigator.popUntil(context, (route) => route.isFirst);
        }
      } catch (e) {
        print('Error resetting to home: $e');
        // If navigation fails, use the goHome function from main.dart which is more reliable
        // This avoids creating a new navigator with an empty stack
        if (mounted) {
          goHome(context);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BaseScreen(
      title: widget.title,
      automaticallyImplyLeading: false, // No back button on home screen
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'CoolBird File Manager',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),
            const Icon(
              Icons.file_copy_outlined,
              size: 100,
              color: Colors.green,
            ),
            const SizedBox(height: 40),
            const Text(
              'Your complete file management solution',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            const Text(
              'Organize your files with powerful tagging capabilities',
              style: TextStyle(fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              icon: const Icon(Icons.folder_open),
              label: const Text('Browse Files'),
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              ),
              onPressed: () {
                RouteUtils.safeNavigate(context, const LocalHome());
              },
            ),
          ],
        ),
      ),
    );
  }
}
