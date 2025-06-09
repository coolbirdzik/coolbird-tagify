import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/foundation.dart';

import '../../services/network_browsing/network_service_base.dart';
import '../../services/network_browsing/network_service_registry.dart';
import 'network_browsing_event.dart';
import 'network_browsing_state.dart';

/// BLoC for managing network browsing state
class NetworkBrowsingBloc
    extends Bloc<NetworkBrowsingEvent, NetworkBrowsingState> {
  final NetworkServiceRegistry _registry = NetworkServiceRegistry();

  // Track last requested path to prevent duplicate requests
  String? _lastRequestedPath;
  bool _isProcessingDirectoryRequest = false;

  NetworkBrowsingBloc() : super(const NetworkBrowsingState.initial()) {
    on<NetworkServicesListRequested>(_onServicesListRequested);
    on<NetworkConnectionRequested>(_onConnectionRequested);
    on<NetworkDisconnectRequested>(_onDisconnectRequested);
    on<NetworkDirectoryRequested>(_onDirectoryRequested);
    on<NetworkClearLastConnectedPath>(_onClearLastConnectedPath);
    on<NetworkDirectoryLoaded>(_onDirectoryLoaded);
  }

  void _onServicesListRequested(
      NetworkServicesListRequested event, Emitter<NetworkBrowsingState> emit) {
    emit(state.copyWith(isLoading: true));

    final services = _registry.availableServices;

    emit(state.copyWith(
      isLoading: false,
      services: services,
      clearServices: false,
    ));
  }

  Future<void> _onConnectionRequested(NetworkConnectionRequested event,
      Emitter<NetworkBrowsingState> emit) async {
    emit(state.copyWith(
        isConnecting: true,
        clearLastSuccessfullyConnectedPath: true,
        clearErrorMessage: true));

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
          emit(state.copyWith(
            isConnecting: false,
            errorMessage:
                'Service ${event.serviceName} not found after connection.',
            clearLastSuccessfullyConnectedPath: true,
          ));
          return;
        }

        Map<String, NetworkServiceBase> updatedConnections =
            Map<String, NetworkServiceBase>.from(state.connections);
        updatedConnections[result.connectedPath!] = service;

        emit(state.copyWith(
          isConnecting: false,
          connections: updatedConnections,
          lastSuccessfullyConnectedPath: result.connectedPath,
          clearErrorMessage: true,
        ));
      } else {
        emit(state.copyWith(
          isConnecting: false,
          errorMessage:
              result.errorMessage ?? 'Unknown error connecting to service',
          clearLastSuccessfullyConnectedPath: true,
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        isConnecting: false,
        errorMessage: 'Error connecting to service: $e',
        clearLastSuccessfullyConnectedPath: true,
      ));
    }
  }

  Future<void> _onDirectoryRequested(NetworkDirectoryRequested event,
      Emitter<NetworkBrowsingState> emit) async {
    // Check for duplicate requests for the same path
    if (event.path == _lastRequestedPath && _isProcessingDirectoryRequest) {
      debugPrint(
          "NetworkBrowsingBloc: Skipping duplicate directory request for ${event.path}");
      return;
    }

    // Set request tracking variables
    _lastRequestedPath = event.path;
    _isProcessingDirectoryRequest = true;

    final String? previousPath = state.currentPath;
    final NetworkServiceBase? previousService = state.currentService;

    // Additional debugging for the current state
    debugPrint("NetworkBrowsingBloc: Current state BEFORE request:");
    debugPrint("  - currentPath: ${state.currentPath}");
    debugPrint("  - directories: ${state.directories?.length ?? 0}");
    debugPrint("  - files: ${state.files?.length ?? 0}");

    // First, emit a loading state to show progress
    emit(state.copyWith(isLoading: true, currentPath: event.path));

    // Log once at the start of the request
    debugPrint("NetworkBrowsingBloc: Requesting directory: ${event.path}");

    try {
      final service = _registry.getServiceForPath(event.path);

      if (service == null) {
        debugPrint(
            "NetworkBrowsingBloc: No service found for path: ${event.path}");
        emit(state.copyWith(
          isLoading: false,
          errorMessage: 'No connected service found for path: ${event.path}',
          currentPath: previousPath,
          currentService: previousService,
        ));
        _isProcessingDirectoryRequest = false;
        return;
      }

      try {
        // Log the service type we're using
        debugPrint(
            "NetworkBrowsingBloc: Using service type: ${service.serviceName}");

        // Get directory contents
        final contents = await service.listDirectory(event.path);

        // Log raw contents for debugging
        debugPrint(
            "NetworkBrowsingBloc: Raw contents received (${contents.length} items):");
        for (var item in contents) {
          debugPrint("  - ${item.runtimeType}: ${item.path}");
        }

        // Filter out empty or null entries that might be causing issues
        final validContents = contents
            .where((item) =>
                item != null && item.path != null && item.path.isNotEmpty)
            .toList();

        debugPrint(
            "NetworkBrowsingBloc: Valid contents after filtering: ${validContents.length} items");

        // Force cast to correct types - this is important for the UI to recognize the types
        final List<Directory> directories = [];
        final List<File> files = [];

        // Instead of blindly casting, ensure we create proper Directory and File objects
        for (var item in validContents) {
          debugPrint("Processing item: ${item.runtimeType} - ${item.path}");

          if (item is Directory) {
            directories.add(item);
            debugPrint("Added existing Directory: ${item.path}");
          } else if (item is File) {
            files.add(item);
            debugPrint("Added existing File: ${item.path}");
          } else {
            // For other types, create a proper Directory or File based on some criteria
            // For example, path ending with / might be directory
            if (item.path.endsWith('/') || item.path.endsWith('\\')) {
              final dir = Directory(item.path);
              directories.add(dir);
              debugPrint("Created new Directory from path: ${item.path}");
            } else {
              final file = File(item.path);
              files.add(file);
              debugPrint("Created new File from path: ${item.path}");
            }
          }
        }

        // Log success with count and content details
        debugPrint(
            "NetworkBrowsingBloc: Listed ${directories.length} directories and ${files.length} files");

        // Log all directories and files for debugging
        debugPrint("NetworkBrowsingBloc: Directories:");
        for (var dir in directories) {
          debugPrint("  - Directory: ${dir.path}");
        }

        debugPrint("NetworkBrowsingBloc: Files:");
        for (var file in files) {
          debugPrint("  - File: ${file.path}");
        }

        // Verify that directories and files are non-null before emitting
        debugPrint(
            "NetworkBrowsingBloc: About to emit state update with directories: ${directories.length}, files: ${files.length}");

        // If we have no content but no error, set a warning message
        if (directories.isEmpty && files.isEmpty) {
          debugPrint(
              "NetworkBrowsingBloc: Directory is empty or path might be invalid");
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
        debugPrint("NetworkBrowsingBloc: State emitted successfully.");
        debugPrint(
            "NetworkBrowsingBloc: New state has directories: ${newState.directories?.length ?? 0}, files: ${newState.files?.length ?? 0}");

        // Extra verification to make sure state was properly updated
        debugPrint(
            "NetworkBrowsingBloc: After emit - current state: directories=${state.directories?.length ?? 0}, files=${state.files?.length ?? 0}");
      } catch (e) {
        debugPrint(
            "NetworkBrowsingBloc: Error listing directory ${event.path}: $e");
        emit(state.copyWith(
          isLoading: false,
          errorMessage: 'Error listing directory: $e',
          currentPath: previousPath,
          currentService: previousService,
        ));
      }
    } catch (e) {
      debugPrint("NetworkBrowsingBloc: Error: $e");
      emit(state.copyWith(
        isLoading: false,
        errorMessage: 'Error: $e',
        currentPath: previousPath,
        currentService: previousService,
      ));
    }

    _isProcessingDirectoryRequest = false;
  }

  Future<void> _onDisconnectRequested(NetworkDisconnectRequested event,
      Emitter<NetworkBrowsingState> emit) async {
    final servicePath = event.path;

    debugPrint("NetworkBrowsingBloc: Disconnecting from path: $servicePath");
    debugPrint(
        "NetworkBrowsingBloc: Current connections: ${state.connections.keys.join(', ')}");

    if (servicePath == null || !servicePath.startsWith('#network/')) {
      emit(state.copyWith(
        errorMessage: 'Invalid network path',
      ));
      return;
    }

    try {
      // Lấy đường dẫn gốc để đóng kết nối vật lý
      await _registry.disconnect(servicePath);

      // Xóa kết nối khỏi danh sách
      final Map<String, NetworkServiceBase> updatedConnections = {
        ...state.connections
      };

      // Xóa chính xác tab path khỏi danh sách
      final NetworkServiceBase? service =
          updatedConnections.remove(servicePath);

      debugPrint(
          "NetworkBrowsingBloc: Removed connection: $servicePath, service: ${service?.serviceName}");
      debugPrint(
          "NetworkBrowsingBloc: Updated connections: ${updatedConnections.keys.join(', ')}");

      // Nếu ngắt kết nối dịch vụ hiện tại, reset về danh sách dịch vụ
      if (state.currentService != null &&
          state.currentPath != null &&
          state.currentPath!.startsWith(servicePath)) {
        emit(NetworkBrowsingState.disconnected(
          connections: updatedConnections,
          lastSuccessfullyConnectedPath: state.lastSuccessfullyConnectedPath,
          services: state.services,
        ));
      } else {
        // Otherwise just update the connections map
        emit(state.copyWith(
          connections: updatedConnections,
        ));
      }
    } catch (e) {
      debugPrint("NetworkBrowsingBloc: Error disconnecting: $e");
      emit(state.copyWith(
        errorMessage: 'Error disconnecting: $e',
      ));
    }
  }

  void _onClearLastConnectedPath(
      NetworkClearLastConnectedPath event, Emitter<NetworkBrowsingState> emit) {
    emit(state.copyWith(clearLastSuccessfullyConnectedPath: true));
  }

  // Handler for the NetworkDirectoryLoaded event
  void _onDirectoryLoaded(
      NetworkDirectoryLoaded event, Emitter<NetworkBrowsingState> emit) {
    debugPrint("NetworkBrowsingBloc: Processing NetworkDirectoryLoaded event");
    debugPrint("NetworkBrowsingBloc: Path: ${event.path}");
    debugPrint("NetworkBrowsingBloc: Directories: ${event.directories.length}");
    debugPrint("NetworkBrowsingBloc: Files: ${event.files.length}");

    // We simply update the state with the provided directories and files
    emit(state.copyWith(
      isLoading: false,
      currentPath: event.path,
      directories: event.directories,
      files: event.files,
      clearErrorMessage: true,
      clearDirectories: false,
      clearFiles: false,
    ));
  }
}
