import 'package:flutter/material.dart';
import 'dart:io';
import '../../services/permission_state_service.dart';
import '../screens/permissions/permission_explainer_screen.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';
import '../../bloc/network_browsing/network_browsing_bloc.dart';
import 'tab_manager.dart';
import 'tab_screen.dart';

/// The main screen that provides the tabbed interface for the file manager
class TabMainScreen extends StatefulWidget {
  const TabMainScreen({Key? key}) : super(key: key);

  /// Static method to create and open a new tab with a specific path
  static void openPath(BuildContext context, String path) {
    final tabBloc = context.read<TabManagerBloc>();
    tabBloc.add(AddTab(path: path));
  }

  /// Static method to open the default path (e.g., documents directory)
  static Future<void> openDefaultPath(BuildContext context) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      openPath(context, directory.path);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error accessing directory: $e')),
      );
    }
  }

  @override
  State<TabMainScreen> createState() => _TabMainScreenState();
}

class _TabMainScreenState extends State<TabMainScreen> {
  late TabManagerBloc _tabManagerBloc;
  late NetworkBrowsingBloc _networkBrowsingBloc;
  bool _checkedPerms = false;

  @override
  void initState() {
    super.initState();
    _tabManagerBloc = TabManagerBloc();
    _networkBrowsingBloc = NetworkBrowsingBloc();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (_checkedPerms) return;
      _checkedPerms = true;
      final hasStorage =
          await PermissionStateService.instance.hasStorageOrPhotosPermission();
      final hasLocal =
          await PermissionStateService.instance.hasLocalNetworkPermission();
      final needsExplainer =
          !hasStorage || (Platform.isIOS ? !hasLocal : false);
      if (needsExplainer) {
        if (!mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const PermissionExplainerScreen(),
            fullscreenDialog: true,
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _tabManagerBloc.close();
    _networkBrowsingBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<TabManagerBloc>.value(value: _tabManagerBloc),
        BlocProvider<NetworkBrowsingBloc>.value(value: _networkBrowsingBloc),
      ],
      child: const TabScreen(),
    );
  }
}
