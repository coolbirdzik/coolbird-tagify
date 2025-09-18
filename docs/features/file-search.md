# File Search Feature Documentation

## Overview

File search enables users to quickly locate files and folders using search bars and result components. Performance depends on database indexing and directory size.

## Key Files & Entry Points

- helpers_core_filesystem_utils
- ui_tab_manager_components_search_bar
- ui_tab_manager_components_search_results

## Architecture & Integration

- Integrated with ObjectBox for fast queries
- UI search bar triggers search logic in helpers
- Results displayed in tab manager components

## Technical Debt & Known Issues

- Performance may degrade with large directories
- Indexing strategies can be improved

## Workarounds & Gotchas

- For best performance, keep database indexes up-to-date
- Large directory searches may be slow

## Testing

- Unit tests in test/ (coverage varies)
- Manual testing for large directories

## Success Criteria

## Database & Persistence

File search relies on ObjectBox for fast data queries and persistent storage. All file metadata and search indexes are stored in ObjectBox models, ensuring quick access and durability. Backup and restore procedures should be followed as described in `database.md`.

## Settings & Configuration

Users can customize search behavior via the app settings. Options include search scope (local/network), result sorting, and indexing preferences. Settings are persisted using ObjectBox and can be restored after reinstall.

## Error Handling & Logging

All search operations are logged for debugging and audit purposes. Errors such as missing indexes, failed queries, or permission issues are captured in the log system. Refer to `logging.md` for troubleshooting steps and log file locations.

## Performance Optimization

Performance is optimized by maintaining up-to-date indexes and limiting search scope for large directories. Caching strategies and lazy loading are applied to reduce query time. For best results, schedule regular index updates and monitor performance metrics in the app dashboard.
