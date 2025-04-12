import 'package:flutter/material.dart';
import 'package:cb_file_manager/ui/utils/base_screen.dart';

/// Helper class to standardize app bar functionality across the application
class ActionBarHelper {
  /// Creates a standard app bar with the given title
  static AppBar createAppBar({
    required String title,
    required BuildContext context,
    List<Widget>? actions,
    bool automaticallyImplyLeading = true,
    Color? backgroundColor,
    PreferredSizeWidget? bottom,
    double? elevation,
    Widget? flexibleSpace,
  }) {
    return AppBar(
      title: Text(title),
      actions: actions,
      leading: automaticallyImplyLeading ? _buildLeadingIcon(context) : null,
      backgroundColor: backgroundColor,
      bottom: bottom,
      elevation: elevation,
      flexibleSpace: flexibleSpace,
    );
  }

  /// Builds the leading icon (back button or drawer toggle) based on navigation context
  static Widget? _buildLeadingIcon(BuildContext context) {
    final ModalRoute<dynamic>? parentRoute = ModalRoute.of(context);
    final bool canPop = parentRoute?.canPop ?? false;

    if (canPop) {
      return IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => _handleBackNavigation(context),
      );
    } else {
      return IconButton(
        icon: const Icon(Icons.menu),
        onPressed: () => BaseScreen.openDrawer(),
      );
    }
  }

  /// Handles back navigation, either popping the current route or showing a dialog
  static void _handleBackNavigation(BuildContext context) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      // Show exit confirmation dialog when trying to exit the app
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Exit Application?'),
          content: const Text('Are you sure you want to exit the application?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Exit'),
            ),
          ],
        ),
      ).then((value) {
        if (value == true) {
          // Exit the app if confirmed
          Navigator.of(context).pop();
        }
      });
    }
  }

  /// Creates a search action for the app bar
  static IconButton createSearchAction(VoidCallback onPressed) {
    return IconButton(
      icon: const Icon(Icons.search),
      tooltip: 'Search',
      onPressed: onPressed,
    );
  }

  /// Creates a settings action for the app bar
  static IconButton createSettingsAction(VoidCallback onPressed) {
    return IconButton(
      icon: const Icon(Icons.settings),
      tooltip: 'Settings',
      onPressed: onPressed,
    );
  }

  /// Creates a more options menu for the app bar with the provided items
  static PopupMenuButton<String> createMoreOptionsMenu({
    required Map<String, IconData> items,
    required Function(String) onSelected,
  }) {
    return PopupMenuButton<String>(
      onSelected: onSelected,
      itemBuilder: (context) {
        return items.entries.map((entry) {
          return PopupMenuItem<String>(
            value: entry.key,
            child: Row(
              children: [
                Icon(entry.value, size: 20),
                const SizedBox(width: 8),
                Text(entry.key),
              ],
            ),
          );
        }).toList();
      },
    );
  }

  /// Creates a title with breadcrumb navigation for folder hierarchy
  static Widget createBreadcrumbTitle(
    BuildContext context,
    List<String> pathSegments,
    Function(int) onSegmentTap,
  ) {
    if (pathSegments.isEmpty) {
      return const Text('Home');
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (int i = 0; i < pathSegments.length; i++) ...[
            if (i > 0) const Text(' / ', style: TextStyle(fontSize: 16)),
            InkWell(
              onTap: () => onSegmentTap(i),
              child: Text(
                pathSegments[i],
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Creates a selection mode app bar for multi-select operations
  static AppBar createSelectionModeAppBar({
    required BuildContext context,
    required int selectedCount,
    required VoidCallback onClose,
    required List<Widget> actions,
  }) {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: onClose,
      ),
      title: Text('$selectedCount selected'),
      actions: actions,
      backgroundColor: Colors.blueGrey,
    );
  }
}
