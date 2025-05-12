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
      icon: const Icon(EvaIcons.moreVertical),
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
                Icon(EvaIcons.imageOutline, size: 20),
                SizedBox(width: 8),
                Text('Thư viện ảnh'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'video_gallery',
            child: Row(
              children: [
                Icon(EvaIcons.videoOutline, size: 20),
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
          const PopupMenuDivider(),
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

    // Thêm nút chuyển đổi chế độ xem
    actions.add(
      IconButton(
        icon: Icon(viewMode == ViewMode.grid
            ? EvaIcons.listOutline
            : EvaIcons.gridOutline),
        tooltip: viewMode == ViewMode.grid ? 'Chế độ danh sách' : 'Chế độ lưới',
        onPressed: onViewModeToggled,
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
