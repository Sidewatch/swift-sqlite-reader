# Audit log

Last full audit: **17 Sep 2026** — every source file covered by the MECHANICAL checks below (build warnings, tests,
dead-code and risk-pattern scans, docs drift); line-by-line logic review was targeted at the areas changed since
5 Sep 2026, not the whole tree. Nothing needs re-scanning unless it changed after that date. Add a dated line under *History* when you audit again, and keep the
*Known non-issues* list current so the next pass skips them.

## What a full audit checks

1. `swift build` warnings (none allowed except those listed under known non-issues) and `swift test` green.
2. Dead code: every `func`/type/property declared once and referenced nowhere in the app or the family
   (`grep -w` across `*.swift` AND non-Swift files — selectors and MCP names live in strings). Protocol
   requirements, `override`s, `@objc` actions and public API are NOT dead because Sidewatch does not call them.
3. Risky patterns: `Timer` without `invalidate`, `addObserver(forName:)` without `removeObserver`, `as!`, `try!`
   outside literal regexes, `fatalError` outside `init?(coder:)`, `print(` outside harnesses, TODO/FIXME left behind.
4. Docs drift: every name in CLAUDE.md's module map exists; AGENTS.md mirrors CLAUDE.md; README Usage matches the API.

## Result on 17 Sep 2026

- Build: clean. Tests: green.
- Nothing to fix in this package.

## Logic review — 18 Sep 2026 (every source and test file, line by line)

Nothing to fix. Checked: every prepared statement is finalized on every path (`defer`, and the
multi-statement tail); the read-write open falling back to read-only; the in-memory open; `deinit`
closing the handle; value mapping per column type including NULL and blobs; the column and
foreign-key pragmas.

## Security review — 9 Oct 2026

- **A `.sql` file could reach a database on disk.** `SQLiteDB(sql:)` opened `:memory:` read-write
  and ran every statement of the text, so `ATTACH DATABASE '/path/victim.db' AS v; DELETE FROM
  v.users` emptied a real database when a schema file was previewed or diffed. Now
  `SchemaAuthorizer` (Support/) is installed on the connection for its life: `SQLITE_LIMIT_ATTACHED`
  is 0 and `sqlite3_set_authorizer` allows CREATE TABLE/INDEX/VIEW/TRIGGER (temp too), ALTER TABLE,
  REINDEX (a CREATE INDEX ends in one), READ/SELECT/FUNCTION/TRANSACTION/SAVEPOINT/RECURSIVE, data
  writes only on SQLite's own `sqlite_*` catalogue tables (CREATE and ALTER write them), and the
  schema-reading pragmas (`table_info`, `index_list`, `index_info`, `foreign_key_list`, …); it
  denies ATTACH, DETACH, every DROP, INSERT/UPDATE/DELETE on user tables and everything else with
  `not authorized`. Which action codes a schema raises was measured with a logging authorizer
  before the whitelist was written. `SchemaAuthorizerTests`: the victim keeps its rows and a later
  ATTACH is `not authorized`; writes and drops refused in the script and after; every schema form
  still builds and reads; the verdict table. Mutant: the install line removed — 11 failures (the
  victim emptied, the INSERT ran, the DROP ran, `writable_schema` allowed). Mutant: the
  `sqlite3_limit` line removed — `attachedDatabaseLimit` is no longer 0.
- Consequence recorded: a dump's `INSERT` rows no longer populate the in-memory build
  (`testAPostgresDumpsSchemaQualifiedNamesBuildTheirTables` asserts 0 rows now); the reader's own
  query/edit/binding tests moved onto a temporary-file fixture (`scratch(_:)`), which is what they
  were about.

## Known non-issues (do not "fix" these again)

- `SQLiteDB(url:)` opens READWRITE without CREATE: a harness that wants a scratch database must create the (empty) file first.
- `SQLiteDB(sql:)` refuses data writes by design (see the 9 Oct 2026 entry); do not relax it for a dump's rows.

## History

- 17 Sep 2026 — full audit (app + all 20 libraries), Claude with David.
- 18 Sep 2026 — logic review (every source and test file, line by line), Claude with David.
- 9 Oct 2026 — security review: `SchemaAuthorizer` on every script-built connection (see the section above); 36 tests.
