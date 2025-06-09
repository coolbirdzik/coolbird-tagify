import 'dart:io';
import 'package:equatable/equatable.dart';
import '../../services/network_browsing/network_service_base.dart';

/// State for the NetworkBrowsingBloc
class NetworkBrowsingState extends Equatable {
  /// Flag to indicate if the state is in a loading condition
  final bool isLoading;

  /// Flag to indicate if we're currently connecting to a service
  final bool isConnecting;

  /// Flag to indicate if we're currently transferring a file
  final bool isTransferring;

  /// Progress of the current transfer (0.0 to 1.0)
  final double? transferProgress;

  /// Available network services
  final List<NetworkServiceBase>? services;

  /// Currently active connections
  final Map<String, NetworkServiceBase> connections;

  /// Currently active service
  final NetworkServiceBase? currentService;

  /// Current directory path being browsed
  final String? currentPath;

  /// Directories in the current path
  final List<Directory>? directories;

  /// Files in the current path
  final List<File>? files;

  /// Error message, if any
  final String? errorMessage;

  /// Path of the last successfully established connection (e.g. #network/service_id/)
  final String? lastSuccessfullyConnectedPath;

  /// Path of the current transfer
  final String? transferPath;

  /// Flag to indicate if state has an error
  bool get hasError => errorMessage != null && errorMessage!.isNotEmpty;

  bool get hasDirectories => directories != null && directories!.isNotEmpty;

  bool get hasFiles => files != null && files!.isNotEmpty;

  bool get hasContent => hasDirectories || hasFiles;

  const NetworkBrowsingState({
    this.isLoading = false,
    this.isConnecting = false,
    this.errorMessage,
    this.services,
    this.connections = const {},
    this.lastSuccessfullyConnectedPath,
    this.currentService,
    this.currentPath,
    this.directories,
    this.files,
    this.transferProgress,
    this.transferPath,
    this.isTransferring = false,
  });

  /// Initial state of the bloc
  const NetworkBrowsingState.initial()
      : isLoading = false,
        isConnecting = false,
        errorMessage = null,
        services = null,
        connections = const {},
        lastSuccessfullyConnectedPath = null,
        currentService = null,
        currentPath = null,
        directories = null,
        files = null,
        transferProgress = null,
        transferPath = null,
        isTransferring = false;

  /// Loading state
  NetworkBrowsingState.loading({
    String? errorMessage,
    List<NetworkServiceBase>? services,
    Map<String, NetworkServiceBase>? connections,
    String? lastSuccessfullyConnectedPath,
    NetworkServiceBase? currentService,
    String? currentPath,
    List<Directory>? directories,
    List<File>? files,
    double? transferProgress,
    String? transferPath,
    bool isTransferring = false,
  })  : isLoading = true,
        isConnecting = false,
        errorMessage = errorMessage,
        services = services,
        connections = connections ?? const {},
        lastSuccessfullyConnectedPath = lastSuccessfullyConnectedPath,
        currentService = currentService,
        currentPath = currentPath,
        directories = directories,
        files = files,
        transferProgress = transferProgress,
        transferPath = transferPath,
        isTransferring = isTransferring;

  /// State when connection is in progress
  NetworkBrowsingState.connecting({
    String? errorMessage,
    List<NetworkServiceBase>? services,
    Map<String, NetworkServiceBase>? connections,
    String? lastSuccessfullyConnectedPath,
    NetworkServiceBase? currentService,
    String? currentPath,
    List<Directory>? directories,
    List<File>? files,
    double? transferProgress,
    String? transferPath,
    bool isTransferring = false,
  })  : isLoading = false,
        isConnecting = true,
        errorMessage = errorMessage,
        services = services,
        connections = connections ?? const {},
        lastSuccessfullyConnectedPath = lastSuccessfullyConnectedPath,
        currentService = currentService,
        currentPath = currentPath,
        directories = directories,
        files = files,
        transferProgress = transferProgress,
        transferPath = transferPath,
        isTransferring = isTransferring;

  /// State when services are loaded
  NetworkBrowsingState.servicesLoaded({
    List<NetworkServiceBase> services = const [],
    Map<String, NetworkServiceBase>? connections,
    String? lastSuccessfullyConnectedPath,
    NetworkServiceBase? currentService,
    String? currentPath,
    List<Directory>? directories,
    List<File>? files,
    double? transferProgress,
    String? transferPath,
    bool isTransferring = false,
  })  : isLoading = false,
        isConnecting = false,
        errorMessage = null,
        services = services,
        connections = connections ?? const {},
        lastSuccessfullyConnectedPath = lastSuccessfullyConnectedPath,
        currentService = currentService,
        currentPath = currentPath,
        directories = directories,
        files = files,
        transferProgress = transferProgress,
        transferPath = transferPath,
        isTransferring = isTransferring;

  /// State when connected to a service
  NetworkBrowsingState.connected({
    Map<String, NetworkServiceBase>? connections,
    required String lastSuccessfullyConnectedPath,
    NetworkServiceBase? currentService,
    String? currentPath,
    List<Directory>? directories,
    List<File>? files,
    double? transferProgress,
    String? transferPath,
    bool isTransferring = false,
  })  : isLoading = false,
        isConnecting = false,
        errorMessage = null,
        services = null,
        connections = connections ?? const {},
        lastSuccessfullyConnectedPath = lastSuccessfullyConnectedPath,
        currentService = currentService,
        currentPath = currentPath,
        directories = directories,
        files = files,
        transferProgress = transferProgress,
        transferPath = transferPath,
        isTransferring = isTransferring;

