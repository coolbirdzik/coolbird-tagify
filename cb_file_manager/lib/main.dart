import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart'; // For SystemUiOverlayStyle
import 'package:flutter/foundation.dart'; // For kDebugMode
import 'package:flutter/scheduler.dart'; // For frame scheduling
import 'dart:async';
import 'dart:io';
import 'package:provider/provider.dart';

import 'ui/tab_manager/core/tab_main_screen.dart';
import 'helpers/tags/tag_manager.dart';
import 'package:media_kit/media_kit.dart'; // Import Media Kit
// Ensure Windows video native libraries (mpv) are bundled.
// This import is a no-op at runtime but required at build time.
// Note: If media_kit_libs_windows_video is available in your environment,
// you can import it here to bundle mpv DLLs. We avoid importing it directly
// to prevent build failures when the package isn't present locally.
import 'package:window_manager/window_manager.dart'; // Import window_manager
import 'ui/components/video/pip_window/desktop_pip_window.dart';
import 'helpers/media/media_kit_audio_helper.dart'; // Import our audio helper
import 'helpers/core/user_preferences.dart'; // Import user preferences
import 'helpers/media/folder_thumbnail_service.dart'; // Import thumbnail service
import 'helpers/media/video_thumbnail_helper.dart'; // Import our video thumbnail helper
import 'helpers/ui/frame_timing_optimizer.dart'; // Import our new frame timing optimizer
import 'helpers/tags/batch_tag_manager.dart'; // Import batch tag manager
import 'models/database/database_manager.dart'; // Import database manager
import 'services/network_credentials_service.dart'; // Import network credentials service
import 'providers/theme_provider.dart'; // Import theme provider
import 'config/theme_config.dart'; // Import theme config
import 'package:flutter_localizations/flutter_localizations.dart'; // Import for localization
import 'config/language_controller.dart'; // Import our language controller
import 'config/languages/app_localizations_delegate.dart'; // Import our localization delegate
import 'services/streaming_service_manager.dart'; // Import streaming service manager
import 'ui/utils/safe_navigation_wrapper.dart'; // Import safe navigation wrapper
import 'core/service_locator.dart'; // Import service locator
import 'package:cb_file_manager/services/album_service.dart'; // Import AlbumService
import 'package:cb_file_manager/ui/screens/media_gallery/video_player_full_screen.dart';
import 'package:cb_file_manager/ui/utils/file_type_utils.dart';
import 'package:cb_file_manager/helpers/files/external_app_helper.dart';
import 'services/windowing/window_startup_payload.dart';
import 'services/windowing/windows_native_tab_drag_drop_service.dart';
// Permission explainer is pushed from TabMainScreen; no direct import needed here

// Global access to test the video thumbnail screen (for development)
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

const List<String> _debugLogAllowList = <String>['VideoPlayer', 'VLC'];

/// Launch file path from OS (e.g. double-click when app is default for video)
List<String> _launchPaths = [];

void _handleLaunchFiles() {
  if (_launchPaths.isEmpty) return;
  final p = _launchPaths.removeAt(0);
  if (p.isEmpty) return;
  try {
    final f = File(p);
    if (f.existsSync() && FileTypeUtils.isVideoFile(p)) {
      navigatorKey.currentState?.push(MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => VideoPlayerFullScreen(file: f),
      ));
    }
  } catch (_) {}
}

/// On Android: open video from launch intent (Open with / default app).
Future<void> _handleAndroidLaunchVideo() async {
  if (!Platform.isAndroid) return;
  try {
    final m = await ExternalAppHelper.getLaunchVideoPath();
    final path = m['path'] ?? '';
    final contentUri = m['contentUri'] ?? '';
    if (path.isEmpty && contentUri.isEmpty) return;
    navigatorKey.currentState?.push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => path.isNotEmpty
          ? VideoPlayerFullScreen(file: File(path))
          : VideoPlayerFullScreen(contentUri: contentUri),
    ));
  } catch (_) {}
}

