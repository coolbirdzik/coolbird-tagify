import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Thêm import này cho SystemUiOverlayStyle
import 'dart:async';
import 'dart:io';
import 'ui/home.dart';
import 'ui/tab_manager/tab_main_screen.dart';
import 'package:permission_handler/permission_handler.dart';
import 'helpers/tag_manager.dart';
import 'package:media_kit/media_kit.dart'; // Import Media Kit
import 'package:window_manager/window_manager.dart'; // Import window_manager
import 'helpers/media_kit_audio_helper.dart'; // Import our audio helper
import 'helpers/user_preferences.dart'; // Import user preferences
import 'config/app_theme.dart'; // Import global theme configuration
import 'package:flutter_localizations/flutter_localizations.dart'; // Import for localization
import 'config/language_controller.dart'; // Import our language controller
import 'config/languages/app_localizations_delegate.dart'; // Import our localization delegate

// Global key for app state access
final GlobalKey<MyHomePageState> homeKey = GlobalKey<MyHomePageState>();

void main() async {
  // Catch any errors during app initialization
  runZonedGuarded(() async {
    // Ensure Flutter is initialized before using platform plugins
    WidgetsFlutterBinding.ensureInitialized();

    // Initialize Media Kit with proper audio configuration
    MediaKit.ensureInitialized();

    // Initialize our audio helper to ensure sound works
    if (Platform.isWindows) {
      debugPrint('Setting up Windows-specific audio configuration');
      await MediaKitAudioHelper.initialize();
    }

    // Initialize window_manager if on desktop platform
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      await windowManager.ensureInitialized();

      // Create window options with minimum size but still allow maximized state
      WindowOptions windowOptions = const WindowOptions(
        center: true,
        backgroundColor: Colors.transparent,
        titleBarStyle: TitleBarStyle.normal,
        windowButtonVisibility: true,
        // Set minimum size but allow window to be resized
        minimumSize: Size(800, 600),
      );

      // Apply the window options
      await windowManager.waitUntilReadyToShow(windowOptions);

      // For Windows, start maximized but allow toggling
      if (Platform.isWindows) {
        // Enable resizing so the window can be un-maximized
        await windowManager.setResizable(true);

        // Ensure the window is shown first
        await windowManager.show();

        // Start maximized initially
        await windowManager.maximize();

        // Configure additional window properties
        await windowManager.setPreventClose(false);
        await windowManager.setSkipTaskbar(false);

        // Focus the window
        await windowManager.focus();
      }
    }

    // Request storage permissions at startup
    await _requestPermissions();

    // Initialize the global tag system
    await TagManager.initialize();

    // Initialize user preferences
    final preferences = UserPreferences();
    await preferences.init();

    // Initialize language controller
    await LanguageController().initialize();

    runApp(const CBFileApp());
  }, (error, stackTrace) {
    print('Error during app initialization: $error');
    print(stackTrace);
  });
}

// Navigate directly to home screen - updated to use the tabbed interface
void goHome(BuildContext context) {
  try {
    // Check if the context is mounted before navigating
    if (!context.mounted) {
      print('Context not mounted, cannot navigate');
      return;
    }

    // Most reliable way to navigate home - create a fresh route with TabMainScreen
    final route = MaterialPageRoute(
      builder: (_) => const TabMainScreen(),
    );

    // Replace entire navigation stack with home
    Navigator.of(context, rootNavigator: true)
        .pushAndRemoveUntil(route, (r) => false);
  } catch (e) {
    print('Error navigating home: $e');
    // Last resort fallback
    runApp(const CBFileApp());
  }
}

Future<void> _requestPermissions() async {
  // Request storage permissions
  var storageStatus = await Permission.storage.request();

  // For Android 11+, try to request manage external storage permission
  if (Platform.isAndroid) {
    try {
      await Permission.manageExternalStorage.request();
    } catch (e) {
      print('Manage external storage permission not available: $e');
    }
  }

  print('Storage permission status: $storageStatus');
}

class CBFileApp extends StatefulWidget {
  const CBFileApp({Key? key}) : super(key: key);

  @override
  State<CBFileApp> createState() => _CBFileAppState();
}

class _CBFileAppState extends State<CBFileApp> with WidgetsBindingObserver {
  final UserPreferences _preferences = UserPreferences();
  // Change from late initialization to default value
  ThemeMode _themeMode = ThemeMode.system;
  StreamSubscription<ThemeMode>? _themeSubscription;

  // Language controller for handling language changes
  final LanguageController _languageController = LanguageController();
  ValueNotifier<Locale>? _localeNotifier;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadThemePreference();

    // Initialize locale notifier
    _localeNotifier = _languageController.languageNotifier;
    _localeNotifier?.addListener(() {
      setState(() {});
    });

    // Listen for theme changes
    _themeSubscription =
        _preferences.themeChangeStream.listen((ThemeMode newThemeMode) {
      setState(() {
        _themeMode = newThemeMode;
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _themeSubscription?.cancel();
    _localeNotifier?.removeListener(() {});
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh theme when app is resumed (in case system theme changed)
      _loadThemePreference();
    }
    super.didChangeAppLifecycleState(state);
  }

  Future<void> _loadThemePreference() async {
    await _preferences.init();
    setState(() {
      _themeMode = _preferences.getThemeMode();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CoolBird - File Manager',
      // Use our TabMainScreen as the default entry point
      home: const TabMainScreen(),
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _themeMode,
      debugShowCheckedModeBanner: false,

      // Add localization support
      locale: _languageController.currentLocale,
      localizationsDelegates: const [
        AppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('vi', ''), // Vietnamese
        Locale('en', ''), // English
      ],
    );
  }
}
