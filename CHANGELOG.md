## [Unreleased]

## [0.3.0] - 2026-10-14

### Fixed

- Replacing a legacy `annotate` block above a `module`-wrapped class no longer deletes the rest of the file
- Never write into model files outside the application (engines, gems, `vendor/`); skip anonymous classes and HABTM join models
- MySQL, Trilogy and SQLite no longer crash on PostgreSQL-only enum queries; SQLite triggers are now listed
- Check constraints are skipped on adapters/Rails versions that don't support them
- Models on a secondary database are annotated from their own connection
- `rake "annotato:models[User,Post]"` annotates every listed model; unknown names are skipped with a warning
- Columns whose only unique index is partial are marked `unique (partial)` instead of `unique`
- JSON defaults are rendered as valid JSON (numbers, nested values, `null`, escaped quotes)
- Tables without columns no longer crash; SQL is never wrapped inside a quoted literal

### Added

- `rake annotato:check` for CI: fails when annotations are missing or outdated
- Database function defaults (`default(now())`), generated columns (`generated(...)`), table comments, index method / order / `INCLUDE` / `NULLS NOT DISTINCT`
- `MODEL` environment variable for `annotato:models`
- `ANNOTATO_SKIP=1` to disable automatic annotation after migrations

### Changed

- Automatic annotation after migrations now runs only in development, and also after `db:rollback` and per-database migrate tasks
- Model files are written atomically
- Depends on `activerecord` and `railties` (>= 6.1) instead of the whole `rails` gem

## [0.1.0] - 2025-05-16

- Initial release
