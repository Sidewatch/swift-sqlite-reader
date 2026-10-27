//
//  TypedCellsTests.swift
//  SQLiteReaderTests
//
//  A result keeps each cell as SQLite stored it, and INSERT statements put the same cells back.
//
//  Created by David Sherlock on 10/27/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation
import XCTest

@testable import SQLiteReader

final class TypedCellsTests: XCTestCase {
    private var scratchFiles: [URL] = []

    override func tearDown() {
        scratchFiles.forEach { try? FileManager.default.removeItem(at: $0) }
        super.tearDown()
    }

    /// A writable database in a temporary file built from `sql`.
    private func scratch(_ sql: String) throws -> SQLiteDB {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("typed-\(UUID().uuidString).db")
        FileManager.default.createFile(atPath: url.path, contents: nil)
        scratchFiles.append(url)
        let db = try XCTUnwrap(SQLiteDB(url: url))
        XCTAssertNil(db.run(sql).error, "the fixture script runs whole")
        return db
    }

    /// A real NULL apart from the text "NULL", an INTEGER apart from digits stored as TEXT, a REAL, a blob's bytes, an
    /// empty blob; the display text is what it always was.
    func testCellsKeepWhatSQLiteStored() throws {
        let db = try scratch(
            """
            CREATE TABLE t (a, b, c, d, e, f, g);
            INSERT INTO t VALUES (NULL, 'NULL', 42, '042', 2.5, X'010203', X'');
            """)
        let result = db.run("SELECT * FROM t")
        XCTAssertEqual(
            result.cells.first,
            [.null, .text("NULL"), .integer(42), .text("042"), .real(2.5), .blob(Data([1, 2, 3]), count: 3), .blob(Data(), count: 0)])
        XCTAssertEqual(result.rows.first, ["NULL", "NULL", "42", "042", "2.5", "‹blob 3b›", "‹blob 0b›"])
    }

    /// A blob past the kept size keeps its size only, and shows the same.
    func testABigBlobKeepsItsSizeOnly() throws {
        let size = SQLiteDB.keptBlobBytes + 1
        let db = try scratch("CREATE TABLE t (b); INSERT INTO t VALUES (zeroblob(\(size)));")
        let result = db.run("SELECT b FROM t")
        XCTAssertEqual(result.cells.first, [.blob(nil, count: size)])
        XCTAssertEqual(result.rows.first, ["‹blob \(size)b›"])
    }

    /// Reordering, trimming the first column, replacing and appending a row move the cells with the rows.
    func testRowsAndCellsMoveTogether() throws {
        let db = try scratch("CREATE TABLE t (id, v); INSERT INTO t VALUES (1, 'a'), (2, NULL), (3, 3.5);")
        let result = db.run("SELECT rowid, * FROM t")
        let sorted = result.reordered([2, 0, 1])
        XCTAssertEqual(sorted.rows.map { $0[1] }, ["3", "1", "2"])
        XCTAssertEqual(sorted.cells.map { $0[2] }, [.real(3.5), .text("a"), .null])
        let trimmed = sorted.droppingFirstColumn()
        XCTAssertEqual(trimmed.columns, ["id", "v"])
        XCTAssertEqual(trimmed.cells.first, [.integer(3), .real(3.5)])
        let fresh = db.run("SELECT id, v FROM t WHERE id = 2")
        XCTAssertEqual(trimmed.replacingRow(0, withFirstRowOf: fresh).cells.first, [.integer(2), .null])
        XCTAssertEqual(trimmed.appendingFirstRow(of: fresh).cells.last, [.integer(2), .null])
        XCTAssertEqual(trimmed.replacingRow(9, withFirstRowOf: fresh), trimmed, "a row that is not there leaves the result as it is")
    }

    /// INSERT statements written from the cells put the same cells back: quotes doubled, NULL, numbers, blobs.
    func testInsertStatementsPutTheSameCellsBack() throws {
        let db = try scratch(
            #"""
            CREATE TABLE "odd ""name""" ("a b", c, d, e, f);
            INSERT INTO "odd ""name""" VALUES ('it''s', NULL, -7, 1e-05, X'00FF');
            INSERT INTO "odd ""name""" VALUES ('line
            break', 'NULL', 9223372036854775807, 9e999, X'');
            """#)
        let source = db.run(#"SELECT * FROM "odd ""name""""#)
        let script = SQLiteDB.insertStatements(into: #"odd "name""#, columns: source.columns, rows: source.cells)
        let copy = try scratch(#"CREATE TABLE "odd ""name""" ("a b", c, d, e, f);"# + "\n" + script)
        XCTAssertEqual(copy.run(#"SELECT * FROM "odd ""name""""#).cells, source.cells)
        XCTAssertTrue(
            script.hasPrefix(#"INSERT INTO "odd ""name""" ("a b", "c", "d", "e", "f") VALUES ('it''s', NULL, -7, 1e-05, X'00FF');"#))
    }

    /// The SQL that made a table: its CREATE, then its index and trigger, as written; a view's own; nothing for a name
    /// that is not there.
    func testCreateStatementsAreTheTablesOwnSQL() throws {
        let db = try scratch(
            """
            CREATE TABLE users (id INTEGER PRIMARY KEY, email TEXT UNIQUE);
            CREATE INDEX users_email ON users (email);
            CREATE TRIGGER users_touch AFTER UPDATE ON users BEGIN SELECT 1; END;
            CREATE VIEW people AS SELECT * FROM users;
            """)
        XCTAssertEqual(
            db.createStatements(for: "users"),
            [
                "CREATE TABLE users (id INTEGER PRIMARY KEY, email TEXT UNIQUE);",
                "CREATE INDEX users_email ON users (email);",
                "CREATE TRIGGER users_touch AFTER UPDATE ON users BEGIN SELECT 1; END;",
            ])
        XCTAssertEqual(db.createStatements(for: "people"), ["CREATE VIEW people AS SELECT * FROM users;"])
        XCTAssertEqual(db.createStatements(for: "nobody"), [])
    }

    /// A blob whose bytes were not kept is written as NULL with a comment that says so, and the statement still runs.
    func testAnUnkeptBlobIsSaidNotSilentlyWrong() throws {
        let line = SQLiteDB.insertStatements(into: "t", columns: ["b"], rows: [[.blob(nil, count: 100_000)]])
        XCTAssertEqual(line, "INSERT INTO \"t\" (\"b\") VALUES (NULL /* a blob of 100000 bytes, not copied */);\n")
        let db = try scratch("CREATE TABLE t (b);\n" + line)
        XCTAssertEqual(db.run("SELECT b FROM t").cells, [[.null]])
    }
}
