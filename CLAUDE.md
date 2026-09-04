# Swift SQLite Reader

A tiny, zero-dependency wrapper over the system `libsqlite3` for **reading and introspecting** a SQLite database — tables, schema, foreign keys, row counts, and ad-hoc queries — with values stringified for display. Ideal for database viewers, schema diagrams, and tooling; not a typed ORM.

- Module `SQLiteReader` in `Sources/SQLiteReader`; tests in `Tests`; `swift test` is the whole check.
- Swift 6 language mode, tools 6.2, macOS 14+, no dependencies unless the README says so.
- Part of the Sidewatch package family; every package follows the same layout and PR rules.

## Module map

- `Core/` — the engine: SQLiteDB
- `Models/` — value types — the shape of a thing, nothing else: SQLiteDB+Column, SQLiteDB+ForeignKey, SQLiteDB+Result, SQLiteDB+Value

## Rules

@CONTRIBUTING.md
