# Database Feature Documentation

## Overview

Database functionality uses ObjectBox for local storage of tags, user preferences, and other data models.

## Key Files & Entry Points

## Architecture & Integration

## Technical Debt & Known Issues

## Workarounds & Gotchas

## Testing

## Success Criteria

## Data Models

- Tag, user preference, file metadata models in `models/objectbox/`
- Extensible for new data types

## Provider & Access

- Access via `models/database/database_provider.dart`, `models/objectbox/objectbox_database_provider.dart`
- Transaction management for data integrity

## Backup & Restore

- Regularly backup database files to prevent data loss
- Restore procedures documented in `README_IMPLEMENTATION.md`

## Error Handling & Logging

- All database operations are logged
- Errors (e.g., failed transactions, data corruption) are surfaced in the UI
- Refer to `logging.md` for troubleshooting

## Performance Optimization

- Indexing and caching for fast queries
- Batch updates optimized for large data sets

## Best Practices

- Ensure ObjectBox is properly initialized before use
- Regularly backup database files
- Monitor logs for database errors
