//
//  SQLiteDB+Cell.swift
//  SQLiteReader
//
//  One result cell as SQLite stored it.
//
//  Created by David Sherlock on 10/27/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

public extension SQLiteDB {

    /// One result cell as SQLite stored it, beside ``Result/rows``' display text: a real NULL apart from the text
    /// "NULL", a number apart from digits in a text column, a blob's bytes. What a copy that keeps types reads.
    enum Cell: Sendable, Equatable {
        /// SQL NULL.
        case null
        /// An INTEGER.
        case integer(Int64)
        /// A REAL.
        case real(Double)
        /// TEXT, decoded as UTF-8 at its full length.
        case text(String)
        /// A BLOB of `count` bytes, with its bytes when they were kept (``SQLiteDB/keptBlobBytes``).
        case blob(Data?, count: Int)

        /// The cell as ``Result/rows`` shows it: `NULL`, the number, the text, or `‹blob Nb›`.
        public var display: String {
            switch self {
            case .null: return "NULL"
            case .integer(let value): return String(value)
            case .real(let value): return String(value)
            case .text(let text): return text
            case .blob(_, let count): return "‹blob \(count)b›"
            }
        }
    }

    /// The most bytes of one blob a result keeps; a bigger blob keeps its size only.
    static let keptBlobBytes = 64 * 1024
    /// The most blob bytes one result keeps in all; past it, every further blob keeps its size only.
    static let keptBlobTotal = 16 * 1024 * 1024
}
