//
//  SQLiteDB+Result+Rows.swift
//  SQLiteReader
//
//  A result's rows reordered, trimmed or replaced, their typed cells moving with them.
//
//  Created by David Sherlock on 10/27/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

public extension SQLiteDB.Result {
    /// The rows in `order`, each an index into ``rows``, their cells moved with them (a sorted grid).
    func reordered(_ order: [Int]) -> Self {
        Self(columns: columns, rows: order.map { rows[$0] }, cells: order.map { cells[$0] }, error: error, rowsAffected: rowsAffected)
    }

    /// Without the first column, from the header, every row and its cells: a `rowid` read only to edit by.
    func droppingFirstColumn() -> Self {
        Self(
            columns: Array(columns.dropFirst()), rows: rows.map { Array($0.dropFirst()) }, cells: cells.map { Array($0.dropFirst()) },
            error: error, rowsAffected: rowsAffected)
    }

    /// With row `index` replaced by `other`'s first row, cells and all (a fresh read of the same record); as it is
    /// when either row is missing.
    func replacingRow(_ index: Int, withFirstRowOf other: Self) -> Self {
        guard rows.indices.contains(index), let row = other.rows.first, let cellRow = other.cells.first else { return self }
        var rows = rows
        var cells = cells
        rows[index] = row
        cells[index] = cellRow
        return Self(columns: columns, rows: rows, cells: cells, error: error, rowsAffected: rowsAffected)
    }

    /// With `other`'s first row added at the end, cells and all; as it is when `other` has no rows.
    func appendingFirstRow(of other: Self) -> Self {
        guard let row = other.rows.first, let cellRow = other.cells.first else { return self }
        return Self(columns: columns, rows: rows + [row], cells: cells + [cellRow], error: error, rowsAffected: rowsAffected)
    }
}
