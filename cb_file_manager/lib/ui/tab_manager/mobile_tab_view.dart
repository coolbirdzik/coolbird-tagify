import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Thêm import cho SystemUiOverlayStyle
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:io'; // Thêm import cho Platform
import 'tab_manager.dart';
import 'tab_data.dart';
import '../screens/settings/settings_screen.dart';
import 'tabbed_folder_list_screen.dart';

/// Giao diện kiểu Chrome cho thiết bị di động, hiển thị thanh địa chỉ ở trên
/// và một nút hiển thị số lượng tab bên cạnh
class MobileTabView extends StatelessWidget {
  /// Callback khi nhấn vào nút thêm tab mới
  final VoidCallback onAddNewTab;

  const MobileTabView({
    Key? key,
    required this.onAddNewTab,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Lấy theme để xác định màu sắc phù hợp
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return BlocBuilder<TabManagerBloc, TabManagerState>(
      builder: (context, state) {
        // Xác định style dựa trên trạng thái tab và theme
        final overlayStyle = isDarkMode
            ? SystemUiOverlayStyle.light.copyWith(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: Brightness.light,
                statusBarBrightness: Brightness.dark,
              )
            : SystemUiOverlayStyle.dark.copyWith(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: Brightness.dark,
                statusBarBrightness: Brightness.light,
              );

        // Sử dụng AnnotatedRegion để áp dụng style cho khu vực này
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: overlayStyle,
          child: SafeArea(
            child: Column(
              children: [
                // Luôn hiển thị thanh địa chỉ kiểu Chrome
                _buildEmptyOrNormalChromeBar(context, state),

                // Nội dung chính: hiển thị nội dung tab hoặc màn hình trống
                Expanded(
                  child: state.tabs.isEmpty
                      ? _buildEmptyTabsView(context)
                      : _buildTabContent(state),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Xây dựng thanh chrome style cho cả trường hợp có tab và không có tab
  Widget _buildEmptyOrNormalChromeBar(
      BuildContext context, TabManagerState state) {
    // Nếu không có tab, hiển thị thanh chrome style đơn giản hơn
    if (state.tabs.isEmpty) {
      return _buildEmptyChromeStyleAddressBar(context);
    }

    // Nếu có tab, sử dụng thanh chrome style bình thường
    return _buildChromeStyleAddressBar(context, state);
  }

  /// Xây dựng thanh chrome style khi không có tab nào
  Widget _buildEmptyChromeStyleAddressBar(BuildContext context) {
    // Lấy màu từ theme để đảm bảo đồng bộ với theme của ứng dụng
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    // Sử dụng màu trắng hoặc đen tùy theo theme sáng/tối
    final backgroundColor = isDarkMode ? Colors.black : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: backgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          // Nút menu để mở drawer
          IconButton(
            icon: Icon(Icons.menu, color: textColor),
            onPressed: () {
              // Mở Scaffold drawer
              Scaffold.of(context).openDrawer();
            },
          ),

          // Thanh tiêu đề - sử dụng AddressBarWidget giống như khi có tab
          Expanded(
            child: AddressBarWidget(
              path: "",
              name: "CoolBird File Manager",
              onTap: () {
                // Không cần hành động, hoặc có thể hiển thị thông báo cần mở tab trước
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Vui lòng tạo một tab trước khi điều hướng'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              isDarkMode: isDarkMode,
            ),
          ),

          // Nút thêm tab mới
          IconButton(
            icon: Icon(Icons.add, color: textColor),
            tooltip: 'Add new tab',
            onPressed: onAddNewTab,
          ),

          // Nút menu tùy chọn
          IconButton(
            icon: Icon(Icons.more_vert, color: textColor),
            onPressed: () {
              _showMobileTabOptions(context);
            },
          ),
        ],
      ),
    );
  }

  /// Xây dựng thanh địa chỉ và nút tab kiểu Chrome
  Widget _buildChromeStyleAddressBar(
      BuildContext context, TabManagerState state) {
    // Lấy tab đang hoạt động
    final activeTab = state.activeTab;
    if (activeTab == null) return Container();

    // Lấy màu từ theme để đảm bảo đồng bộ với theme của ứng dụng
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    // Sử dụng màu trắng hoặc đen tùy theo theme sáng/tối
    final backgroundColor = isDarkMode ? Colors.black : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: backgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          // Nút menu để mở drawer
          IconButton(
            icon: Icon(Icons.menu, color: textColor),
            onPressed: () {
              // Mở Scaffold drawer
              Scaffold.of(context).openDrawer();
            },
          ),

          // Thanh địa chỉ
          Expanded(
            child: AddressBarWidget(
              path: activeTab.path,
              name: activeTab.name,
              onTap: () {
                _showPathNavigationDialog(context, activeTab);
              },
              isDarkMode: isDarkMode,
            ),
          ),

          // Nút số lượng tab và menu tab - đã chuyển sang bên phải thanh địa chỉ
          _buildTabCountButton(context, state, textColor),

          // Nút menu tùy chọn
          IconButton(
            icon: Icon(Icons.more_vert, color: textColor),
            onPressed: () {
              _showMobileTabOptions(context);
            },
          ),
        ],
      ),
    );
  }

  /// Hiển thị menu tùy chọn cho giao diện mobile
  void _showMobileTabOptions(BuildContext context) {
    final state = context.read<TabManagerBloc>().state;
    final activeTab = state.activeTab;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Thanh kéo ở trên cùng
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              child: Text(
                'Tùy chọn',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),

            Divider(height: 1),

            // Danh sách các tùy chọn
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  // Thêm tab mới
                  ListTile(
                    leading: const Icon(Icons.add),
                    title: const Text('Thêm tab mới'),
                    onTap: () {
                      Navigator.pop(context);
                      onAddNewTab();
                    },
                  ),

                  // Làm mới tab hiện tại
                  if (activeTab != null)
                    ListTile(
                      leading: const Icon(Icons.refresh),
                      title: const Text('Làm mới tab'),
                      onTap: () {
                        Navigator.pop(context);
                        context
                            .read<TabManagerBloc>()
                            .add(UpdateTabPath(activeTab.id, activeTab.path));
                      },
                    ),

                  // Xem thông tin chi tiết về tab
                  if (activeTab != null)
                    ListTile(
                      leading: const Icon(Icons.info_outline),
                      title: const Text('Thông tin tab'),
                      onTap: () {
                        Navigator.pop(context);
                        _showTabInfoDialog(context, activeTab);
                      },
                    ),

                  // Đóng tất cả các tab
                  if (state.tabs.isNotEmpty)
                    ListTile(
                      leading: const Icon(Icons.close),
                      title: const Text('Đóng tất cả các tab'),
                      onTap: () {
                        Navigator.pop(context);
                        _showCloseAllTabsConfirmation(context);
                      },
                    ),

                  const Divider(),

                  // Cài đặt
                  ListTile(
                    leading: const Icon(Icons.settings),
                    title: const Text('Cài đặt'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SettingsScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Hiển thị hộp thoại xác nhận khi đóng tất cả các tab
  void _showCloseAllTabsConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Đóng tất cả các tab?'),
        content: const Text('Bạn có chắc chắn muốn đóng tất cả các tab không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              final tabBloc = context.read<TabManagerBloc>();
              final tabs = List<TabData>.from(tabBloc.state.tabs);
              for (var tab in tabs) {
                tabBloc.add(CloseTab(tab.id));
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Đóng tất cả'),
          ),
        ],
      ),
    );
  }

  /// Hiển thị thông tin chi tiết về tab
  void _showTabInfoDialog(BuildContext context, TabData tab) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tab.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Thông tin tab:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Đường dẫn: ${tab.path}'),
            const SizedBox(height: 4),
            Text('Ghim: ${tab.isPinned ? 'Có' : 'Không'}'),
            const SizedBox(height: 4),
            Text('ID: ${tab.id}'),
            const SizedBox(height: 16),
            Text(
              'Lịch sử điều hướng:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (tab.navigationHistory.isEmpty)
              const Text('Không có lịch sử')
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: tab.navigationHistory.length,
                  itemBuilder: (context, index) {
                    final path = tab.navigationHistory[index];
                    final isCurrentPath = path == tab.path;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        path.isEmpty ? 'Drives' : path,
                        style: TextStyle(
                          fontWeight: isCurrentPath ? FontWeight.bold : null,
                          color: isCurrentPath
                              ? Theme.of(context).colorScheme.primary
                              : null,
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
        actions: [
          if (tab.isPinned)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                context.read<TabManagerBloc>().add(ToggleTabPin(tab.id));
              },
              child: const Text('Bỏ ghim'),
            )
          else
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                context.read<TabManagerBloc>().add(ToggleTabPin(tab.id));
              },
              child: const Text('Ghim'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  /// Xây dựng nút hiển thị số lượng tab
  Widget _buildTabCountButton(
      BuildContext context, TabManagerState state, Color textColor) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        _showTabsBottomSheet(context, state);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        margin: const EdgeInsets.only(left: 8.0),
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.grey[800] : Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDarkMode
                ? Colors.grey[700]!
                : theme.colorScheme.outline.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${state.tabs.length}',
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.tab,
              size: 16,
              color: textColor,
            ),
          ],
        ),
      ),
    );
  }

  /// Hiển thị danh sách tab trong bottom sheet
  void _showTabsBottomSheet(BuildContext context, TabManagerState state) {
    // Lấy instance của TabManagerBloc từ context hiện tại
    final tabManagerBloc = BlocProvider.of<TabManagerBloc>(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) =>
          // Sử dụng BlocProvider.value để truyền instance của TabManagerBloc vào widget tree mới
          BlocProvider.value(
        value: tabManagerBloc,
        child: Builder(
          builder: (newContext) => BlocBuilder<TabManagerBloc, TabManagerState>(
            builder: (context, updatedState) => Container(
              decoration: BoxDecoration(
                color: Theme.of(newContext).scaffoldBackgroundColor,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(newContext).size.height * 0.7,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Thanh tiêu đề
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Text(
                          'Tabs (${updatedState.tabs.length})',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(newContext).colorScheme.onSurface,
                          ),
                        ),
                        const Spacer(),
                        // Nút thêm tab mới
                        IconButton(
                          icon: const Icon(Icons.add),
                          tooltip: 'Add new tab',
                          onPressed: () {
                            Navigator.pop(newContext); // Đóng bottom sheet
                            onAddNewTab();
                          },
                        ),
                      ],
                    ),
                  ),

                  const Divider(height: 1),

                  // Danh sách tab
                  Flexible(
                    child: updatedState.tabs.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Text(
                                'Không có tab nào',
                                style: TextStyle(
                                  color: Theme.of(newContext)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            padding: EdgeInsets.zero,
                            itemCount: updatedState.tabs.length,
                            itemBuilder: (context, index) {
                              final tab = updatedState.tabs[index];
                              final isActive =
                                  tab.id == updatedState.activeTabId;

                              return ListTile(
                                leading: Icon(
                                  tab.isPinned ? Icons.push_pin : Icons.folder,
                                  color: isActive
                                      ? Theme.of(newContext).colorScheme.primary
                                      : null,
                                ),
                                title: Text(
                                  tab.name,
                                  style: TextStyle(
                                    fontWeight:
                                        isActive ? FontWeight.bold : null,
                                    color: isActive
                                        ? Theme.of(newContext)
                                            .colorScheme
                                            .primary
                                        : null,
                                  ),
                                ),
                                subtitle: Text(
                                  tab.path,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.close),
                                  onPressed: () {
                                    // Sử dụng context mới có BlocProvider để đóng tab
                                    BlocProvider.of<TabManagerBloc>(newContext)
                                        .add(CloseTab(tab.id));
                                  },
                                ),
                                selected: isActive,
                                onTap: () {
                                  if (!isActive) {
                                    // Sử dụng context mới có BlocProvider để chuyển tab
                                    BlocProvider.of<TabManagerBloc>(newContext)
                                        .add(SwitchToTab(tab.id));
                                  }
                                  Navigator.pop(
                                      newContext); // Đóng bottom sheet
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyTabsView(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.tab_unselected,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          const Text(
            'No tabs open',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Open a new tab to get started',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('New Tab'),
            onPressed: onAddNewTab,
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent(TabManagerState state) {
    final activeTab = state.activeTab;
    if (activeTab == null) return Container();

    return Container(
      key: ValueKey(activeTab.id), // Đảm bảo rebuild khi tab thay đổi
      child: Navigator(
        key: activeTab.navigatorKey,
        onGenerateRoute: (settings) {
          return MaterialPageRoute(
            settings: settings,
            builder: (context) => TabContentScreen(
              path: activeTab.path,
              tabId: activeTab.id,
            ),
          );
        },
      ),
    );
  }

  /// Hiển thị dialog cho phép người dùng thay đổi đường dẫn
  void _showPathNavigationDialog(BuildContext context, TabData tab) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black;

    // Phân tách đường dẫn thành các phần
    List<String> pathParts = tab.path.split(Platform.pathSeparator);
    if (tab.path.startsWith(Platform.pathSeparator)) {
      pathParts = [
        Platform.pathSeparator,
        ...pathParts.where((part) => part.isNotEmpty)
      ];
    } else if (tab.path.isEmpty) {
      pathParts = ["Drives"];
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Thanh kéo ở trên cùng
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              child: Row(
                children: [
                  Text(
                    'Chọn vị trí',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const Spacer(),
                  // Nút đóng
                  IconButton(
                    icon: Icon(Icons.close, color: textColor),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Hiển thị đường dẫn hiện tại
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Text(
                  tab.path.isEmpty ? 'Drives' : tab.path,
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ),

            // Danh sách các phần của đường dẫn
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: pathParts.length,
                itemBuilder: (context, index) {
                  // Tạo đường dẫn từ đầu đến phần hiện tại
                  String currentPath;
                  if (pathParts[0] == "Drives") {
                    currentPath = index == 0
                        ? ""
                        : pathParts
                            .sublist(1, index + 1)
                            .join(Platform.pathSeparator);
                  } else {
                    if (pathParts[0] == Platform.pathSeparator) {
                      currentPath = index == 0
                          ? Platform.pathSeparator
                          : Platform.pathSeparator +
                              pathParts
                                  .sublist(1, index + 1)
                                  .join(Platform.pathSeparator);
                    } else {
                      currentPath = pathParts
                          .sublist(0, index + 1)
                          .join(Platform.pathSeparator);
                    }
                  }

                  return ListTile(
                    leading: Icon(
                      index == 0 ? Icons.computer : Icons.folder,
                      color: theme.colorScheme.primary,
                    ),
                    title: Text(
                      pathParts[index].isEmpty ? 'Root' : pathParts[index],
                      style: TextStyle(
                        fontWeight: index == pathParts.length - 1
                            ? FontWeight.bold
                            : null,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      // Cập nhật đường dẫn hiện tại
                      context
                          .read<TabManagerBloc>()
                          .add(UpdateTabPath(tab.id, currentPath));
                    },
                  );
                },
              ),
            ),

            // Phần chân với lịch sử điều hướng
            if (tab.navigationHistory.isNotEmpty) ...[
              const Divider(),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Lịch sử điều hướng:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
              Container(
                height: 60,
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: tab.navigationHistory.length,
                  itemBuilder: (context, index) {
                    final historyPath = tab.navigationHistory[index];
                    final isCurrentPath = historyPath == tab.path;

                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: InkWell(
                        onTap: () {
                          Navigator.pop(context);
                          if (!isCurrentPath) {
                            context
                                .read<TabManagerBloc>()
                                .add(UpdateTabPath(tab.id, historyPath));
                          }
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isCurrentPath
                                ? theme.colorScheme.primary.withOpacity(0.2)
                                : isDarkMode
                                    ? Colors.grey[800]
                                    : Colors.grey[200],
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Center(
                            child: Text(
                              historyPath.isEmpty
                                  ? 'Drives'
                                  : historyPath
                                          .split(Platform.pathSeparator)
                                          .last
                                          .isEmpty
                                      ? Platform.pathSeparator
                                      : historyPath
                                          .split(Platform.pathSeparator)
                                          .last,
                              style: TextStyle(
                                color: isCurrentPath
                                    ? theme.colorScheme.primary
                                    : isDarkMode
                                        ? Colors.white
                                        : Colors.black87,
                                fontWeight:
                                    isCurrentPath ? FontWeight.bold : null,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
  }
}

/// Widget để hiển thị nội dung tab, tái sử dụng TabbedFolderListScreen
class TabContentScreen extends StatelessWidget {
  final String path;
  final String tabId;

  const TabContentScreen({
    Key? key,
    required this.path,
    required this.tabId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Import và sử dụng TabbedFolderListScreen nhưng ẩn AppBar
    // do thanh địa chỉ đã được hiển thị ở MobileTabView
    return TabbedFolderListScreen(
      path: path,
      tabId: tabId,
      showAppBar: false, // Thêm tham số này vào TabbedFolderListScreen
    );
  }
}

/// Widget hiển thị thanh địa chỉ có thể nhấn để thay đổi đường dẫn
class AddressBarWidget extends StatelessWidget {
  final String path;
  final String name;
  final VoidCallback onTap;
  final bool isDarkMode;

  const AddressBarWidget({
    Key? key,
    required this.path,
    required this.name,
    required this.onTap,
    required this.isDarkMode,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20.0),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.grey[800] : Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(20.0),
          border: Border.all(
            color: isDarkMode
                ? Colors.grey[700]!
                : theme.colorScheme.outline.withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.folder_outlined,
              size: 16,
              color: isDarkMode ? Colors.white70 : Colors.black87,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              Icons.arrow_drop_down,
              size: 20,
              color: isDarkMode ? Colors.white70 : Colors.black87,
            ),
          ],
        ),
      ),
    );
  }
}
