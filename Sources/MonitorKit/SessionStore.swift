import Foundation
#if canImport(SQLite3)
import SQLite3
#endif

/// SQLite 기반 세션 저장소. ~/.mon/sessions.db
public final class SessionStore: Sendable {
    private let dbPath: String
    private let lock = NSLock()

    public init(dbPath: String? = nil) throws {
        if let dbPath {
            self.dbPath = dbPath
        } else {
            let monDir = NSHomeDirectory() + "/.mon"
            try FileManager.default.createDirectory(atPath: monDir, withIntermediateDirectories: true)
            self.dbPath = monDir + "/sessions.db"
        }
        try createTable()
    }

    // MARK: - CRUD

    /// 새 세션 등록, id 반환
    public func start(title: String, machine: String = ProcessInfo.processInfo.hostName) throws -> String {
        let session = Session(title: title, machine: machine)
        try execute("""
            INSERT INTO sessions (id, title, machine, started_at, updated_at)
            VALUES (?, ?, ?, datetime('now'), datetime('now'))
            """, params: [session.id, session.title, session.machine])
        return session.id
    }

    /// heartbeat — updated_at 갱신
    public func ping(_ id: String) throws {
        let changed = try executeUpdate(
            "UPDATE sessions SET updated_at = datetime('now') WHERE id = ?",
            params: [id])
        if changed == 0 {
            throw MonError.sessionNotFound(id)
        }
    }

    /// 세션 종료 (삭제)
    public func end(_ id: String) throws {
        let changed = try executeUpdate(
            "DELETE FROM sessions WHERE id = ?",
            params: [id])
        if changed == 0 {
            throw MonError.sessionNotFound(id)
        }
    }

    /// 전체 세션 목록 (active 먼저, idle 다음)
    public func list() throws -> [Session] {
        try query("SELECT id, title, machine, started_at, updated_at FROM sessions ORDER BY updated_at DESC")
    }

    /// 오래된 세션 정리 (기본 24시간)
    public func prune(olderThan seconds: TimeInterval = 86400) throws {
        try execute(
            "DELETE FROM sessions WHERE updated_at < datetime('now', ?)",
            params: ["-\(Int(seconds)) seconds"])
    }

    // MARK: - SQLite internals

    private func createTable() throws {
        try execute("""
            CREATE TABLE IF NOT EXISTS sessions (
                id TEXT PRIMARY KEY,
                title TEXT NOT NULL,
                machine TEXT NOT NULL,
                started_at TEXT NOT NULL DEFAULT (datetime('now')),
                updated_at TEXT NOT NULL DEFAULT (datetime('now'))
            )
            """)
    }

    private func withDB<T>(_ body: (OpaquePointer) throws -> T) throws -> T {
        var db: OpaquePointer?
        let rc = sqlite3_open(dbPath, &db)
        guard rc == SQLITE_OK, let db else {
            let msg = db.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown"
            sqlite3_close(db)
            throw MonError.dbError(msg)
        }
        defer { sqlite3_close(db) }
        // WAL mode for concurrent reads
        sqlite3_exec(db, "PRAGMA journal_mode=WAL", nil, nil, nil)
        return try body(db)
    }

    private func execute(_ sql: String, params: [String] = []) throws {
        try withDB { db in
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                throw MonError.dbError(String(cString: sqlite3_errmsg(db)))
            }
            defer { sqlite3_finalize(stmt) }

            for (i, param) in params.enumerated() {
                sqlite3_bind_text(stmt, Int32(i + 1), (param as NSString).utf8String, -1, nil)
            }

            let rc = sqlite3_step(stmt)
            guard rc == SQLITE_DONE || rc == SQLITE_ROW else {
                throw MonError.dbError(String(cString: sqlite3_errmsg(db)))
            }
        }
    }

    private func executeUpdate(_ sql: String, params: [String] = []) throws -> Int {
        try withDB { db in
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                throw MonError.dbError(String(cString: sqlite3_errmsg(db)))
            }
            defer { sqlite3_finalize(stmt) }

            for (i, param) in params.enumerated() {
                sqlite3_bind_text(stmt, Int32(i + 1), (param as NSString).utf8String, -1, nil)
            }

            let rc = sqlite3_step(stmt)
            guard rc == SQLITE_DONE else {
                throw MonError.dbError(String(cString: sqlite3_errmsg(db)))
            }
            return Int(sqlite3_changes(db))
        }
    }

    private func query(_ sql: String) throws -> [Session] {
        try withDB { db in
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                throw MonError.dbError(String(cString: sqlite3_errmsg(db)))
            }
            defer { sqlite3_finalize(stmt) }

            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let fallback = DateFormatter()
            fallback.dateFormat = "yyyy-MM-dd HH:mm:ss"
            fallback.timeZone = TimeZone(identifier: "UTC")

            var sessions: [Session] = []
            while sqlite3_step(stmt) == SQLITE_ROW {
                let id = String(cString: sqlite3_column_text(stmt, 0))
                let title = String(cString: sqlite3_column_text(stmt, 1))
                let machine = String(cString: sqlite3_column_text(stmt, 2))
                let startedStr = String(cString: sqlite3_column_text(stmt, 3))
                let updatedStr = String(cString: sqlite3_column_text(stmt, 4))

                let started = formatter.date(from: startedStr) ?? fallback.date(from: startedStr) ?? Date()
                let updated = formatter.date(from: updatedStr) ?? fallback.date(from: updatedStr) ?? Date()

                sessions.append(Session(
                    id: id, title: title, machine: machine,
                    startedAt: started, updatedAt: updated))
            }
            return sessions
        }
    }
}

public enum MonError: Error, LocalizedError {
    case sessionNotFound(String)
    case dbError(String)

    public var errorDescription: String? {
        switch self {
        case .sessionNotFound(let id): "session not found: \(id)"
        case .dbError(let msg): "db error: \(msg)"
        }
    }
}
