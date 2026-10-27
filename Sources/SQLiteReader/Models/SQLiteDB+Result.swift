//
//  SQLiteDB+Result.swift
//  SQLiteReader
//
//  The outcome of running a SQL statement. Kept nested (`SQLiteDB.Result`) so it
//  does not collide with the standard library's `Swift.Result`.
//
//  Created by David Sherlock on 7/9/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

public extension SQLiteDB {

    /// The result of ``SQLiteDB/run(_:limit:)`` — stringified rows and their typed cells, or an error.
    struct Result: Sendable, Equatable {

        /// Column names, in order.
        public let columns: [String]

        /// Rows, each a stringified value per column.
        public let rows: [[String]]

        /// The same rows as typed cells, one per value of ``rows``: what SQLite stored, for a copy that keeps types.
        /// A result built from display text alone holds every cell as text.
        public let cells: [[Cell]]

        /// An error message if the statement failed, otherwise `nil`.
        public let error: String?

        /// The number of rows changed by the statement (for INSERT/UPDATE/DELETE).
        public let rowsAffected: Int

        /// A result from display text alone (a grid a viewer builds itself): every cell is text. Results are
        /// normally produced by ``SQLiteDB/run(_:limit:)``.
        public init(columns: [String], rows: [[String]], error: String?, rowsAffected: Int) {
            self.init(columns: columns, rows: rows, cells: rows.map { $0.map(Cell.text) }, error: error, rowsAffected: rowsAffected)
        }

        /// A result from typed cells, its ``rows`` their display text (``Cell/display``).
        public init(columns: [String], cells: [[Cell]], error: String?, rowsAffected: Int) {
            self.init(columns: columns, rows: cells.map { $0.map(\.display) }, cells: cells, error: error, rowsAffected: rowsAffected)
        }

        /// Every field, `rows` and `cells` already in step.
        init(columns: [String], rows: [[String]], cells: [[Cell]], error: String?, rowsAffected: Int) {
            self.columns = columns
            self.rows = rows
            self.cells = cells
            self.error = error
            self.rowsAffected = rowsAffected
        }
    }
}
