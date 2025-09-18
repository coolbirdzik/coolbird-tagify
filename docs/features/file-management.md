# File Management Feature Documentation

## Overview

File management in cb_file_manager covers file/folder operations, sorting, icon/type helpers, trash management, and batch actions. The system is modular and supports extensibility for new file types and operations.

## File & Folder Operations

- Create, rename, move, copy, delete files/folders
- Batch operations supported via UI and helpers
- Key files: `helpers/files/folder_sort_manager.dart`, `helpers/files/trash_manager.dart`

## Icon & Type Helpers

- File type detection and icon assignment
- Custom icons for Windows apps (`helpers/files/windows_app_icon.dart`)
- Extensible for new file types

## Sorting & Filtering

- Sort by name, date, size, type
- Filter by file type, tags, or custom criteria
- Sorting logic in `helpers/files/folder_sort_manager.dart`

## Trash Management

- Safe delete to trash bin
- Restore and permanent delete options
- Trash logic in `helpers/files/trash_manager.dart`, UI in `ui/screens/trash_bin/`

## Batch Operations

- Multi-select and batch actions in UI
- Efficient processing for large file sets

## Error Handling & Logging

- All file operations are logged
- Errors (e.g., permission denied, file not found) are surfaced in the UI
- Refer to `logging.md` for troubleshooting

## Performance Optimization

- Uses lazy loading and caching for large directories
- Batch operations optimized to minimize UI blocking

## Best Practices

- Validate file/folder names before operations
- Monitor logs for errors and failed operations

## Testing

- Unit tests for helpers and UI workflows
- Manual testing for edge cases and batch actions

## Success Criteria

- Reliable file/folder operations
- No regressions in sorting, icon, or trash features
- Consistent UI/UX for file management
