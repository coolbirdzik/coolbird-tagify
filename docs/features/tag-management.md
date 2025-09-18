# Tag Management Feature Documentation

## Overview

Tag management allows users to organize files with custom tags, colors, and batch operations. Relies on ObjectBox for persistence.

## Key Files & Entry Points

- helpers_tags_tag_manager
- ui*screens_tag_management*\*
- models_objectbox_file_tag

## Architecture & Integration

- Custom color manager and batch tag manager
- UI screens for tag creation, editing, and batch operations
- Data stored in ObjectBox models

## Technical Debt & Known Issues

- Initialization order is critical for color manager
- Some modules lack detailed documentation

## Workarounds & Gotchas

- Always initialize color manager before batch operations

## Testing

- Unit tests in test/ (coverage varies)
- Manual testing for batch operations

## Success Criteria

- Reliable tag creation and editing
- Batch operations work as expected
- No regressions in tag functionality
