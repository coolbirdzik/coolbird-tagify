import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:eva_icons_flutter/eva_icons_flutter.dart';

import '../../../bloc/network_browsing/network_browsing_bloc.dart';
import '../../../bloc/network_browsing/network_browsing_event.dart';
import '../../../bloc/network_browsing/network_browsing_state.dart';
import '../../../services/network_browsing/network_service_base.dart';
import '../../tab_manager/tab_manager.dart';
import '../../tab_manager/tab_data.dart'; // Import TabData
import '../../tab_manager/tab_main_screen.dart'; // Import TabMainScreen
import 'network_connection_dialog.dart';
import 'smb_browser_screen.dart'; // Import SMBBrowserScreen

/// Screen to display and manage network connections
class NetworkConnectionScreen extends StatefulWidget {
  const NetworkConnectionScreen({Key? key}) : super(key: key);

  @override
  State<NetworkConnectionScreen> createState() =>
      _NetworkConnectionScreenState();
}

class _NetworkConnectionScreenState extends State<NetworkConnectionScreen> {
  @override
  void initState() {
    super.initState();
    // Request list of available services when screen initializes
    context.read<NetworkBrowsingBloc>().add(
          const NetworkServicesListRequested(),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Network Connections')),
      body: BlocBuilder<NetworkBrowsingBloc, NetworkBrowsingState>(
        builder: (context, state) {
          if (state.isLoading && state.connections.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(EvaIcons.alertTriangle,
                      size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${state.errorMessage}',
                      textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context
                        .read<NetworkBrowsingBloc>()
                        .add(const NetworkServicesListRequested()),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              context
                  .read<NetworkBrowsingBloc>()
                  .add(const NetworkServicesListRequested());
            },
            child: ListView(
              children: [
                // Active Connections Section
                Padding(
                  padding: const EdgeInsets.fromLTRB(16.0, 24.0, 16.0, 8.0),
                  child: Text(
                    'Active Connections',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                _buildActiveConnections(state.connections),

                const Divider(height: 32),

                // Available Services Section
                Padding(
                  padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0),
                  child: Text(
                    'Available Services',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                _buildAvailableServices(state.services ?? []),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showConnectionDialog(context),
        child: const Icon(EvaIcons.plus),
        tooltip: 'Add Connection',
      ),
    );
  }

  Widget _buildActiveConnections(Map<String, NetworkServiceBase> connections) {
    if (connections.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(EvaIcons.wifiOffOutline, size: 48, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'No active network connections',
                style: TextStyle(color: Colors.grey),
              ),
              SizedBox(height: 8),
              Text(
                'Use the (+) button to add a new connection',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: connections.length,
      itemBuilder: (context, index) {
        final entry = connections.entries.elementAt(index);
        final path = entry.key;
        final service = entry.value;

        String displayName = 'Unknown Connection';
        String subtitle = service.serviceName;

        if (path.startsWith('#network/')) {
          final parts = path.substring('#network/'.length).split('/');
          if (parts.length >= 2) {
            final serviceName = parts[0];
            final host = Uri.decodeComponent(parts[1]);
            displayName = host;
            subtitle = '$serviceName Connection';
          }
        }

        return ListTile(
          leading: Icon(
            service.serviceIcon,
            color: Theme.of(context).primaryColor,
          ),
          title: Text(displayName, overflow: TextOverflow.ellipsis),
          subtitle: Text(subtitle),
          trailing: IconButton(
            icon: const Icon(EvaIcons.closeCircleOutline, color: Colors.red),
            onPressed: () => _disconnectService(path),
            tooltip: 'Disconnect',
          ),
          onTap: () => _openConnection(path),
        );
      },
    );
  }

  Widget _buildAvailableServices(List<NetworkServiceBase> services) {
    if (services.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(child: Text('No services available')),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: services.length,
      itemBuilder: (context, index) {
        final service = services[index];

        return ListTile(
          leading: Icon(
            service.serviceIcon,
            color: Theme.of(context).primaryColor,
          ),
          title: Text(service.serviceName),
          subtitle: Text(service.serviceDescription),
          onTap: () {
            if (service.serviceName == 'SMB') {
              _openBrowserInTab(context, '#smb', 'SMB Network');
            } else if (service.serviceName == 'FTP') {
              _openBrowserInTab(context, '#ftp', 'FTP Connections');
            } else {
              _showConnectionDialog(
                context,
                initialService: service.serviceName,
              );
            }
          },
        );
      },
    );
  }

  void _showConnectionDialog(BuildContext context, {String? initialService}) {
    final networkBloc = context.read<NetworkBrowsingBloc>();
    showDialog(
      context: context,
      builder: (dialogContext) => BlocProvider.value(
        value: networkBloc,
        child: NetworkConnectionDialog(initialService: initialService),
      ),
    );
  }

  void _disconnectService(String path) {
    context.read<NetworkBrowsingBloc>().add(NetworkDisconnectRequested(path));
  }

  void _openConnection(String path) {
    debugPrint("NetworkConnectionScreen: Opening connection to path: $path");

    if (path.startsWith('#network/')) {
      final tabBloc = BlocProvider.of<TabManagerBloc>(context, listen: false);

      String tabName = 'Network';
      try {
        final parts = path.substring('#network/'.length).split('/');
        if (parts.length >= 2) {
          final serviceName = parts[0];
          final host = Uri.decodeComponent(parts[1]);
          tabName = '$host ($serviceName)';
        }
      } catch (_) {}

      debugPrint(
          "NetworkConnectionScreen: Opening new tab with path: $path and name: $tabName");
      tabBloc.add(AddTab(
        path: path,
        name: tabName,
        switchToTab: true,
      ));
    }
    // Do not pop the navigator here, as it causes the crash.
  }

  void _openBrowserInTab(BuildContext context, String path, String tabName) {
    try {
      final tabBloc = BlocProvider.of<TabManagerBloc>(context, listen: false);
      tabBloc.add(
        AddTab(
          path: path,
          name: tabName,
          switchToTab: true,
        ),
      );
      // Do not pop the navigator here. The user should be able to navigate back
      // to this connection screen from the tab bar if they wish.
    } catch (e) {
      debugPrint('Error opening tab for $tabName: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening tab for $tabName: $e')),
        );
      }
    }
  }
}