void _configureDebugPrintFiltering() {
  debugPrint = (String? message, {int? wrapWidth}) {
    if (message == null) return;
    for (final token in _debugLogAllowList) {
      if (message.contains(token)) {
        debugPrintThrottled(message, wrapWidth: wrapWidth);
        return;
      }
    }
  };
}

bool _shouldAllowLog(String message) {
  for (final token in _debugLogAllowList) {
    if (message.contains(token)) {
      return true;
    }
  }
  return false;
}

void main(List<String> args) async {
  _launchPaths = List.from(args);
  // Catch any errors during app initialization
  runZonedGuarded(() async {
    // Ensure Flutter is initialized before using platform plugins
    WidgetsFlutterBinding.ensureInitialized();
    _configureDebugPrintFiltering();
    final env = Platform.environment;
    final isDesktopPlatform =
        Platform.isWindows || Platform.isLinux || Platform.isMacOS;
    final isSecondaryWindow =
        env[WindowStartupPayload.envSecondaryWindowKey] == '1';
    final startHidden = env[WindowStartupPayload.envStartHiddenKey] == '1';
    final windowRole =
        (env[WindowStartupPayload.envWindowRoleKey] ?? 'normal').trim();
    final isPip = env['CB_PIP_MODE'] == '1';
    final List<Future<void> Function()> deferredSecondaryInitializers = [];

    // Native event loop init removed to avoid build issues when package
    // artifacts are not present locally.

    // Note: If you use media_kit_native_event_loop, initialize it here.
    // We avoid importing it directly to prevent build failures when
    // the package isn't available in the environment.

    if (isDesktopPlatform) {
      try {
        await windowManager.ensureInitialized();
      } catch (_) {}

      if (!isPip) {
        // Show desktop windows as soon as possible.
        const windowOptions = WindowOptions(
          center: true,
          backgroundColor: Colors.transparent,
          titleBarStyle: TitleBarStyle.hidden,
          windowButtonVisibility: true,
          minimumSize: Size(800, 600),
        );

        try {
          // For secondary windows, avoid blocking startup on window option
          // application. We'll show/focus immediately and let options settle.
          if (isSecondaryWindow) {
            unawaited(windowManager.waitUntilReadyToShow(windowOptions));
          } else {
            await windowManager.waitUntilReadyToShow(windowOptions);
          }
        } catch (_) {}

        if (Platform.isWindows) {
          if (isSecondaryWindow) {
            if (startHidden || windowRole == 'spare') {
              try {
                await windowManager.setSkipTaskbar(true);
                await windowManager.hide();
              } catch (_) {}
            } else {
              try {
                await windowManager.setSkipTaskbar(false);
                await windowManager.show();
                await windowManager.focus();
                await WindowsNativeTabDragDropService.forceActivateWindow();
                unawaited(windowManager.center());
              } catch (_) {}
            }
          } else {
            try {
              await windowManager.maximize();
              await windowManager.show();
              unawaited(windowManager.focus());
              unawaited(windowManager.setResizable(true));
              unawaited(windowManager.setPreventClose(false));
              unawaited(windowManager.setSkipTaskbar(false));
            } catch (_) {}
          }
        }
      }
    }

    // Configure frame timing and rendering for better performance
    // This helps prevent the "Reported frame time is older than the last one" error
    // Note: Removed incorrect schedulerPhase setter that caused compilation error

    // Initialize frame timing optimizer
    if (isSecondaryWindow && !isPip) {
      deferredSecondaryInitializers.add(() async {
        await FrameTimingOptimizer().initialize();
      });
    } else {
      await FrameTimingOptimizer().initialize();
    }

    // Platform-specific optimizations
    if (isDesktopPlatform) {
      // For desktop platforms, configure Skia resource cache for better image handling
      SystemChannels.skia.invokeMethod<void>(
          'Skia.setResourceCacheMaxBytes', 512 * 1024 * 1024);
    } else if (Platform.isAndroid || Platform.isIOS) {
      // For mobile platforms, show full system UI by default
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
          overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom]);
      // Apply specific settings for better rendering on mobile
      SystemChrome.setSystemUIChangeCallback((systemOverlaysAreVisible) async {
        return;
      });
    }

    // Add a frame callback to help with frame pacing
    SchedulerBinding.instance.addPostFrameCallback((_) {
      FrameTimingOptimizer().optimizeImageRendering();
    });

    // Tối ưu ImageCache để quản lý bộ nhớ tốt hơn khi scroll
    PaintingBinding.instance.imageCache.maximumSize =
        200; // Giới hạn số lượng hình ảnh
    PaintingBinding.instance.imageCache.maximumSizeBytes =
        100 * 1024 * 1024; // Giới hạn ~100MB

    // Initialize Media Kit with proper audio configuration
    if (isSecondaryWindow && !isPip) {
      deferredSecondaryInitializers.add(() async {
        MediaKit.ensureInitialized();
      });
    } else {
      MediaKit.ensureInitialized();
    }

    // Initialize our audio helper to ensure sound works
    if (Platform.isWindows) {
      if (isSecondaryWindow) {
        deferredSecondaryInitializers.add(() async {
          debugPrint(
              'Deferred Windows audio configuration for secondary window');
          await MediaKitAudioHelper.initialize();
        });
      } else {
        debugPrint('Setting up Windows-specific audio configuration');
        await MediaKitAudioHelper.initialize();
      }
    }

    // Initialize streaming service manager
    if (isSecondaryWindow) {
      deferredSecondaryInitializers.add(() async {
        await StreamingServiceManager.initialize();
      });
    } else {
      await StreamingServiceManager.initialize();
    }

    // Do not request permissions at startup; handled via explainer UI on demand

    // Setup dependency injection container
    // This must be done before initializing any services
    await setupServiceLocator();
    debugPrint('Service locator initialized successfully');

    // Initialize preferences first for theme and language.
    if (isSecondaryWindow && !isPip) {
      deferredSecondaryInitializers.add(() async {
        try {
          final preferences = locator<UserPreferences>();
          await preferences.init();
          debugPrint('Deferred user preferences initialization completed');
        } catch (e) {
          debugPrint('Error initializing user preferences: $e');
        }
      });
      deferredSecondaryInitializers.add(() async {
        await locator<LanguageController>().initialize();
      });
    } else {
      try {
        final preferences = locator<UserPreferences>();
        await preferences.init();
        debugPrint('User preferences initialized successfully');
      } catch (e) {
        debugPrint('Error initializing user preferences: $e');
      }

      // Initialize language controller
      await locator<LanguageController>().initialize();
    }

    Future<void> initializeDataAndTags() async {
      try {
        final dbManager = locator<DatabaseManager>();
        if (!dbManager.isInitialized()) {
          await dbManager.initialize();
          debugPrint('Database manager initialized successfully');
        } else {
          debugPrint('Database manager already initialized');
        }
        final store = dbManager.getStore();
        if (store != null) {
          final networkCredService = locator<NetworkCredentialsService>();
          await networkCredService.init(store);
        }

        await BatchTagManager.initialize();
        await TagManager.initialize();
        debugPrint('Data and tag services initialized successfully');
      } catch (e) {
        debugPrint('Error during data/tag initialization: $e');
      }
    }

    Future<void> initializeHeavyBackgroundServices() async {
      try {
        await locator<FolderThumbnailService>().initialize();
      } catch (e) {
        debugPrint('Error initializing folder thumbnail service: $e');
      }

      try {
        debugPrint('Initializing video thumbnail cache system');
        await VideoThumbnailHelper.initializeCache();
        if (kDebugMode) {
          VideoThumbnailHelper.setVerboseLogging(true);
        }
      } catch (e) {
        debugPrint('Error initializing video thumbnail cache: $e');
      }

      try {
        await locator<AlbumService>().initialize();
      } catch (e) {
        debugPrint('Error initializing album service: $e');
      }
    }

    if (isSecondaryWindow) {
      deferredSecondaryInitializers.add(initializeDataAndTags);
      deferredSecondaryInitializers.add(initializeHeavyBackgroundServices);
    } else {
      await initializeDataAndTags();
      await initializeHeavyBackgroundServices();
    }

    // Streaming functionality is now handled directly by StreamingHelper with network services

    // If PiP env flag is set, run ultra‑lightweight PiP window instead of full app
    if (env['CB_PIP_MODE'] == '1' &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      Map<String, dynamic> args = {};
      final raw = env['CB_PIP_ARGS'];
      if (raw != null && raw.isNotEmpty) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is Map<String, dynamic>) args = decoded;
        } catch (_) {}
      }
      // Lightweight shell for PiP window: MaterialApp with dark theme
      runApp(MaterialApp(
        theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: Colors.black),
        debugShowCheckedModeBanner: false,
        home: DesktopPipWindow(args: args),
      ));
      return;
    }

    final startupPayload = WindowStartupPayload.fromEnvironment();
    runApp(
      ChangeNotifierProvider(
        create: (context) => locator<ThemeProvider>(),
        child: CBFileApp(startupPayload: startupPayload),
      ),
    );

    if (isSecondaryWindow && deferredSecondaryInitializers.isNotEmpty) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        for (final initializer in deferredSecondaryInitializers) {
          unawaited(initializer());
        }
      });
    }
  }, (error, stackTrace) {
    debugPrint('Error during app initialization: $error');
  }, zoneSpecification: ZoneSpecification(print: (self, parent, zone, line) {
    if (_shouldAllowLog(line)) {
      parent.print(zone, line);
    }
  }));
}

