# Swift SQLite Reader

A tiny, zero-dependency wrapper over the system `libsqlite3` for **reading and introspecting** a SQLite database — tables, schema, foreign keys, row counts, and ad-hoc queries — with values stringified for display. Ideal for database viewers, schema diagrams, and tooling; not a typed ORM.

- Module `SQLiteReader` in `Sources/SQLiteReader`; tests in `Tests`; `swift test` is the whole check.
- Swift 6 language mode, tools 6.2, macOS 14+, no dependencies unless the README says so.
- Part of the Sidewatch package family; every package follows the same layout and PR rules.

## Module map

- `Core/` — the engine: SQLiteDB
- `Models/` — value types — the shape of a thing, nothing else: SQLiteDB+Column, SQLiteDB+ForeignKey, SQLiteDB+Result (display `rows` and typed `cells`, kept in step by SQLiteDB+Result+Rows: `reordered`, `droppingFirstColumn`, `replacingRow`, `appendingFirstRow`), SQLiteDB+Cell (a cell as SQLite stored it; blobs keep their bytes up to `keptBlobBytes`, 64 KB, and `keptBlobTotal`, 16 MB a result), SQLiteDB+Value
- `Support/` — pure helpers: SQLiteDB+Insert (`insertStatements(into:columns:rows:)`, `literal(_:)`: rows as INSERT statements that put the same cells back), SchemaAuthorizer (the rule a script-built connection runs under: CREATE/ALTER and schema reads pass; ATTACH, DETACH, DROP and data writes are refused)

## Rules

Read `CONTRIBUTING.md` for the folder layout and the pull-request rules.

@CONTRIBUTING.md

- **Auditing? Read `AUDIT.md` first** — what the last full audit checked and fixed, and the known non-issues to skip; extend it, do not redo it.
