# Testing Strategy

## Goals

- Fast feedback, reliable coverage, and protection against regressions.

## Test Pyramid

- Unit: majority focus (helpers, services, blocs)
- Widget: key components and flows
- Integration: service boundaries (e.g., storage, network)
- E2E (optional): smoke paths on target platforms

## What to Test

- Business logic in `lib/services/` and `lib/bloc/`
- Parsing/formatting helpers in `lib/helpers/`
- Critical UI states and navigation flows in `lib/ui/`

## Tooling

- `flutter test`
- Mocking with `mocktail` (or preferred lib)
- Golden tests using `flutter_test` + `golden_toolkit` (optional)

## Data & Fixtures

- Use lightweight fixtures; keep deterministic
- Avoid network; use fakes/mocks

## CI Recommendations

- Run unit+widget tests on PR
- Optional nightly integration/E2E

## Coverage Targets

- Baseline 70%+, raise over time

## Test Organization

- Mirror `lib/` structure under `test/`
- Name tests `<file>_test.dart`

## Non-Functional

- Performance checks for heavy lists/streams
- Reliability: retry/backoff logic
