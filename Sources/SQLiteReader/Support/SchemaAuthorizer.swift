//
//  SchemaAuthorizer.swift
//  SQLiteReader
//
//  The authorizer a script-built database runs under: schema statements only.
//
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation
import SQLite3

/// Confines a connection built from SQL text to what a schema model needs. The text comes from a
/// file nobody vetted — a `schema.sql` in a checkout — and SQLite would otherwise run every
/// statement in it: an `ATTACH DATABASE '/path/real.db'` followed by a `DELETE` empties a real
/// database on disk. So the connection may hold no attached database at all
/// (`SQLITE_LIMIT_ATTACHED` 0) and every statement is judged first: CREATE, ALTER and the reads
/// that describe them pass; ATTACH, DETACH, DROP and data writes are refused with
/// `not authorized`. The connection stays confined for its life, so a later query through it
/// is held to the same rule.
enum SchemaAuthorizer {
    /// The pragmas a schema reader issues: table columns, indexes, foreign keys, the database list.
    static let readPragmas: Set<String> = [
        "table_info", "table_xinfo", "table_list", "index_list", "index_info", "index_xinfo",
        "foreign_key_list", "database_list",
    ]

    /// Installs the rule on `db`: no attached databases, and ``verdict(action:subject:)`` on
    /// every statement it compiles from now on.
    static func install(on db: OpaquePointer) {
        sqlite3_limit(db, SQLITE_LIMIT_ATTACHED, 0)
        sqlite3_set_authorizer(
            db,
            { _, action, first, _, _, _ in
                SchemaAuthorizer.verdict(action: action, subject: first.map { String(cString: $0) })
            }, nil)
    }

    /// `SQLITE_OK` or `SQLITE_DENY` for one authorizer call: `action` is the code, `subject` its
    /// first argument (a table, a pragma, a file to attach).
    static func verdict(action: Int32, subject: String?) -> Int32 {
        allows(action: action, subject: subject) ? SQLITE_OK : SQLITE_DENY
    }

    /// Whether a statement raising `action` on `subject` may run.
    ///
    /// Creating a table, index, view or trigger writes rows into `sqlite_master` and an ALTER
    /// rewrites them (and `sqlite_sequence`), so data writes are allowed on SQLite's own
    /// `sqlite_*` tables, which no script can name for a table of its own. `CREATE INDEX` ends in
    /// a `REINDEX`, so that passes too. Every other write, every DROP, ATTACH and DETACH, and a
    /// pragma that is not a read of the schema is refused.
    static func allows(action: Int32, subject: String?) -> Bool {
        switch action {
        case SQLITE_CREATE_INDEX, SQLITE_CREATE_TABLE, SQLITE_CREATE_TEMP_INDEX, SQLITE_CREATE_TEMP_TABLE,
            SQLITE_CREATE_TEMP_TRIGGER, SQLITE_CREATE_TEMP_VIEW, SQLITE_CREATE_TRIGGER, SQLITE_CREATE_VIEW,
            SQLITE_ALTER_TABLE, SQLITE_REINDEX:
            return true
        case SQLITE_READ, SQLITE_SELECT, SQLITE_FUNCTION, SQLITE_TRANSACTION, SQLITE_SAVEPOINT, SQLITE_RECURSIVE:
            return true
        case SQLITE_INSERT, SQLITE_UPDATE, SQLITE_DELETE:
            return subject?.lowercased().hasPrefix("sqlite_") == true
        case SQLITE_PRAGMA:
            return readPragmas.contains(subject?.lowercased() ?? "")
        default:
            return false
        }
    }
}
