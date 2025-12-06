import 'package:flutter/material.dart';
import '../../screens/folder_list/folder_list_state.dart';
import '../../../helpers/core/user_preferences.dart';
import 'package:remixicon/remixicon.dart' as remix;
import '../../../config/app_theme.dart';
import '../../../config/languages/app_localizations.dart';

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
            const Icon(remix.Remix.check_line, color: Colors.blue, size: 20),
        ],
      ),
    );
  }

  static void showGridSizeDialog(
    BuildContext context, {
    required int currentGridSize,
    required Function(int) onApply,
  }) {
    int size = currentGridSize;
    final l10n = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            title: Text(l10n.adjustGridSizeTitle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Slider(
                  value: size.toDouble(),
                  min: UserPreferences.minGridZoomLevel.toDouble(),
                  max: UserPreferences.maxGridZoomLevel.toDouble(),
                  divisions: UserPreferences.maxGridZoomLevel -
                      UserPreferences.minGridZoomLevel,
                  label: l10n.gridSizeLabel(size.round()),
                  onChanged: (double value) {
                    setState(() {
                      size = value.round();
                    });
                  },
                ),
                Text(
                  l10n.gridSizeInstructions,
                  style: const TextStyle(
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
                child: Text(l10n.cancel.toUpperCase()),
              ),
              TextButton(
                onPressed: () {
                  onApply(size);
                  Navigator.pop(context);
                },
                child: Text(l10n.apply),
              ),
            ],
          );
        });
      },
    );
  }

  static void showColumnVisibilityDialog(
    BuildContext context, {
    required ColumnVisibility currentVisibility,
    required Function(ColumnVisibility) onApply,
  }) {
    final l10n = AppLocalizations.of(context)!;
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
              title: Row(
                children: [
                  const Icon(remix.Remix.layout_column_line, size: 24),
                  const SizedBox(width: 8),
                  Text(l10n.columnVisibilityTitle),
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
                        color: AppTheme.primaryBlue,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Text(
                        l10n.columnVisibilityInstructions,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    CheckboxListTile(
                      title: Text(l10n.columnSize),
                      subtitle: Text(l10n.columnSizeDescription),
                      value: size,
                      onChanged: (value) {
                        setState(() {
                          size = value ?? true;
                        });
                      },
                      secondary: const Icon(remix.Remix.hard_drive_2_line),
                      dense: true,
                    ),
                    const Divider(height: 1),
                    CheckboxListTile(
                      title: Text(l10n.columnType),
                      subtitle: Text(l10n.columnTypeDescription),
                      value: type,
                      onChanged: (value) {
                        setState(() {
                          type = value ?? true;
                        });
                      },
                      secondary: const Icon(remix.Remix.file_text_line),
                      dense: true,
                    ),
                    const Divider(height: 1),
                    CheckboxListTile(
                      title: Text(l10n.columnDateModified),
                      subtitle: Text(l10n.columnDateModifiedDescription),
                      value: dateModified,
                      onChanged: (value) {
                        setState(() {
                          dateModified = value ?? true;
                        });
                      },
                      secondary: const Icon(remix.Remix.refresh_line),
                      dense: true,
                    ),
                    const Divider(height: 1),
                    CheckboxListTile(
                      title: Text(l10n.columnDateCreated),
                      subtitle: Text(l10n.columnDateCreatedDescription),
                      value: dateCreated,
                      onChanged: (value) {
                        setState(() {
                          dateCreated = value ?? false;
                        });
                      },
                      secondary: const Icon(remix.Remix.calendar_line),
                      dense: true,
                    ),
                    const Divider(height: 1),
                    CheckboxListTile(
                      title: Text(l10n.columnAttributes),
                      subtitle: Text(l10n.columnAttributesDescription),
                      value: attributes,
                      onChanged: (value) {
                        setState(() {
                          attributes = value ?? false;
                        });
                      },
                      secondary: const Icon(remix.Remix.information_line),
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
                  child: Text(l10n.cancel.toUpperCase()),
                ),
                ElevatedButton.icon(
                  icon: const Icon(remix.Remix.check_line),
                  label: Text(l10n.apply),
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

  static Widget buildMoreOptionsMenu({
    required VoidCallback onSelectionModeToggled,
    VoidCallback? onManageTagsPressed,
    Function(String)? onGallerySelected,
    String? currentPath,
  }) {
    return Builder(
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return PopupMenuButton<String>(
          icon: const Icon(remix.Remix.more_2_line),
          tooltip: l10n.moreOptionsTooltip,
          offset: const Offset(0, 50),
          itemBuilder: (context) {
            List<PopupMenuEntry<String>> items = [
              PopupMenuItem<String>(
                value: 'selection_mode',
                child: Row(
                  children: [
                    const Icon(remix.Remix.checkbox_line, size: 20),
                    const SizedBox(width: 10),
                    Text(l10n.selectMultipleFiles),
                  ],
                ),
              ),
            ];

            // Only show tag management if the callback is provided
            if (onManageTagsPressed != null) {
              items.add(
                PopupMenuItem<String>(
                  value: 'manage_tags',
                  child: Row(
                    children: [
                      const Icon(remix.Remix.bookmark_line, size: 20),
                      const SizedBox(width: 10),
                      Text(l10n.manageTags),
                    ],
                  ),
                ),
              );
            }

            // Only show gallery options if the callback and path are provided
            if (onGallerySelected != null && currentPath != null) {
              items.add(const PopupMenuDivider());
              items.add(
                PopupMenuItem<String>(
                  value: 'image_gallery',
                  child: Row(
                    children: [
                      const Icon(remix.Remix.image_line, size: 20),
                      const SizedBox(width: 10),
                      Text(l10n.viewImageGallery),
                    ],
                  ),
                ),
              );
              items.add(
                PopupMenuItem<String>(
                  value: 'video_gallery',
                  child: Row(
                    children: [
                      const Icon(remix.Remix.video_line, size: 20),
                      const SizedBox(width: 10),
                      Text(l10n.viewVideoGallery),
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
      },
    );
  }

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
    final l10n = AppLocalizations.of(context)!;
    List<Widget> actions = [];

    // Add search button
    actions.add(
      IconButton(
        icon: const Icon(remix.Remix.search_line),
        tooltip: l10n.searchTooltip,
        onPressed: onSearchPressed,
      ),
    );

    // Add sort button
    actions.add(
      PopupMenuButton<SortOption>(
        icon: const Icon(remix.Remix.settings_3_line),
        tooltip: l10n.sortByTooltip,
        offset: const Offset(0, 50),
        initialValue: currentSortOption,
        onSelected: onSortOptionSelected,
        itemBuilder: (context) => [
          buildSortMenuItem(context, SortOption.nameAsc, l10n.sortNameAsc,
              remix.Remix.file_text_line, currentSortOption),
          buildSortMenuItem(context, SortOption.nameDesc, l10n.sortNameDesc,
              remix.Remix.file_text_line, currentSortOption),
          const PopupMenuDivider(),
          buildSortMenuItem(
              context,
              SortOption.dateAsc,
              l10n.sortDateModifiedOldest,
              remix.Remix.calendar_line,
              currentSortOption),
          buildSortMenuItem(
              context,
              SortOption.dateDesc,
              l10n.sortDateModifiedNewest,
              remix.Remix.calendar_line,
              currentSortOption),
          const PopupMenuDivider(),
          buildSortMenuItem(
              context,
              SortOption.dateCreatedAsc,
              l10n.sortDateCreatedOldest,
              remix.Remix.time_line,
              currentSortOption),
          buildSortMenuItem(
              context,
              SortOption.dateCreatedDesc,
              l10n.sortDateCreatedNewest,
              remix.Remix.time_line,
              currentSortOption),
          buildSortMenuItem(
              context,
              SortOption.sizeAsc,
              l10n.sortSizeSmallest,
              remix.Remix.pulse_line,
              currentSortOption),
          buildSortMenuItem(
              context,
              SortOption.sizeDesc,
              l10n.sortSizeLargest,
              remix.Remix.pulse_line,
              currentSortOption),
          const PopupMenuDivider(),
          buildSortMenuItem(context, SortOption.typeAsc, l10n.sortTypeAsc,
              remix.Remix.file_3_line, currentSortOption),
          buildSortMenuItem(context, SortOption.typeDesc, l10n.sortTypeDesc,
              remix.Remix.file_3_line, currentSortOption),
          const PopupMenuDivider(),
          buildSortMenuItem(context, SortOption.extensionAsc,
              l10n.sortExtensionAsc, remix.Remix.at_line, currentSortOption),
          buildSortMenuItem(context, SortOption.extensionDesc,
              l10n.sortExtensionDesc, remix.Remix.at_line, currentSortOption),
          const PopupMenuDivider(),
          buildSortMenuItem(
              context,
              SortOption.attributesAsc,
              l10n.sortAttributesAsc,
              remix.Remix.information_line,
              currentSortOption),
          buildSortMenuItem(
              context,
              SortOption.attributesDesc,
              l10n.sortAttributesDesc,
              remix.Remix.information_line,
              currentSortOption),
        ],
      ),
    );

    // Add grid size button if in grid mode
    if (viewMode == ViewMode.grid && onGridSizePressed != null) {
      actions.add(
        IconButton(
          icon: const Icon(remix.Remix.grid_line),
          tooltip: l10n.adjustGridSizeTooltip,
          onPressed: onGridSizePressed,
        ),
      );
    }

    // Add column settings button if in details mode
    if (viewMode == ViewMode.details && onColumnSettingsPressed != null) {
      actions.add(
        IconButton(
          icon: const Icon(remix.Remix.layout_line),
          tooltip: l10n.columnSettingsTooltip,
          onPressed: onColumnSettingsPressed,
        ),
      );
    }

    // Add view mode toggle button
    actions.add(
      PopupMenuButton<ViewMode>(
        icon: const Icon(remix.Remix.eye_line),
        tooltip: l10n.viewModeTooltip,
        offset: const Offset(0, 50),
        initialValue: viewMode,
        itemBuilder: (context) => [
          PopupMenuItem<ViewMode>(
            value: ViewMode.list,
            child: Row(
              children: [
                Icon(
                  remix.Remix.menu_2_line,
                  size: 20,
                  color: viewMode == ViewMode.list ? Colors.blue : null,
                ),
                const SizedBox(width: 10),
                Text(
                  l10n.viewModeList,
                  style: TextStyle(
                    fontWeight: viewMode == ViewMode.list
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: viewMode == ViewMode.list ? Colors.blue : null,
                  ),
                ),
                const Spacer(),
                if (viewMode == ViewMode.list)
                  const Icon(remix.Remix.check_line,
                      color: Colors.blue, size: 20),
              ],
            ),
          ),
          PopupMenuItem<ViewMode>(
            value: ViewMode.grid,
            child: Row(
              children: [
                Icon(
                  remix.Remix.grid_line,
                  size: 20,
                  color: viewMode == ViewMode.grid ? Colors.blue : null,
                ),
                const SizedBox(width: 10),
                Text(
                  l10n.viewModeGrid,
                  style: TextStyle(
                    fontWeight: viewMode == ViewMode.grid
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: viewMode == ViewMode.grid ? Colors.blue : null,
                  ),
                ),
                const Spacer(),
                if (viewMode == ViewMode.grid)
                  const Icon(remix.Remix.check_line,
                      color: Colors.blue, size: 20),
              ],
            ),
          ),
          PopupMenuItem<ViewMode>(
            value: ViewMode.details,
            child: Row(
              children: [
                Icon(
                  remix.Remix.list_unordered,
                  size: 20,
                  color: viewMode == ViewMode.details ? Colors.blue : null,
                ),
                const SizedBox(width: 10),
                Text(
                  l10n.viewModeDetails,
                  style: TextStyle(
                    fontWeight: viewMode == ViewMode.details
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: viewMode == ViewMode.details ? Colors.blue : null,
                  ),
                ),
                const Spacer(),
                if (viewMode == ViewMode.details)
                  const Icon(remix.Remix.check_line,
                      color: Colors.blue, size: 20),
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

    // Add refresh button
    actions.add(
      IconButton(
        icon: const Icon(remix.Remix.refresh_line),
        tooltip: l10n.refreshTooltip,
        onPressed: onRefresh,
      ),
    );

    // Add more options menu
    actions.add(buildMoreOptionsMenu(
      onSelectionModeToggled: onSelectionModeToggled,
      onManageTagsPressed: onManageTagsPressed,
      onGallerySelected: onGallerySelected,
      currentPath: currentPath,
    ));

    return actions;
  }
}