  /// State when disconnected from a service
  NetworkBrowsingState.disconnected({
    Map<String, NetworkServiceBase>? connections,
    String? lastSuccessfullyConnectedPath,
    List<NetworkServiceBase>? services,
    double? transferProgress,
    String? transferPath,
    bool isTransferring = false,
  })  : isLoading = false,
        isConnecting = false,
        errorMessage = null,
        services = services,
        connections = connections ?? const {},
        lastSuccessfullyConnectedPath = lastSuccessfullyConnectedPath,
        currentService = null,
        currentPath = null,
        directories = null,
        files = null,
        transferProgress = transferProgress,
        transferPath = transferPath,
        isTransferring = isTransferring;

  /// State when a directory is loaded
  NetworkBrowsingState.directoryLoaded({
    required NetworkServiceBase currentService,
    required String currentPath,
    required List<Directory> directories,
    required List<File> files,
    Map<String, NetworkServiceBase>? connections,
    String? lastSuccessfullyConnectedPath,
    double? transferProgress,
    String? transferPath,
    bool isTransferring = false,
  })  : isLoading = false,
        isConnecting = false,
        errorMessage = null,
        services = null,
        connections = connections ?? const {},
        lastSuccessfullyConnectedPath = lastSuccessfullyConnectedPath,
        currentService = currentService,
        currentPath = currentPath,
        directories = directories,
        files = files,
        transferProgress = transferProgress,
        transferPath = transferPath,
        isTransferring = isTransferring;

  /// State when an error occurs
  NetworkBrowsingState.error({
    required String errorMessage,
    List<NetworkServiceBase>? services,
    Map<String, NetworkServiceBase>? connections,
    String? lastSuccessfullyConnectedPath,
    NetworkServiceBase? currentService,
    String? currentPath,
    List<Directory>? directories,
    List<File>? files,
    double? transferProgress,
    String? transferPath,
    bool isTransferring = false,
  })  : isLoading = false,
        isConnecting = false,
        errorMessage = errorMessage,
        services = services,
        connections = connections ?? const {},
        lastSuccessfullyConnectedPath = lastSuccessfullyConnectedPath,
        currentService = currentService,
        currentPath = currentPath,
        directories = directories,
        files = files,
        transferProgress = transferProgress,
        transferPath = transferPath,
        isTransferring = isTransferring;

  /// State when a file transfer is in progress
  NetworkBrowsingState.transferring({
    required double transferProgress,
    required String transferPath,
    List<NetworkServiceBase>? services,
    Map<String, NetworkServiceBase>? connections,
    String? lastSuccessfullyConnectedPath,
    NetworkServiceBase? currentService,
    String? currentPath,
    List<Directory>? directories,
    List<File>? files,
  })  : isLoading = false,
        isConnecting = false,
        errorMessage = null,
        services = services,
        connections = connections ?? const {},
        lastSuccessfullyConnectedPath = lastSuccessfullyConnectedPath,
        currentService = currentService,
        currentPath = currentPath,
        directories = directories,
        files = files,
        transferProgress = transferProgress,
        transferPath = transferPath,
        isTransferring = true;

  /// Helper method to create a copy of the current state with some values changed.
  /// This is often preferred over many named constructors for state updates.
  NetworkBrowsingState copyWith({
    bool? isLoading,
    bool? isConnecting,
    String? errorMessage,
    bool clearErrorMessage = false,
    List<NetworkServiceBase>? services,
    bool clearServices = false,
    Map<String, NetworkServiceBase>? connections,
    String? lastSuccessfullyConnectedPath,
    bool clearLastSuccessfullyConnectedPath = false,
    NetworkServiceBase? currentService,
    String? currentPath,
    List<Directory>? directories,
    bool clearDirectories = false,
    List<File>? files,
    bool clearFiles = false,
    double? transferProgress,
    String? transferPath,
    bool? isTransferring,
  }) {
    return NetworkBrowsingState(
      isLoading: isLoading ?? this.isLoading,
      isConnecting: isConnecting ?? this.isConnecting,
      errorMessage:
          clearErrorMessage ? null : errorMessage ?? this.errorMessage,
      services: clearServices ? null : services ?? this.services,
      connections: connections ?? this.connections,
      lastSuccessfullyConnectedPath: clearLastSuccessfullyConnectedPath
          ? null
          : lastSuccessfullyConnectedPath ?? this.lastSuccessfullyConnectedPath,
      currentService: currentService ?? this.currentService,
      currentPath: currentPath ?? this.currentPath,
      directories: clearDirectories ? null : directories ?? this.directories,
      files: clearFiles ? null : files ?? this.files,
      transferProgress: transferProgress ?? this.transferProgress,
      transferPath: transferPath ?? this.transferPath,
      isTransferring: isTransferring ?? this.isTransferring,
    );
  }

  @override
  List<Object?> get props => [
        isLoading,
        isConnecting,
        errorMessage,
        services,
        connections,
        lastSuccessfullyConnectedPath,
        currentService,
        currentPath,
        directories,
        files,
        transferProgress,
        transferPath,
        isTransferring,
      ];

  @override
  String toString() {
    return 'NetworkBrowsingState{'
        'isLoading: $isLoading, '
        'isConnecting: $isConnecting, '
        'errorMessage: $errorMessage, '
        'servicesCount: ${services?.length ?? 0}, '
        'connectionsCount: ${connections.length}, '
        'lastSuccessfullyConnectedPath: $lastSuccessfullyConnectedPath, '
        'currentService: ${currentService?.serviceName}, '
        'currentPath: $currentPath, '
        'directoriesCount: ${directories?.length ?? 0}, '
        'filesCount: ${files?.length ?? 0}, '
        'transferProgress: $transferProgress, '
        'transferPath: $transferPath, '
        'isTransferring: $isTransferring}';
  }
}
