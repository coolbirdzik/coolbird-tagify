import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:eva_icons_flutter/eva_icons_flutter.dart';

import '../../../bloc/network_browsing/network_browsing_bloc.dart';
import '../../../bloc/network_browsing/network_browsing_event.dart';
import '../../../bloc/network_browsing/network_browsing_state.dart';
import '../../../services/network_browsing/network_service_registry.dart';
import '../../../services/network_browsing/network_service_base.dart';
import '../../../services/network_browsing/ftp_service.dart';
import '../../../services/network_browsing/ftp_tester.dart';
import '../../../services/network_credentials_service.dart';
import '../../../models/database/network_credentials.dart';
import '../../tab_manager/tab_manager.dart';
import '../../utils/fluent_background.dart';
import '../system_screen.dart';
import 'network_connection_dialog.dart';

/// Screen to browse FTP servers
class FTPBrowserScreen extends StatefulWidget {
  /// The tab ID this screen belongs to
  final String tabId;

  const FTPBrowserScreen({
    Key? key,
    required this.tabId,
  }) : super(key: key);

  @override
  State<FTPBrowserScreen> createState() => _FTPBrowserScreenState();
}

class _FTPBrowserScreenState extends State<FTPBrowserScreen>
    with WidgetsBindingObserver {
  final NetworkServiceRegistry _registry = NetworkServiceRegistry();
  final NetworkCredentialsService _credentialsService =
      NetworkCredentialsService();

  late NetworkBrowsingBloc _networkBloc;

  List<NetworkCredentials> _savedCredentials = [];
  Set<int> _connectingCredentialIds = {};
  Map<String, int> _pendingTabCredentialMap = {};

  final TextEditingController _hostController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _portController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _networkBloc = BlocProvider.of<NetworkBrowsingBloc>(context, listen: false);

    _setupBlocListener();
    _refreshData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hostController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _portController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshData();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _refreshData();
  }

  void _setupBlocListener() {
    _networkBloc.stream.listen((state) {
      if (!mounted) return;

      if (state.lastSuccessfullyConnectedPath != null) {
        _handleSuccessfulConnection(state.lastSuccessfullyConnectedPath!);
      }

      bool hadError = false;
      if (state.errorMessage != null && _connectingCredentialIds.isNotEmpty) {
        hadError = true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi kết nối: ${state.errorMessage}')),
        );
      }

      setState(() {
        if (hadError || state.lastSuccessfullyConnectedPath != null) {
          _connectingCredentialIds.clear();
        }
      });
    });
  }

  void _handleSuccessfulConnection(String connectionPath) {
    if (!connectionPath.startsWith('#network/FTP/')) return;

    final host = Uri.decodeComponent(connectionPath.split('/')[2]);

    final credentialId = _pendingTabCredentialMap[host];
    if (credentialId != null) {
      _openTabForConnection(connectionPath, host);
      _pendingTabCredentialMap.remove(host);
    }
  }

  void _refreshData() {
    if (mounted) {
      setState(() {
        _loadSavedCredentials();
      });
      _networkBloc.add(NetworkServicesListRequested());
    }
  }

  void _loadSavedCredentials() {
    try {
      _savedCredentials =
          _credentialsService.getCredentialsByServiceType('FTP');
    } catch (e) {
      debugPrint('Lỗi khi tải thông tin đăng nhập đã lưu: $e');
    }
  }

  void _connectToFTPServer() {
    showDialog(
      context: context,
      builder: (dialogContext) => BlocProvider.value(
        value: _networkBloc,
        child: const NetworkConnectionDialog(initialService: 'FTP'),
      ),
    ).then((_) => _refreshData());
  }

  void _connectWithSavedCredentials(NetworkCredentials credentials) {
    setState(() {
      _connectingCredentialIds.add(credentials.id);
      _pendingTabCredentialMap[credentials.host] = credentials.id;
    });

    _networkBloc.add(NetworkConnectionRequested(
      serviceName: 'FTP',
      host: credentials.host,
      username: credentials.username,
      password: credentials.password,
      port: credentials.port,
    ));
  }

  void _openTabForConnection(String path, String name) {
    final tabBloc = BlocProvider.of<TabManagerBloc>(context, listen: false);
    tabBloc.add(AddTab(
      path: path,
      name: '$name (FTP)',
      switchToTab: true,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return SystemScreen(
      title: 'FTP Connections',
      systemId: '#ftp',
      icon: EvaIcons.cloudUpload,
      showAppBar: true,
      actions: [
        IconButton(
          icon: const Icon(EvaIcons.refresh),
          onPressed: _refreshData,
          tooltip: 'Làm mới',
        ),
        IconButton(
          icon: const Icon(EvaIcons.plus),
          onPressed: _connectToFTPServer,
          tooltip: 'Add Connection',
        ),
      ],
      child: BlocBuilder<NetworkBrowsingBloc, NetworkBrowsingState>(
        bloc: _networkBloc,
        builder: (context, state) {
          final activeConnections = state.connections.entries
              .where((entry) => (entry.value).serviceName == 'FTP')
              .toList();

          if (activeConnections.isEmpty && _savedCredentials.isEmpty) {
            return const Center(child: Text('Không có kết nối FTP nào.'));
          }

          return ListView(
            padding: const EdgeInsets.all(8.0),
            children: [
              if (activeConnections.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(
                      vertical: 8.0, horizontal: 8.0),
                  child: Text('Kết nối đang hoạt động',
                      style: Theme.of(context).textTheme.titleSmall),
                ),
                ...activeConnections.map(_buildActiveConnectionItem),
                const Divider(),
              ],
              if (_savedCredentials.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(
                      vertical: 8.0, horizontal: 8.0),
                  child: Text('Kết nối đã lưu',
                      style: Theme.of(context).textTheme.titleSmall),
                ),
                ..._savedCredentials.map(_buildSavedConnectionItem),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildActiveConnectionItem(
      MapEntry<String, NetworkServiceBase> entry) {
    String host = 'Unknown';
    try {
      host = Uri.parse(entry.value.basePath).host;
    } catch (_) {}

    return ListTile(
      leading: const Icon(EvaIcons.monitor, color: Colors.green),
      title: Text(host),
      subtitle: const Text('Đang kết nối'),
      onTap: () => _openTabForConnection(entry.key, host),
    );
  }

  Widget _buildSavedConnectionItem(NetworkCredentials credentials) {
    final isConnecting = _connectingCredentialIds.contains(credentials.id);

    return ListTile(
      leading: const Icon(EvaIcons.cloudUpload, color: Colors.blue),
      title: Text(credentials.host),
      subtitle: Text(credentials.username),
      trailing: IconButton(
        icon: isConnecting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.0))
            : const Icon(EvaIcons.arrowCircleRight, color: Colors.green),
        onPressed: isConnecting
            ? null
            : () => _connectWithSavedCredentials(credentials),
        tooltip: 'Kết nối',
      ),
      onTap:
          isConnecting ? null : () => _connectWithSavedCredentials(credentials),
    );
  }
}
