//
//  TolerantScriptTests.swift
//  Tests for SQLiteReader
//
//  A script builds what it can: a statement SQLite rejects is skipped, not fatal.
//

import XCTest
@testable import SQLiteReader

final class TolerantScriptTests: XCTestCase {
    func testStatementsSplitOutsideQuotesAndComments() {
        let script = "CREATE TABLE a (id int, note text default 'x;y');\n-- a comment; here\nCREATE TABLE b (id int); /* block; */ CREATE TRIGGER t AFTER INSERT ON a BEGIN INSERT INTO b VALUES (1); END;\nSELECT 1"
        let parts = SQLiteDB.statements(in: script)
        XCTAssertEqual(parts.count, 4, "\(parts)")
        XCTAssertEqual(parts[0], "CREATE TABLE a (id int, note text default 'x;y')")
        XCTAssertTrue(parts[2].hasPrefix("CREATE TRIGGER"), "the trigger body's ; does not split: \(parts[2])")
        XCTAssertEqual(parts[3], "SELECT 1")
    }

    func testAScriptSurvivesAStatementSQLiteRejects() {
        let postgres = "CREATE EXTENSION IF NOT EXISTS pgcrypto;\nCREATE TABLE a (id serial primary key);\nALTER TABLE a ADD CONSTRAINT fk FOREIGN KEY (b) REFERENCES c(id);\nCREATE TABLE b (id int);\n"
        let db = SQLiteDB(sql: postgres)
        XCTAssertEqual(db?.tables(), ["a", "b"], "both tables, despite the extension and the ALTER")
    }
}
