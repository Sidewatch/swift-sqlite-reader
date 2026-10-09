//
//  SchemaAuthorizerTests.swift
//  SQLiteReaderTests
//
//  A script-built database runs schema statements and nothing that can reach outside it.
//
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import XCTest
import SQLite3
@testable import SQLiteReader

/// `SQLiteDB(sql:)` reads text nobody vetted. The connection may create and describe a schema;
/// it may not attach a database, drop anything, or write rows — in the script or afterwards.
final class SchemaAuthorizerTests: XCTestCase {
    private var files: [URL] = []

    override func tearDown() {
        files.forEach { try? FileManager.default.removeItem(at: $0) }
        super.tearDown()
    }

    /// A real database on disk with three users: the victim an `ATTACH` would reach.
    private func victim() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("victim-\(UUID().uuidString).db")
        files.append(url)
        var h: OpaquePointer?
        XCTAssertEqual(sqlite3_open_v2(url.path, &h, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, nil), SQLITE_OK)
        sqlite3_exec(
            h, "CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT); INSERT INTO users (name) VALUES ('a'),('b'),('c');", nil, nil, nil)
        sqlite3_close(h)
        return url
    }

    func testAttachIsRefusedAndTheVictimKeepsItsRows() throws {
        let victim = try victim()
        let path = victim.path.replacingOccurrences(of: "'", with: "''")
        let db = try XCTUnwrap(
            SQLiteDB(
                sql: """
                    CREATE TABLE a (x);
                    ATTACH DATABASE '\(path)' AS v;
                    DELETE FROM v.users;
                    UPDATE v.users SET name = 'gone';
                    """))
        XCTAssertEqual(db.tables(), ["a"], "the schema statement built; the rest was refused")
        XCTAssertEqual(try XCTUnwrap(SQLiteDB(url: victim, readOnly: true)).rowCount("users"), 3, "the victim is untouched")
        let later = db.run("ATTACH DATABASE '\(path)' AS v")
        XCTAssertEqual(later.error, "not authorized", "a later ATTACH through the same connection is refused by the authorizer")
        XCTAssertEqual(db.run("PRAGMA database_list").rows.count, 1, "main only — nothing attached")
        XCTAssertEqual(db.attachedDatabaseLimit, 0, "no attach slot exists, before the authorizer even judges")
    }

    func testDataWritesAndDropsAreRefusedInTheScriptAndAfter() throws {
        let db = try XCTUnwrap(
            SQLiteDB(
                sql: """
                    CREATE TABLE t (n INTEGER);
                    INSERT INTO t VALUES (1), (2);
                    UPDATE t SET n = 9;
                    DELETE FROM t;
                    CREATE TABLE keep (a);
                    DROP TABLE keep;
                    """))
        XCTAssertEqual(db.tables(), ["keep", "t"], "both tables stand; the DROP was refused")
        XCTAssertEqual(db.rowCount("t"), 0, "the INSERT was refused")
        XCTAssertEqual(db.run("INSERT INTO t VALUES (3)").error, "not authorized")
        XCTAssertEqual(db.run("DELETE FROM t").error, "not authorized")
        XCTAssertEqual(db.run("DROP TABLE keep").error, "not authorized")
        XCTAssertEqual(db.execute("UPDATE t SET n = ? WHERE rowid = ?", parameters: [.integer(1), .integer(1)]).error, "not authorized")
        XCTAssertEqual(db.tables(), ["keep", "t"])
    }

    func testEverySchemaStatementStillBuildsAndReads() throws {
        let db = try XCTUnwrap(
            SQLiteDB(
                sql: """
                    BEGIN TRANSACTION;
                    CREATE TABLE users (id INTEGER PRIMARY KEY AUTOINCREMENT, email TEXT NOT NULL UNIQUE, name TEXT);
                    CREATE TABLE posts (id INTEGER PRIMARY KEY, author_id INTEGER REFERENCES users(id), title TEXT);
                    CREATE INDEX posts_author ON posts(author_id);
                    CREATE UNIQUE INDEX posts_title ON posts(author_id, title);
                    CREATE VIEW adults AS SELECT * FROM users WHERE id > 1;
                    CREATE TRIGGER t AFTER INSERT ON users BEGIN INSERT INTO posts VALUES (1, NEW.id, 'x'); END;
                    ALTER TABLE users ADD COLUMN age INTEGER;
                    ALTER TABLE users RENAME TO people;
                    CREATE TEMP TABLE scratch (a);
                    COMMIT;
                    """))
        XCTAssertEqual(db.tables(), ["adults", "people", "posts"])
        XCTAssertEqual(db.schema("people").map(\.name), ["id", "email", "name", "age"], "the ADD COLUMN and the RENAME both applied")
        XCTAssertEqual(db.foreignKeys("posts").map(\.from), ["author_id"])
        let indexes = db.run("PRAGMA index_list(posts)").rows.map { $0[1] }
        XCTAssertTrue(indexes.contains("posts_author") && indexes.contains("posts_title"), "\(indexes)")
        XCTAssertEqual(db.run("PRAGMA index_info(posts_title)").rows.count, 2)
        XCTAssertNil(db.run("SELECT COUNT(*) FROM posts").error, "reads run")
        XCTAssertEqual(db.run("PRAGMA writable_schema = 1").error, "not authorized", "a pragma that is not a schema read is refused")
    }

    /// The rule as a table, so a reader of the test sees what is allowed without SQLite.
    func testTheVerdictTable() {
        XCTAssertEqual(SchemaAuthorizer.verdict(action: SQLITE_ATTACH, subject: "/tmp/x.db"), SQLITE_DENY)
        XCTAssertEqual(SchemaAuthorizer.verdict(action: SQLITE_DETACH, subject: "v"), SQLITE_DENY)
        for drop in [SQLITE_DROP_TABLE, SQLITE_DROP_INDEX, SQLITE_DROP_VIEW, SQLITE_DROP_TRIGGER, SQLITE_DROP_TEMP_TABLE] {
            XCTAssertEqual(SchemaAuthorizer.verdict(action: drop, subject: "t"), SQLITE_DENY)
        }
        for write in [SQLITE_INSERT, SQLITE_UPDATE, SQLITE_DELETE] {
            XCTAssertEqual(SchemaAuthorizer.verdict(action: write, subject: "users"), SQLITE_DENY)
            XCTAssertEqual(
                SchemaAuthorizer.verdict(action: write, subject: "sqlite_master"), SQLITE_OK, "CREATE and ALTER write the catalogue")
        }
        for create in [
            SQLITE_CREATE_TABLE, SQLITE_CREATE_INDEX, SQLITE_CREATE_VIEW, SQLITE_CREATE_TRIGGER, SQLITE_ALTER_TABLE, SQLITE_REINDEX,
        ] {
            XCTAssertEqual(SchemaAuthorizer.verdict(action: create, subject: "t"), SQLITE_OK)
        }
        for read in [SQLITE_READ, SQLITE_SELECT, SQLITE_FUNCTION, SQLITE_TRANSACTION] {
            XCTAssertEqual(SchemaAuthorizer.verdict(action: read, subject: nil), SQLITE_OK)
        }
        XCTAssertEqual(SchemaAuthorizer.verdict(action: SQLITE_PRAGMA, subject: "table_info"), SQLITE_OK)
        XCTAssertEqual(SchemaAuthorizer.verdict(action: SQLITE_PRAGMA, subject: "foreign_key_list"), SQLITE_OK)
        XCTAssertEqual(SchemaAuthorizer.verdict(action: SQLITE_PRAGMA, subject: "writable_schema"), SQLITE_DENY)
        XCTAssertEqual(SchemaAuthorizer.verdict(action: SQLITE_CREATE_VTABLE, subject: "fts"), SQLITE_DENY)
        XCTAssertEqual(SchemaAuthorizer.verdict(action: SQLITE_COPY, subject: nil), SQLITE_DENY)
    }
}
