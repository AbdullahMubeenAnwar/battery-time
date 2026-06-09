import Foundation
import SQLite3

final class BatteryHistoryStore {
    private let retentionInterval: TimeInterval = 30 * 24 * 60 * 60
    private let pruneInterval: TimeInterval = 60 * 60
    private var database: OpaquePointer?
    private var lastPruneDate: Date?

    init(fileManager: FileManager = .default) {
        do {
            let supportDirectory = try Self.applicationSupportDirectory(fileManager: fileManager)
            try fileManager.createDirectory(at: supportDirectory, withIntermediateDirectories: true)
            let url = supportDirectory.appendingPathComponent("BatteryHistory.sqlite3")
            openPersistentDatabase(at: url)
        } catch {}
    }

    deinit {
        if let db = database {
            sqlite3_close(db)
        }
    }

    func saveSnapshot(_ snapshot: BatterySnapshot) {
        guard let percentage = snapshot.percentage, let database else { return }
        insertBatteryPoint(
            BatteryHistoryPoint(
                date: snapshot.collectedAt,
                percentage: percentage,
                isPluggedIn: snapshot.isPluggedIn,
                isCharging: snapshot.isCharging,
                source: .app
            ),
            into: database
        )
        pruneIfNeeded(now: snapshot.collectedAt, database: database)
    }

    func saveScreenActivity(_ sample: ScreenActivitySample) {
        guard sample.activeSeconds > 0, let database else { return }
        insertScreenBucket(
            ScreenUsageBucket(
                startDate: sample.startDate,
                endDate: sample.endDate,
                activeSeconds: sample.activeSeconds,
                source: .app
            ),
            into: database
        )
        pruneIfNeeded(now: sample.endDate, database: database)
    }

    func saveBackfill(_ backfill: BatteryHistoryBackfill, now: Date = Date()) {
        guard let database else { return }
        execute("BEGIN TRANSACTION", in: database)
        for point in backfill.batteryPoints { insertBatteryPoint(point, into: database) }
        for bucket in backfill.screenBuckets { insertScreenBucket(bucket, into: database) }
        execute("COMMIT", in: database)
        pruneIfNeeded(now: now, database: database)
    }

