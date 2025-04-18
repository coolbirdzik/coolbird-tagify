import 'package:flutter/material.dart';
import 'package:cb_file_manager/main.dart' show goHome;
import 'package:cb_file_manager/ui/drawer.dart';
import 'package:cb_file_manager/ui/utils/route.dart';
import 'package:cb_file_manager/helpers/user_preferences.dart'; // Add UserPreferences import
import 'package:cb_file_manager/config/translation_helper.dart'; // Import translation helper
import 'dart:io'; // For Platform check

/// A base screen widget that handles common functionality across all screens
/// including drawer, back button, and home button navigation.
class BaseScreen extends StatefulWidget {
  final String title;
  final Widget body;
  final List<Widget>? actions;
  final FloatingActionButton? floatingActionButton;
  final Widget? bottomNavigationBar;
  final bool automaticallyImplyLeading;
  final Color? backgroundColor;
  final bool resizeToAvoidBottomInset;

  /// Static key for accessing drawer from anywhere - for backward compatibility only
  /// THIS SHOULD NOT BE USED IN NEW CODE - it's only here for legacy support
  static final GlobalKey<ScaffoldState> scaffoldKey =
      GlobalKey<ScaffoldState>(debugLabel: 'legacyGlobalScaffoldKey');

  /// Static reference to the most recently active BaseScreen state
  /// This is used for backward compatibility
  static _BaseScreenState? _mostRecentState;

  /// Function to open the drawer from anywhere in the app
  static void openDrawer() {
    // Try to use the most recent state first
    if (_mostRecentState != null && _mostRecentState!.mounted) {
      _mostRecentState!._scaffoldKey.currentState?.openDrawer();
      return;
    }

    // Fall back to the legacy key if no recent state available
    scaffoldKey.currentState?.openDrawer();
  }

  const BaseScreen({
    Key? key,
    required this.title,
    required this.body,
    this.actions,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.automaticallyImplyLeading = true,
    this.backgroundColor,
    this.resizeToAvoidBottomInset = true,
  }) : super(key: key);

  @override
  State<BaseScreen> createState() => _BaseScreenState();
}

class _BaseScreenState extends State<BaseScreen> {
  // Instance-specific scaffold key
  final GlobalKey<ScaffoldState> _scaffoldKey =
      GlobalKey<ScaffoldState>(debugLabel: 'instanceScaffoldKey');

  // Drawer state variables
  bool _isDrawerPinned = false;

  @override
  void initState() {
    super.initState();
    // Register as the most recent state
    BaseScreen._mostRecentState = this;
    // Load drawer preferences
    _loadDrawerPreferences();
  }

  // Load drawer preferences from storage
  Future<void> _loadDrawerPreferences() async {
    try {
      final UserPreferences prefs = UserPreferences();
      await prefs.init();

      setState(() {
        // Only set drawer to pinned if not on a small screen
        final bool isSmallScreen = MediaQuery.of(context).size.width < 600;
        _isDrawerPinned = isSmallScreen ? false : prefs.getDrawerPinned();
      });
    } catch (e) {
      print('Error loading drawer preferences: $e');
    }
  }

  // Save drawer pinned state
  Future<void> _saveDrawerPinned(bool isPinned) async {
    try {
      final UserPreferences prefs = UserPreferences();
      await prefs.init();
      await prefs.setDrawerPinned(isPinned);
    } catch (e) {
      print('Error saving drawer pinned state: $e');
    }
  }

  // Toggle drawer pin state
  void _toggleDrawerPin() {
    // Check if we're on a small screen
    final bool isSmallScreen = MediaQuery.of(context).size.width < 600;

    setState(() {
      // Only allow pinning on larger screens
      if (!isSmallScreen) {
        _isDrawerPinned = !_isDrawerPinned;
        _saveDrawerPinned(_isDrawerPinned);
      } else {
        // Force unpinned on small screens and show a message
        _isDrawerPinned = false;
        _saveDrawerPinned(false);

        // Show a message explaining why pinning isn't available
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Menu pinning is only available on larger screens'),
              duration: Duration(seconds: 2),
            ),
          );
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _handleBackNavigation(context);
        }
      },
      child: Scaffold(
        key: _scaffoldKey, // Use instance-specific key
        appBar: AppBar(
          title: Text(widget.title),
          leading: widget.automaticallyImplyLeading
              ? _buildLeadingIcon(context)
              : null,
          actions: <Widget>[
            // Always add the menu button as the first action
            IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            ),

            // Home button for emergency navigation
            IconButton(
              icon: const Icon(Icons.home),
              tooltip: context.tr.home,
              onPressed: () => goHome(context),
            ),

            // Add any additional actions
            if (widget.actions != null) ...widget.actions!,
          ],
        ),
        drawer: CBDrawer(
          context,
          isPinned: _isDrawerPinned,
          onPinStateChanged: (isPinned) {
            _toggleDrawerPin();
          },
        ),
        body: widget.body,
        backgroundColor: widget.backgroundColor,
        floatingActionButton: widget.floatingActionButton,
        bottomNavigationBar: widget.bottomNavigationBar,
        resizeToAvoidBottomInset: widget.resizeToAvoidBottomInset,
      ),
    );
  }

  /// Build the leading icon based on the navigation state
  Widget _buildLeadingIcon(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => _handleBackNavigation(context),
    );
  }

  /// Handle back button navigation safely
  void _handleBackNavigation(BuildContext context) {
    // Check if we can pop before attempting to
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      // If we can't pop, go to home screen
      goHome(context);
    }
  }
}
