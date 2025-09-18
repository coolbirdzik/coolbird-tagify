# Coding Standards

## Purpose

Define consistent coding conventions for Flutter/Dart to improve readability, maintainability, and velocity.

## Language & Style

- Dart stable, follow Effective Dart
- Prefer null-safety, avoid `dynamic` unless unavoidable
- Use meaningful names; avoid abbreviations
- Small, single-responsibility functions

## Project Conventions

- State management: follow existing BLoC patterns in `lib/bloc/`
- Config lives in `lib/config/`
- Helpers/utilities in `lib/helpers/` with clear separation
- UI widgets in `lib/ui/` grouped by feature/screen

## Widgets & UI

- Keep widgets pure; lift state to BLoC where appropriate
- Extract reusable widgets into `ui/components`
- Maintain consistent spacing, typography, and theming

## Error Handling

- Use explicit error types; avoid swallowing exceptions
- Wrap external calls and surface user-friendly messages

## Async & Streams

- Prefer `await`/`async` over chained futures
- Close streams and controllers; avoid leaks

## Testing

- Unit tests for helpers, services, blocs
- Golden tests for critical UI where feasible

## Linting

- Enforce `analysis_options.yaml`
- Fix warnings before commit

## Commit Messages

- Conventional Commits (feat, fix, docs, refactor, test, chore)

## Documentation

- Document public APIs (///)
- Keep `docs/` updated alongside changes
