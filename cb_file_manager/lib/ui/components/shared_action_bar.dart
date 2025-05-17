import 'package:flutter/material.dart';
import 'package:cb_file_manager/ui/screens/folder_list/folder_list_state.dart';
import 'package:cb_file_manager/helpers/user_preferences.dart';
import 'package:eva_icons_flutter/eva_icons_flutter.dart';

class SharedActionBar {
  /// Tạo popup menu item cho các tùy chọn sắp xếp
  static PopupMenuItem<SortOption> buildSortMenuItem(
    BuildContext context,
    SortOption option,
    String label,
    IconData icon,
    SortOption currentOption,
  ) {
    return PopupMenuItem<SortOption>(
      value: option,
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: option == currentOption ? Colors.blue : null,
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontWeight:
                  option == currentOption ? FontWeight.bold : FontWeight.normal,
              color: option == currentOption ? Colors.blue : null,
            ),
          ),
          const Spacer(),
          if (option == currentOption)
            const Icon(EvaIcons.checkmark, color: Colors.blue, size: 20),
        ],
      ),
    );
  }

  /// Dialog điều chỉnh kích thước lưới
  static void showGridSizeDialog(
    BuildContext context, {
    required int currentGridSize,
    required Function(int) onApply,
  }) {
    int size = currentGridSize;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            title: const Text('Điều chỉnh kích thước lưới'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Slider(
                  value: size.toDouble(),
                  min: UserPreferences.minGridZoomLevel.toDouble(),
                  max: UserPreferences.maxGridZoomLevel.toDouble(),
                  divisions: UserPreferences.maxGridZoomLevel -
                      UserPreferences.minGridZoomLevel,
                  label: '${size.round()} ô trên mỗi hàng',
                  onChanged: (double value) {
                    setState(() {
                      size = value.round();
                    });
                  },
                ),
                const Text(
                  'Di chuyển thanh trượt để chọn số lượng ô hiển thị trên mỗi hàng',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('HỦY'),
              ),
              TextButton(
                onPressed: () {
                  onApply(size);
                  Navigator.pop(context);
                },
                child: const Text('ÁP DỤNG'),
              ),
            ],
          );
        });
      },
    );
  }

  /// Dialog thiết lập hiển thị cột
  static void showColumnVisibilityDialog(
    BuildContext context, {
    required ColumnVisibility currentVisibility,
    required Function(ColumnVisibility) onApply,
  }) {
    // Create a mutable copy of the current visibility
    bool size = currentVisibility.size;
    bool type = currentVisibility.type;
    bool dateModified = currentVisibility.dateModified;
    bool dateCreated = currentVisibility.dateCreated;
    bool attributes = currentVisibility.attributes;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.view_column, size: 24),
                  SizedBox(width: 8),
                  Text('Tùy chỉnh hiển thị cột'),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: const Text(
                        'Chọn các cột bạn muốn hiển thị trong chế độ xem chi tiết. '
                        'Cột "Tên" luôn được hiển thị và không thể tắt.',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    CheckboxListTile(
                      title: const Text('Kích thước'),
                      subtitle: const Text('Hiển thị kích thước của file'),
                      value: size,
                      onChanged: (value) {
                        setState(() {
                          size = value ?? true;
                        });
                      },
                      secondary: const Icon(Icons.storage),
                      dense: true,
                    ),
                    const Divider(height: 1),
                    CheckboxListTile(
                      title: const Text('Loại'),
                      subtitle:
                          const Text('Hiển thị loại tệp tin (PDF, Word, v.v.)'),
                      value: type,
                      onChanged: (value) {
                        setState(() {
                          type = value ?? true;
                        });
                      },
                      secondary: const Icon(Icons.description),
                      dense: true,
                    ),
                    const Divider(height: 1),
                    CheckboxListTile(
                      title: const Text('Ngày sửa đổi'),
                      subtitle:
                          const Text('Hiển thị ngày giờ tệp được sửa đổi'),
                      value: dateModified,
                      onChanged: (value) {
                        setState(() {
                          dateModified = value ?? true;
                        });
                      },
                      secondary: const Icon(Icons.update),
                      dense: true,
                    ),
                    const Divider(height: 1),
                    CheckboxListTile(
                      title: const Text('Ngày tạo'),
                      subtitle: const Text('Hiển thị ngày giờ tệp được tạo ra'),
                      value: dateCreated,
                      onChanged: (value) {
                        setState(() {
                          dateCreated = value ?? false;
                        });
                      },
                      secondary: const Icon(Icons.calendar_today),
                      dense: true,
                    ),
                    const Divider(height: 1),
                    CheckboxListTile(
                      title: const Text('Thuộc tính'),
                      subtitle:
                          const Text('Hiển thị thuộc tính tệp (quyền đọc/ghi)'),
                      value: attributes,
                      onChanged: (value) {
                        setState(() {
                          attributes = value ?? false;
                        });
                      },
                      secondary: const Icon(Icons.info_outline),
                      dense: true,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('HỦY'),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.check),
                  label: const Text('ÁP DỤNG'),
                  onPressed: () {
                    final newVisibility = ColumnVisibility(
                      size: size,
                      type: type,
                      dateModified: dateModified,
                      dateCreated: dateCreated,
                      attributes: attributes,
                    );
                    onApply(newVisibility);
                    Navigator.pop(context);
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Xây dựng menu "Thêm tùy chọn"
  static Widget buildMoreOptionsMenu({
    required VoidCallback onSelectionModeToggled,
    VoidCallback? onManageTagsPressed,
    Function(String)? onGallerySelected,
    String? currentPath,
  }) {
    return PopupMenuButton<String>(
      icon: const Icon(EvaIcons.moreVerticalOutline),
      tooltip: 'Thêm tùy chọn',
      itemBuilder: (context) {
        List<PopupMenuEntry<String>> items = [
          const PopupMenuItem<String>(
            value: 'selection_mode',
            child: Row(
              children: [
                Icon(EvaIcons.checkmarkSquare2Outline, size: 20),
                SizedBox(width: 10),
                Text('Chọn nhiều file'),
              ],
            ),
          ),
        ];

        // Only show tag management if the callback is provided
        if (onManageTagsPressed != null) {
          items.add(
            const PopupMenuItem<String>(
              value: 'manage_tags',
              child: Row(
                children: [
                  Icon(EvaIcons.bookmarkOutline, size: 20),
                  SizedBox(width: 10),
                  Text('Quản lý thẻ'),
                ],
              ),
            ),
          );
        }

        // Only show gallery options if the callback and path are provided
        if (onGallerySelected != null && currentPath != null) {
          items.add(const PopupMenuDivider());
          items.add(
            const PopupMenuItem<String>(
              value: 'image_gallery',
              child: Row(
                children: [
                  Icon(EvaIcons.imageOutline, size: 20),
                  SizedBox(width: 10),
                  Text('Xem thư viện ảnh'),
                ],
              ),
            ),
          );
          items.add(
            const PopupMenuItem<String>(
              value: 'video_gallery',
              child: Row(
                children: [
                  Icon(EvaIcons.videoOutline, size: 20),
                  SizedBox(width: 10),
                  Text('Xem thư viện video'),
                ],
              ),
            ),
          );
        }

        return items;
      },
      onSelected: (String value) {
        switch (value) {
          case 'selection_mode':
            onSelectionModeToggled();
            break;
          case 'manage_tags':
            if (onManageTagsPressed != null) {
              onManageTagsPressed();
            }
            break;
          case 'image_gallery':
            if (onGallerySelected != null && currentPath != null) {
              onGallerySelected('image_gallery');
            }
            break;
          case 'video_gallery':
            if (onGallerySelected != null && currentPath != null) {
              onGallerySelected('video_gallery');
            }
            break;
        }
      },
    );
  }

  /// Xây dựng danh sách action cho app bar
  static List<Widget> buildCommonActions({
    required BuildContext context,
    required VoidCallback onSearchPressed,
    required Function(SortOption) onSortOptionSelected,
    required SortOption currentSortOption,
    required ViewMode viewMode,
    required VoidCallback onViewModeToggled,
    required VoidCallback onRefresh,
    VoidCallback? onGridSizePressed,
    VoidCallback? onColumnSettingsPressed,
    required VoidCallback onSelectionModeToggled,
    VoidCallback? onManageTagsPressed,
    Function(String)? onGallerySelected,
    String? currentPath,
    Function(ViewMode)? onViewModeSelected,
  }) {
    List<Widget> actions = [];

    // Thêm nút tìm kiếm
    actions.add(
      IconButton(
        icon: const Icon(EvaIcons.search),
        tooltip: 'Tìm kiếm',
        onPressed: onSearchPressed,
      ),
    );

    // Thêm nút sắp xếp
    actions.add(
      PopupMenuButton<SortOption>(
        icon: const Icon(EvaIcons.options2Outline),
        tooltip: 'Sắp xếp theo',
        initialValue: currentSortOption,
        onSelected: onSortOptionSelected,
        itemBuilder: (context) => [
          buildSortMenuItem(context, SortOption.nameAsc, 'Tên (A → Z)',
              EvaIcons.textOutline, currentSortOption),
          buildSortMenuItem(context, SortOption.nameDesc, 'Tên (Z → A)',
              EvaIcons.textOutline, currentSortOption),
          const PopupMenuDivider(),
          buildSortMenuItem(
              context,
              SortOption.dateAsc,
              'Ngày sửa (Cũ nhất trước)',
              EvaIcons.calendarOutline,
              currentSortOption),
          buildSortMenuItem(
              context,
              SortOption.dateDesc,
              'Ngày sửa (Mới nhất trước)',
              EvaIcons.calendarOutline,
              currentSortOption),
          const PopupMenuDivider(),
          buildSortMenuItem(context, SortOption.dateCreatedAsc,
              'Ngày tạo (Cũ nhất trước)', EvaIcons.clock, currentSortOption),
          buildSortMenuItem(context, SortOption.dateCreatedDesc,
              'Ngày tạo (Mới nhất trước)', EvaIcons.clock, currentSortOption),
          buildSortMenuItem(
              context,
              SortOption.sizeAsc,
              'Kích thước (Nhỏ nhất trước)',
              EvaIcons.activity,
              currentSortOption),
          buildSortMenuItem(
              context,
              SortOption.sizeDesc,
              'Kích thước (Lớn nhất trước)',
              EvaIcons.activity,
              currentSortOption),
          const PopupMenuDivider(),
          buildSortMenuItem(context, SortOption.typeAsc, 'Loại tệp (A → Z)',
              EvaIcons.fileOutline, currentSortOption),
          buildSortMenuItem(context, SortOption.typeDesc, 'Loại tệp (Z → A)',
              EvaIcons.fileOutline, currentSortOption),
          const PopupMenuDivider(),
          buildSortMenuItem(context, SortOption.extensionAsc,
              'Đuôi tệp (A → Z)', EvaIcons.atOutline, currentSortOption),
          buildSortMenuItem(context, SortOption.extensionDesc,
              'Đuôi tệp (Z → A)', EvaIcons.atOutline, currentSortOption),
          const PopupMenuDivider(),
          buildSortMenuItem(context, SortOption.attributesAsc,
              'Thuộc tính (A → Z)', EvaIcons.infoOutline, currentSortOption),
          buildSortMenuItem(context, SortOption.attributesDesc,
              'Thuộc tính (Z → A)', EvaIcons.infoOutline, currentSortOption),
        ],
      ),
    );

    // Thêm nút điều chỉnh kích thước lưới nếu đang ở chế độ lưới
    if (viewMode == ViewMode.grid && onGridSizePressed != null) {
      actions.add(
        IconButton(
          icon: const Icon(EvaIcons.gridOutline),
          tooltip: 'Điều chỉnh kích thước lưới',
          onPressed: onGridSizePressed,
        ),
      );
    }

    // Thêm nút điều chỉnh hiển thị cột nếu đang ở chế độ chi tiết
    if (viewMode == ViewMode.details && onColumnSettingsPressed != null) {
      actions.add(
        IconButton(
          icon: const Icon(EvaIcons.layoutOutline),
          tooltip: 'Thiết lập hiển thị cột',
          onPressed: onColumnSettingsPressed,
        ),
      );
    }

    // Thêm nút chuyển đổi chế độ xem
    actions.add(
      PopupMenuButton<ViewMode>(
        icon: const Icon(EvaIcons.eyeOutline),
        tooltip: 'Chế độ xem',
        initialValue: viewMode,
        itemBuilder: (context) => [
          PopupMenuItem<ViewMode>(
            value: ViewMode.list,
            child: Row(
              children: [
                Icon(
                  EvaIcons.listOutline,
                  size: 20,
                  color: viewMode == ViewMode.list ? Colors.blue : null,
                ),
                const SizedBox(width: 10),
                Text(
                  'Danh sách',
                  style: TextStyle(
                    fontWeight: viewMode == ViewMode.list
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: viewMode == ViewMode.list ? Colors.blue : null,
                  ),
                ),
                const Spacer(),
                if (viewMode == ViewMode.list)
                  const Icon(EvaIcons.checkmark, color: Colors.blue, size: 20),
              ],
            ),
          ),
          PopupMenuItem<ViewMode>(
            value: ViewMode.grid,
            child: Row(
              children: [
                Icon(
                  EvaIcons.gridOutline,
                  size: 20,
                  color: viewMode == ViewMode.grid ? Colors.blue : null,
                ),
                const SizedBox(width: 10),
                Text(
                  'Lưới',
                  style: TextStyle(
                    fontWeight: viewMode == ViewMode.grid
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: viewMode == ViewMode.grid ? Colors.blue : null,
                  ),
                ),
                const Spacer(),
                if (viewMode == ViewMode.grid)
                  const Icon(EvaIcons.checkmark, color: Colors.blue, size: 20),
              ],
            ),
          ),
          PopupMenuItem<ViewMode>(
            value: ViewMode.details,
            child: Row(
              children: [
                Icon(
                  EvaIcons.listOutline,
                  size: 20,
                  color: viewMode == ViewMode.details ? Colors.blue : null,
                ),
                const SizedBox(width: 10),
                Text(
                  'Chi tiết',
                  style: TextStyle(
                    fontWeight: viewMode == ViewMode.details
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: viewMode == ViewMode.details ? Colors.blue : null,
                  ),
                ),
                const Spacer(),
                if (viewMode == ViewMode.details)
                  const Icon(EvaIcons.checkmark, color: Colors.blue, size: 20),
              ],
            ),
          ),
        ],
        onSelected: (ViewMode selectedMode) {
          if (selectedMode != viewMode) {
            if (onViewModeSelected != null) {
              onViewModeSelected(selectedMode);
            } else {
              onViewModeToggled();
            }
          }
        },
      ),
    );

    // Thêm nút làm mới
    actions.add(
      IconButton(
        icon: const Icon(EvaIcons.refresh),
        tooltip: 'Làm mới',
        onPressed: onRefresh,
      ),
    );

    // Thêm menu tùy chọn khác
    actions.add(buildMoreOptionsMenu(
      onSelectionModeToggled: onSelectionModeToggled,
      onManageTagsPressed: onManageTagsPressed,
      onGallerySelected: onGallerySelected,
      currentPath: currentPath,
    ));

    return actions;
  }
}
