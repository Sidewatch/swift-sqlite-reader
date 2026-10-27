//
//  SQLiteDB+Insert.swift
//  SQLiteReader
//
//  Rows as INSERT statements, each value an SQL literal.
//
//  Created by David Sherlock on 10/27/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

public extension SQLiteDB {
    /// `rows` as one `INSERT INTO "table" ("a", …) VALUES (…);` statement a row, to paste into a script or a message:
    /// identifiers double-quoted (``quoteIdentifier(_:)``), every value a literal (``literal(_:)``). Running them
    /// puts the same values back, types and all.
    static func insertStatements(into table: String, columns: [String], rows: [[Cell]]) -> String {
        let head = "INSERT INTO \(quoteIdentifier(table)) (\(columns.map(quoteIdentifier).joined(separator: ", "))) VALUES ("
        return rows.map { head + $0.map(literal).joined(separator: ", ") + ");\n" }.joined()
    }

    /// One cell as an SQL literal: NULL; the number (a REAL that is not finite as SQLite writes it, `9e999`); text in
    /// single quotes, quotes doubled; a blob as `X'…'`, or NULL and a comment saying so when its bytes were not kept.
    static func literal(_ cell: Cell) -> String {
        switch cell {
        case .null: return "NULL"
        case .integer(let value): return String(value)
        case .real(let value) where value.isNaN: return "NULL"
        case .real(let value) where value.isInfinite: return value > 0 ? "9e999" : "-9e999"
        case .real(let value): return String(value)
        case .text(let text): return "'" + text.replacingOccurrences(of: "'", with: "''") + "'"
        case .blob(let bytes?, _): return "X'" + bytes.map { String(format: "%02X", $0) }.joined() + "'"
        case .blob(nil, let count): return "NULL /* a blob of \(count) bytes, not copied */"
        }
    }
}
