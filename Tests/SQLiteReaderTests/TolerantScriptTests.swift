//
//  TolerantScriptTests.swift
//  SQLiteReaderTests
//
//  A script builds what it can: a statement SQLite rejects is skipped, not fatal.
//
//  Created by David Sherlock on 9/20/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import XCTest
@testable import SQLiteReader

final class TolerantScriptTests: XCTestCase {
    func testStatementsSplitOutsideQuotesAndComments() {
        let script =
            "CREATE TABLE a (id int, note text default 'x;y');\n-- a comment; here\nCREATE TABLE b (id int); /* block; */ CREATE TRIGGER t AFTER INSERT ON a BEGIN INSERT INTO b VALUES (1); END;\nSELECT 1"
        let parts = SQLiteDB.statements(in: script)
        XCTAssertEqual(parts.count, 4, "\(parts)")
        XCTAssertEqual(parts[0], "CREATE TABLE a (id int, note text default 'x;y')")
        XCTAssertTrue(parts[2].hasPrefix("CREATE TRIGGER"), "the trigger body's ; does not split: \(parts[2])")
        XCTAssertEqual(parts[3], "SELECT 1")
    }

    func testAScriptSurvivesAStatementSQLiteRejects() {
        let postgres =
            "CREATE EXTENSION IF NOT EXISTS pgcrypto;\nCREATE TABLE a (id serial primary key);\nALTER TABLE a ADD CONSTRAINT fk FOREIGN KEY (b) REFERENCES c(id);\nCREATE TABLE b (id int);\n"
        let db = SQLiteDB(sql: postgres)
        XCTAssertEqual(db?.tables(), ["a", "b"], "both tables, despite the extension and the ALTER")
    }

    func testAPostgresDumpsSchemaQualifiedNamesBuildTheirTables() {
        let dump = """
            DROP TABLE IF EXISTS public.users;
            CREATE TABLE public.users (id integer NOT NULL, email text);
            CREATE TABLE "public"."sessions" (id integer NOT NULL, user_id integer REFERENCES public.users(id));
            CREATE TABLE public.orders (id integer NOT NULL, note text DEFAULT 'see public.users');
            INSERT INTO public.users VALUES (1, 'a@example.com');
            CREATE TABLE audit.events (id integer);
            CREATE TABLE audit.logins (id integer, event_id integer REFERENCES audit.events(id));
            """
        let db = SQLiteDB(sql: dump)
        // `public`, and `audit`, learned from SQLite's error on its first table.
        XCTAssertEqual(db?.tables().sorted(), ["events", "logins", "orders", "sessions", "users"])
        XCTAssertEqual(db?.rowCount("users"), 0, "the dump's INSERT is a data write, which a schema build refuses")
        XCTAssertEqual(db?.foreignKeys("sessions").map(\.toTable), ["users"], "the reference loses its qualifier too")
    }

    func testQualifierRemovalLeavesOtherDotsAlone() {
        XCTAssertEqual(SQLiteDB.missingSchema(in: "unknown database public"), "public")
        XCTAssertEqual(SQLiteDB.missingSchema(in: #"unknown database "billing""#), "billing")
        XCTAssertEqual(SQLiteDB.missingSchema(in: "no such table: audit.events"), "audit")
        XCTAssertNil(SQLiteDB.missingSchema(in: "no such table: users"))
        XCTAssertEqual(
            SQLiteDB.removingQualifier("public", from: "SELECT u.id FROM public.users u WHERE x = 1.5"),
            "SELECT u.id FROM users u WHERE x = 1.5")
        XCTAssertNil(SQLiteDB.removingQualifier("public", from: "SELECT republic.x FROM t"))
    }
}