// no-op helper removed; using jsonDecode directly

// Navigate directly to home screen - updated to use the tabbed interface
void goHome(BuildContext context) {
  try {
    // Check if the context is mounted before navigating
    if (!context.mounted) {
      debugPrint('Context not mounted, cannot navigate');
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
    debugPrint('Error navigating home: $e');
    // Last resort fallback
    runApp(const CBFileApp());
  }
}

class CBFileApp extends StatefulWidget {
  final WindowStartupPayload? startupPayload;
  const CBFileApp({Key? key, this.startupPayload}) : super(key: key);

  @override
  State<CBFileApp> createState() => _CBFileAppState();
}

class _CBFileAppState extends State<CBFileApp> with WidgetsBindingObserver {
  // Language controller for handling language changes
  final LanguageController _languageController = locator<LanguageController>();
  ValueNotifier<Locale>? _localeNotifier;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initialize the frame timing optimizer once the app is loaded
    SchedulerBinding.instance.addPostFrameCallback((_) {
      FrameTimingOptimizer().optimizeBeforeHeavyOperation();
    });

    // If launched with a video file (e.g. set as default on Windows), open it
    if (Platform.isWindows) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _handleLaunchFiles();
      });
    }
    // On Android: open video from intent (Open with / default app)
    if (Platform.isAndroid) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _handleAndroidLaunchVideo();
      });
    }

    // Initialize locale notifier
    _localeNotifier = _languageController.languageNotifier;
    _localeNotifier?.addListener(() {
      setState(() {});
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && Platform.isAndroid) {
      _handleAndroidLaunchVideo();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _localeNotifier?.removeListener(() {});
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeNavigationWrapper(
      child: MaterialApp(
        title: 'CB File Hub',
        // Always start at main; we'll push explainer modally if needed
        home: TabMainScreen(startupPayload: widget.startupPayload),
        navigatorKey: navigatorKey, // Add navigator key for global access
        // Dynamic theming: use selected theme for light, and selected dark theme for dark
        theme:
            context.watch<ThemeProvider>().currentTheme == AppThemeType.dark ||
                    context.watch<ThemeProvider>().currentTheme ==
                        AppThemeType.amoled
                ? ThemeConfig.lightTheme
                : context.watch<ThemeProvider>().themeData,
        darkTheme:
            context.watch<ThemeProvider>().currentTheme == AppThemeType.dark ||
                    context.watch<ThemeProvider>().currentTheme ==
                        AppThemeType.amoled
                ? context.watch<ThemeProvider>().themeData
                : ThemeConfig.darkTheme,
        themeMode: context.watch<ThemeProvider>().themeMode,
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
      ),
    );
  }
}

// Explainer navigation handled inside TabMainScreen on first frame