    func batteryPoints(since startDate: Date) -> [BatteryHistoryPoint] {
        guard let database else { return [] }
        let sql = """
            SELECT timestamp, percentage, is_plugged_in, is_charging, source
            FROM battery_samples
            WHERE timestamp >= ?
            ORDER BY timestamp ASC
            """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_double(statement, 1, startDate.timeIntervalSince1970)
        var points: [BatteryHistoryPoint] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let timestamp = sqlite3_column_double(statement, 0)
            let percentage = Int(sqlite3_column_int(statement, 1))
            let isPluggedIn = sqlite3_column_int(statement, 2) != 0
            let isCharging = sqlite3_column_int(statement, 3) != 0
            let sourceText = sqlite3_column_text(statement, 4).map { String(cString: $0) } ?? HistorySampleSource.app.rawValue
            let source = HistorySampleSource(rawValue: sourceText) ?? .app
            points.append(BatteryHistoryPoint(
                date: Date(timeIntervalSince1970: timestamp),
                percentage: percentage,
                isPluggedIn: isPluggedIn,
                isCharging: isCharging,
                source: source
            ))
        }
        return points
    }

    func screenBuckets(since startDate: Date) -> [ScreenUsageBucket] {
        guard let database else { return [] }
        let sql = """
            SELECT bucket_start, bucket_end, active_seconds, source
            FROM screen_usage
            WHERE bucket_end >= ?
            ORDER BY bucket_start ASC
            """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_double(statement, 1, startDate.timeIntervalSince1970)
        var buckets: [ScreenUsageBucket] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let startTimestamp = sqlite3_column_double(statement, 0)
            let endTimestamp = sqlite3_column_double(statement, 1)
            let activeSeconds = sqlite3_column_double(statement, 2)
            let sourceText = sqlite3_column_text(statement, 3).map { String(cString: $0) } ?? HistorySampleSource.app.rawValue
            let source = HistorySampleSource(rawValue: sourceText) ?? .app
            buckets.append(ScreenUsageBucket(
                startDate: Date(timeIntervalSince1970: startTimestamp),
                endDate: Date(timeIntervalSince1970: endTimestamp),
                activeSeconds: activeSeconds,
                source: source
            ))
        }
        return buckets
    }

    func counts(since startDate: Date) -> BatteryHistoryCounts {
        guard let database else {
            return BatteryHistoryCounts(appBatteryPoints: 0, powerlogBatteryPoints: 0, powerlogScreenBuckets: 0)
        }
        return BatteryHistoryCounts(
            appBatteryPoints: countRows(
                sql: "SELECT COUNT(*) FROM battery_samples WHERE timestamp >= ? AND source = ?",
                date: startDate, source: .app, database: database
            ),
            powerlogBatteryPoints: countRows(
                sql: "SELECT COUNT(*) FROM battery_samples WHERE timestamp >= ? AND source = ?",
                date: startDate, source: .powerlog, database: database
            ),
            powerlogScreenBuckets: countRows(
                sql: "SELECT COUNT(*) FROM screen_usage WHERE bucket_end >= ? AND source = ?",
                date: startDate, source: .powerlog, database: database
            )
        )
    }

    private static func applicationSupportDirectory(fileManager: FileManager) throws -> URL {
        guard let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw CocoaError(.fileNoSuchFile)
        }
        return baseURL.appendingPathComponent("BatteryTime", isDirectory: true)
    }

    private func openPersistentDatabase(at url: URL) {
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(url.path, &database, flags, nil) == SQLITE_OK, let db = database else {
            if let db = database { sqlite3_close(db) }
            database = nil
            return
        }
        execute("PRAGMA journal_mode=WAL", in: db)
        execute("PRAGMA synchronous=NORMAL", in: db)
        initializeSchema(in: db)
    }

    private func initializeSchema(in database: OpaquePointer) {
        execute(
            """
            CREATE TABLE IF NOT EXISTS battery_samples (
                timestamp REAL NOT NULL,
                percentage INTEGER NOT NULL,
                is_plugged_in INTEGER NOT NULL,
                is_charging INTEGER NOT NULL,
                source TEXT NOT NULL,
                PRIMARY KEY (timestamp, source)
            )
            """,
            in: database
        )
        execute(
            """
            CREATE TABLE IF NOT EXISTS screen_usage (
                bucket_start REAL NOT NULL,
                bucket_end REAL NOT NULL,
                active_seconds REAL NOT NULL,
                source TEXT NOT NULL,
                PRIMARY KEY (bucket_start, bucket_end, source)
            )
            """,
            in: database
        )
        execute("CREATE INDEX IF NOT EXISTS battery_samples_timestamp_index ON battery_samples(timestamp)", in: database)
        execute("CREATE INDEX IF NOT EXISTS screen_usage_bucket_end_index ON screen_usage(bucket_end)", in: database)
    }

    private func insertBatteryPoint(_ point: BatteryHistoryPoint, into database: OpaquePointer) {
        let sql = """
            INSERT OR REPLACE INTO battery_samples
            (timestamp, percentage, is_plugged_in, is_charging, source)
            VALUES (?, ?, ?, ?, ?)
            """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_double(statement, 1, point.date.timeIntervalSince1970)
        sqlite3_bind_int(statement, 2, Int32(point.percentage))
        sqlite3_bind_int(statement, 3, point.isPluggedIn ? 1 : 0)
        sqlite3_bind_int(statement, 4, point.isCharging ? 1 : 0)
        bindText(point.source.rawValue, at: 5, in: statement)
        sqlite3_step(statement)
    }

    private func insertScreenBucket(_ bucket: ScreenUsageBucket, into database: OpaquePointer) {
        let sql = """
            INSERT OR REPLACE INTO screen_usage
            (bucket_start, bucket_end, active_seconds, source)
            VALUES (?, ?, ?, ?)
            """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_double(statement, 1, bucket.startDate.timeIntervalSince1970)
        sqlite3_bind_double(statement, 2, bucket.endDate.timeIntervalSince1970)
        sqlite3_bind_double(statement, 3, bucket.activeSeconds)
        bindText(bucket.source.rawValue, at: 4, in: statement)
        sqlite3_step(statement)
    }

    private func pruneIfNeeded(now: Date, database: OpaquePointer) {
        if let last = lastPruneDate, now.timeIntervalSince(last) < pruneInterval { return }
        lastPruneDate = now
        pruneOldRows(in: database, now: now)
    }

    private func pruneOldRows(in database: OpaquePointer, now: Date) {
        let cutoff = now.addingTimeInterval(-retentionInterval).timeIntervalSince1970

        var batteryStatement: OpaquePointer?
        if sqlite3_prepare_v2(database, "DELETE FROM battery_samples WHERE timestamp < ?", -1, &batteryStatement, nil) == SQLITE_OK {
            sqlite3_bind_double(batteryStatement, 1, cutoff)
            sqlite3_step(batteryStatement)
        }
        sqlite3_finalize(batteryStatement)

        var screenStatement: OpaquePointer?
        if sqlite3_prepare_v2(database, "DELETE FROM screen_usage WHERE bucket_end < ?", -1, &screenStatement, nil) == SQLITE_OK {
            sqlite3_bind_double(screenStatement, 1, cutoff)
            sqlite3_step(screenStatement)
        }
        sqlite3_finalize(screenStatement)
    }

    private func countRows(sql: String, date: Date, source: HistorySampleSource, database: OpaquePointer) -> Int {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else { return 0 }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_double(statement, 1, date.timeIntervalSince1970)
        bindText(source.rawValue, at: 2, in: statement)
        guard sqlite3_step(statement) == SQLITE_ROW else { return 0 }
        return Int(sqlite3_column_int(statement, 0))
    }

    @discardableResult
    private func execute(_ sql: String, in database: OpaquePointer) -> Bool {
        sqlite3_exec(database, sql, nil, nil, nil) == SQLITE_OK
    }

    private func bindText(_ value: String, at index: Int32, in statement: OpaquePointer?) {
        sqlite3_bind_text(statement, index, value, -1, Self.sqliteTransient)
    }

    private static let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
}
