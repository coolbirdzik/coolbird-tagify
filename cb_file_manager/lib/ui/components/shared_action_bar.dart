import 'package:flutter/material.dart';
import 'package:cb_file_manager/ui/screens/folder_list/folder_list_state.dart';
import 'package:cb_file_manager/helpers/user_preferences.dart';

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
            const Icon(Icons.check, color: Colors.blue, size: 20),
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
    int tempGridSize = currentGridSize;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Điều chỉnh kích thước lưới'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Số cột: $tempGridSize'),
                    Slider(
                      value: tempGridSize.toDouble(),
                      min: UserPreferences.minGridZoomLevel.toDouble(),
                      max: UserPreferences.maxGridZoomLevel.toDouble(),
                      divisions: (UserPreferences.maxGridZoomLevel -
                          UserPreferences.minGridZoomLevel),
                      label: tempGridSize.toString(),
                      onChanged: (double value) {
                        setState(() {
                          tempGridSize = value.round();
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildSizePreviewBox(2, tempGridSize),
                        _buildSizePreviewBox(4, tempGridSize),
                        _buildSizePreviewBox(8, tempGridSize),
                        _buildSizePreviewBox(12, tempGridSize),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Hình lớn', style: TextStyle(fontSize: 12)),
                        Text('Hình nhỏ', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Hủy'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                TextButton(
                  child: const Text('Áp dụng'),
                  onPressed: () {
                    onApply(tempGridSize);
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Widget hiển thị kích thước ô lưới mẫu
  static Widget _buildSizePreviewBox(int size, int currentSize) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            border: Border.all(
              color: currentSize == size ? Colors.blue : Colors.grey,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          child: GridView.count(
            crossAxisCount: size,
            mainAxisSpacing: 1,
            crossAxisSpacing: 1,
            physics: const NeverScrollableScrollPhysics(),
            children: List.generate(
              size * size,
              (index) => Container(
                color: Colors.grey[300],
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$size',
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  /// Tạo menu popup cho các tùy chọn khác
  static Widget buildMoreOptionsMenu({
    required VoidCallback onSelectionModeToggled,
    VoidCallback? onManageTagsPressed,
    Function(String)? onGallerySelected,
    String? currentPath,
  }) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      tooltip: 'Tùy chọn khác',
      onSelected: (value) {
        if (value == 'select') {
          onSelectionModeToggled();
        } else if (value == 'manage_tags' && onManageTagsPressed != null) {
          onManageTagsPressed();
        } else if ((value == 'image_gallery' || value == 'video_gallery') &&
            onGallerySelected != null) {
          onGallerySelected(value);
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'select',
          child: Text('Chọn các mục'),
        ),
        if (onManageTagsPressed != null)
          const PopupMenuItem(
            value: 'manage_tags',
            child: Text('Quản lý thẻ'),
          ),
        if (onGallerySelected != null && currentPath != null) ...[
          const PopupMenuItem(
            value: 'image_gallery',
            child: Row(
              children: [
                Icon(Icons.photo_library, size: 20),
                SizedBox(width: 8),
                Text('Thư viện ảnh'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'video_gallery',
            child: Row(
              children: [
                Icon(Icons.video_library, size: 20),
                SizedBox(width: 8),
                Text('Thư viện video'),
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// Tạo danh sách các action cho thanh công cụ
  static List<Widget> buildCommonActions({
    required BuildContext context,
    required VoidCallback onSearchPressed,
    required Function(SortOption) onSortOptionSelected,
    required SortOption currentSortOption,
    required ViewMode viewMode,
    required VoidCallback onViewModeToggled,
    required VoidCallback onRefresh,
    VoidCallback? onGridSizePressed,
    required VoidCallback onSelectionModeToggled,
    VoidCallback? onManageTagsPressed,
    Function(String)? onGallerySelected,
    String? currentPath,
  }) {
    List<Widget> actions = [];

    // Thêm nút tìm kiếm
    actions.add(
      IconButton(
        icon: const Icon(Icons.search),
        tooltip: 'Tìm kiếm',
        onPressed: onSearchPressed,
      ),
    );

    // Thêm nút sắp xếp
    actions.add(
      PopupMenuButton<SortOption>(
        icon: const Icon(Icons.sort),
        tooltip: 'Sắp xếp theo',
        initialValue: currentSortOption,
        onSelected: onSortOptionSelected,
        itemBuilder: (context) => [
          buildSortMenuItem(context, SortOption.nameAsc, 'Tên (A → Z)',
              Icons.sort_by_alpha, currentSortOption),
          buildSortMenuItem(context, SortOption.nameDesc, 'Tên (Z → A)',
              Icons.sort_by_alpha, currentSortOption),
          const PopupMenuDivider(),
          buildSortMenuItem(context, SortOption.dateAsc, 'Ngày (Cũ nhất trước)',
              Icons.calendar_today, currentSortOption),
          buildSortMenuItem(context, SortOption.dateDesc,
              'Ngày (Mới nhất trước)', Icons.calendar_today, currentSortOption),
          const PopupMenuDivider(),
          buildSortMenuItem(
              context,
              SortOption.sizeAsc,
              'Kích thước (Nhỏ nhất trước)',
              Icons.data_usage,
              currentSortOption),
          buildSortMenuItem(
              context,
              SortOption.sizeDesc,
              'Kích thước (Lớn nhất trước)',
              Icons.data_usage,
              currentSortOption),
          const PopupMenuDivider(),
          buildSortMenuItem(context, SortOption.typeAsc, 'Loại tệp (A → Z)',
              Icons.insert_drive_file, currentSortOption),
        ],
      ),
    );

    // Thêm nút điều chỉnh kích thước lưới nếu đang ở chế độ lưới
    if (viewMode == ViewMode.grid && onGridSizePressed != null) {
      actions.add(
        IconButton(
          icon: const Icon(Icons.grid_view_outlined),
          tooltip: 'Điều chỉnh kích thước lưới',
          onPressed: onGridSizePressed,
        ),
      );
    }

    // Thêm nút chuyển đổi chế độ xem
    actions.add(
      IconButton(
        icon: Icon(viewMode == ViewMode.grid ? Icons.list : Icons.grid_view),
        tooltip: viewMode == ViewMode.grid ? 'Chế độ danh sách' : 'Chế độ lưới',
        onPressed: onViewModeToggled,
      ),
    );

    // Thêm nút làm mới
    actions.add(
      IconButton(
        icon: const Icon(Icons.refresh),
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
