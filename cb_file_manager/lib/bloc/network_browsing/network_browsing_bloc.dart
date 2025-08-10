import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/foundation.dart';

import '../../services/network_browsing/network_service_base.dart';
import '../../services/network_browsing/network_service_registry.dart';
import '../../helpers/network_thumbnail_helper.dart';
import '../../ui/widgets/thumbnail_loader.dart';
import 'network_browsing_event.dart';
import 'network_browsing_state.dart';

/// BLoC for managing network browsing state
class NetworkBrowsingBloc
    extends Bloc<NetworkBrowsingEvent, NetworkBrowsingState> {
  final NetworkServiceRegistry _registry = NetworkServiceRegistry();

  // Track last requested path to prevent duplicate requests
  String? _lastRequestedPath;
  bool _isProcessingDirectoryRequest = false;

  // Toggle this to true if you need verbose BLoC logs for debugging.
  static const bool _enableBlocVerboseLogs = false;

  void _log(String message) {
    if (_enableBlocVerboseLogs) {
      debugPrint(message);
    }
  }

  NetworkBrowsingBloc() : super(const NetworkBrowsingState.initial()) {
    on<NetworkServicesListRequested>(_onServicesListRequested);
    on<NetworkConnectionRequested>(_onConnectionRequested);
    on<NetworkDisconnectRequested>(_onDisconnectRequested);
    on<NetworkDirectoryRequested>(_onDirectoryRequested);
    on<NetworkClearLastConnectedPath>(_onClearLastConnectedPath);
    on<NetworkDirectoryLoaded>(_onDirectoryLoaded);
  }

  void _onServicesListRequested(
    NetworkServicesListRequested event,
    Emitter<NetworkBrowsingState> emit,
  ) {
    emit(state.copyWith(isLoading: true));

    final services = _registry.availableServices;

    emit(
      state.copyWith(
        isLoading: false,
        services: services,
        clearServices: false,
      ),
    );
  }

  Future<void> _onConnectionRequested(
    NetworkConnectionRequested event,
    Emitter<NetworkBrowsingState> emit,
  ) async {
    emit(
      state.copyWith(
        isConnecting: true,
        clearLastSuccessfullyConnectedPath: true,
        clearErrorMessage: true,
      ),
    );

    try {
      final result = await _registry.connect(
        serviceName: event.serviceName,
        host: event.host,
        username: event.username,
        password: event.password,
        port: event.port,
        additionalOptions: event.additionalOptions,
      );

      if (result.success && result.connectedPath != null) {
        final service = _registry.getServiceByName(event.serviceName);
        if (service == null) {
          emit(
            state.copyWith(
              isConnecting: false,
              errorMessage:
                  'Service ${event.serviceName} not found after connection.',
              clearLastSuccessfullyConnectedPath: true,
            ),
          );
          return;
        }

        Map<String, NetworkServiceBase> updatedConnections =
            Map<String, NetworkServiceBase>.from(state.connections);
        updatedConnections[result.connectedPath!] = service;

        emit(
          state.copyWith(
            isConnecting: false,
            connections: updatedConnections,
            lastSuccessfullyConnectedPath: result.connectedPath,
            clearErrorMessage: true,
          ),
        );

        // Reset failed attempts when successfully connected
        NetworkThumbnailHelper.resetFailedAttempts();
        ThumbnailLoader.resetFailedAttempts();
      } else {
        emit(
          state.copyWith(
            isConnecting: false,
            errorMessage:
                result.errorMessage ?? 'Unknown error connecting to service',
            clearLastSuccessfullyConnectedPath: true,
          ),
        );
      }
    } catch (e) {
      emit(
        state.copyWith(
          isConnecting: false,
          errorMessage: 'Error connecting to service: $e',
          clearLastSuccessfullyConnectedPath: true,
        ),
      );
    }
  }

  Future<void> _onDirectoryRequested(
    NetworkDirectoryRequested event,
    Emitter<NetworkBrowsingState> emit,
  ) async {
    // Check for duplicate requests for the same path
    if (event.path == _lastRequestedPath && _isProcessingDirectoryRequest) {
      _log(
        "NetworkBrowsingBloc: Skipping duplicate directory request for ${event.path}",
      );
      return;
    }

    // Set request tracking variables
    _lastRequestedPath = event.path;
    _isProcessingDirectoryRequest = true;

    final String? previousPath = state.currentPath;
    final NetworkServiceBase? previousService = state.currentService;

    // Additional debugging for the current state
    _log("NetworkBrowsingBloc: Current state BEFORE request:");
    _log("  - currentPath: ${state.currentPath}");
    _log("  - directories: ${state.directories?.length ?? 0}");
    _log("  - files: ${state.files?.length ?? 0}");

    // First, emit a loading state to show progress
    emit(state.copyWith(isLoading: true, currentPath: event.path));

    // Log once at the start of the request
    _log("NetworkBrowsingBloc: Requesting directory: ${event.path}");

    try {
      final service = _registry.getServiceForPath(event.path);

      if (service == null) {
        _log("NetworkBrowsingBloc: No service found for path: ${event.path}");
        emit(
          state.copyWith(
            isLoading: false,
            errorMessage: 'No connected service found for path: ${event.path}',
            currentPath: previousPath,
            currentService: previousService,
          ),
        );
        _isProcessingDirectoryRequest = false;
        return;
      }

      try {
        // Log the service type we're using
        _log("NetworkBrowsingBloc: Using service type: ${service.serviceName}");

        // Get directory contents
        final contents = await service.listDirectory(event.path);

        // Log raw contents for debugging
        _log(
          "NetworkBrowsingBloc: Raw contents received (${contents.length} items):",
        );
        for (var item in contents) {
          _log("  - ${item.runtimeType}: ${item.path}");
        }

        // Filter out empty or null entries that might be causing issues
        final validContents = contents
            .where(
              (item) =>
                  item != null && item.path != null && item.path.isNotEmpty,
            )
            .toList();

        _log(
          "NetworkBrowsingBloc: Valid contents after filtering: ${validContents.length} items",
        );

        // Force cast to correct types - this is important for the UI to recognize the types
        final List<Directory> directories = [];
        final List<File> files = [];

        // Instead of blindly casting, ensure we create proper Directory and File objects
        for (var item in validContents) {
          // _log("Processing item: ${item.runtimeType} - ${item.path}");

          if (item is Directory) {
            directories.add(item);
            _log("Added existing Directory: ${item.path}");
          } else if (item is File) {
            files.add(item);
            _log("Added existing File: ${item.path}");
          } else {
            // For other types, create a proper Directory or File based on some criteria
            // For example, path ending with / might be directory
            if (item.path.endsWith('/') || item.path.endsWith('\\')) {
              final dir = Directory(item.path);
              directories.add(dir);
              _log("Created new Directory from path: ${item.path}");
            } else {
              final file = File(item.path);
              files.add(file);
              _log("Created new File from path: ${item.path}");
            }
          }
        }

        // Log success with count and content details
        _log(
          "NetworkBrowsingBloc: Listed ${directories.length} directories and ${files.length} files",
        );

        // Log all directories and files for debugging
        _log("NetworkBrowsingBloc: Directories:");
        for (var dir in directories) {
          _log("  - Directory: ${dir.path}");
        }
        // Verify that directories and files are non-null before emitting
        _log(
          "NetworkBrowsingBloc: About to emit state update with directories: ${directories.length}, files: ${files.length}",
        );

        // If we have no content but no error, set a warning message
        if (directories.isEmpty && files.isEmpty) {
          _log(
            "NetworkBrowsingBloc: Directory is empty or path might be invalid",
          );
        }

        // Create a fresh state with directoryLoaded constructor for clarity
        final newState = NetworkBrowsingState.directoryLoaded(
          currentService: service,
          currentPath: event.path,
          directories: directories,
          files: files,
          connections: state.connections,
          lastSuccessfullyConnectedPath: state.lastSuccessfullyConnectedPath,
        );

        emit(newState);

        // Log the state after emission to confirm
        _log("NetworkBrowsingBloc: State emitted successfully.");
        _log(
          "NetworkBrowsingBloc: New state has directories: ${newState.directories?.length ?? 0}, files: ${newState.files?.length ?? 0}",
        );

        // Extra verification to make sure state was properly updated
        _log(
          "NetworkBrowsingBloc: After emit - current state: directories=${state.directories?.length ?? 0}, files=${state.files?.length ?? 0}",
        );
      } catch (e) {
        _log("NetworkBrowsingBloc: Error listing directory ${event.path}: $e");
        emit(
          state.copyWith(
            isLoading: false,
            errorMessage: 'Error listing directory: $e',
            currentPath: previousPath,
            currentService: previousService,
          ),
        );
      }
    } catch (e) {
      _log("NetworkBrowsingBloc: Error: $e");
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: 'Error: $e',
          currentPath: previousPath,
          currentService: previousService,
        ),
      );
    }

    _isProcessingDirectoryRequest = false;
  }

  Future<void> _onDisconnectRequested(
    NetworkDisconnectRequested event,
    Emitter<NetworkBrowsingState> emit,
  ) async {
    final servicePath = event.path;

    _log("NetworkBrowsingBloc: Disconnecting from path: $servicePath");
    _log(
      "NetworkBrowsingBloc: Current connections: ${state.connections.keys.join(', ')}",
    );

    if (servicePath == null || !servicePath.startsWith('#network/')) {
      emit(state.copyWith(errorMessage: 'Invalid network path'));
      return;
    }

    try {
      // Lấy đường dẫn gốc để đóng kết nối vật lý
      await _registry.disconnect(servicePath);

      // Xóa kết nối khỏi danh sách
      final Map<String, NetworkServiceBase> updatedConnections = {
        ...state.connections,
      };

      // Xóa chính xác tab path khỏi danh sách
      final NetworkServiceBase? service = updatedConnections.remove(
        servicePath,
      );

      _log(
        "NetworkBrowsingBloc: Removed connection: $servicePath, service: ${service?.serviceName}",
      );
      _log(
        "NetworkBrowsingBloc: Updated connections: ${updatedConnections.keys.join(', ')}",
      );

      // Nếu ngắt kết nối dịch vụ hiện tại, reset về danh sách dịch vụ
      if (state.currentService != null &&
          state.currentPath != null &&
          state.currentPath!.startsWith(servicePath)) {
        emit(
          NetworkBrowsingState.disconnected(
            connections: updatedConnections,
            lastSuccessfullyConnectedPath: state.lastSuccessfullyConnectedPath,
            services: state.services,
          ),
        );
      } else {
        // Otherwise just update the connections map
        emit(state.copyWith(connections: updatedConnections));
      }
    } catch (e) {
      _log("NetworkBrowsingBloc: Error disconnecting: $e");
      emit(state.copyWith(errorMessage: 'Error disconnecting: $e'));
    }
  }

  void _onClearLastConnectedPath(
    NetworkClearLastConnectedPath event,
    Emitter<NetworkBrowsingState> emit,
  ) {
    emit(state.copyWith(clearLastSuccessfullyConnectedPath: true));
  }

  // Handler for the NetworkDirectoryLoaded event
  void _onDirectoryLoaded(
    NetworkDirectoryLoaded event,
    Emitter<NetworkBrowsingState> emit,
  ) {
    _log("NetworkBrowsingBloc: Processing NetworkDirectoryLoaded event");
    _log("NetworkBrowsingBloc: Path: ${event.path}");
    _log("NetworkBrowsingBloc: Directories: ${event.directories.length}");
    _log("NetworkBrowsingBloc: Files: ${event.files.length}");

    // We simply update the state with the provided directories and files
    emit(
      state.copyWith(
        isLoading: false,
        currentPath: event.path,
        directories: event.directories,
        files: event.files,
        clearErrorMessage: true,
        clearDirectories: false,
        clearFiles: false,
      ),
    );
  }
}
