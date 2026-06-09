import Foundation
import SQLite3

struct PowerlogBackfillClient {
    private let databasePath = "/var/db/powerlog/Library/BatteryLife/CurrentPowerlog.PLSQL"

    func backfill(since startDate: Date) -> PowerlogBackfillResult {
        guard FileManager.default.isReadableFile(atPath: databasePath) else {
            return unavailable("macOS power history is not readable.")
        }

        var database: OpaquePointer?
        guard sqlite3_open_v2(databasePath, &database, SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK,
              let database else {
            if let database {
                sqlite3_close(database)
            }
            return unavailable("macOS power history could not be opened.")
        }
        defer { sqlite3_close(database) }

        var batteryPoints = batteryPointsFromBatteryTable(since: startDate, database: database)
        if batteryPoints.isEmpty {
            batteryPoints = batteryPointsFromBatteryUITable(since: startDate, database: database)
        }

        let screenBuckets = screenBucketsFromPowerlog(since: startDate, database: database)
        let backfill = BatteryHistoryBackfill(
            batteryPoints: batteryPoints,
            screenBuckets: screenBuckets
        )

        guard !batteryPoints.isEmpty || !screenBuckets.isEmpty else {
            return PowerlogBackfillResult(
                backfill: backfill,
                isAvailable: false,
                reason: "macOS power history did not return usable rows."
            )
        }

        return PowerlogBackfillResult(
            backfill: backfill,
            isAvailable: true,
            reason: nil
        )
    }

    private func unavailable(_ reason: String) -> PowerlogBackfillResult {
        PowerlogBackfillResult(
            backfill: BatteryHistoryBackfill(batteryPoints: [], screenBuckets: []),
            isAvailable: false,
            reason: reason
        )
    }

    private func batteryPointsFromBatteryTable(since startDate: Date, database: OpaquePointer) -> [BatteryHistoryPoint] {
        guard tableExists("PLBatteryAgent_EventBackward_Battery", database: database) else {
            return []
        }

        let sql = """
            SELECT timestamp, Level, IsCharging, ExternalConnected
            FROM PLBatteryAgent_EventBackward_Battery
            WHERE timestamp >= ? AND Level IS NOT NULL
            ORDER BY timestamp ASC
            """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            return []
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_double(statement, 1, startDate.timeIntervalSince1970)

        var points: [BatteryHistoryPoint] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let level = sqlite3_column_double(statement, 1)
            guard level.isFinite else {
                continue
            }

            points.append(
                BatteryHistoryPoint(
                    date: Date(timeIntervalSince1970: sqlite3_column_double(statement, 0)),
                    percentage: clampPercent(level),
                    isPluggedIn: sqlite3_column_int(statement, 3) != 0,
                    isCharging: sqlite3_column_int(statement, 2) != 0,
                    source: .powerlog
                )
            )
        }

        return points
    }

    private func batteryPointsFromBatteryUITable(since startDate: Date, database: OpaquePointer) -> [BatteryHistoryPoint] {
        guard tableExists("PLBatteryAgent_EventBackward_BatteryUI", database: database) else {
            return []
        }

        let sql = """
            SELECT timestamp, Level, IsCharging
            FROM PLBatteryAgent_EventBackward_BatteryUI
            WHERE timestamp >= ? AND Level IS NOT NULL
            ORDER BY timestamp ASC
            """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            return []
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_double(statement, 1, startDate.timeIntervalSince1970)

        var points: [BatteryHistoryPoint] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let level = sqlite3_column_double(statement, 1)
            guard level.isFinite else {
                continue
            }

            let isCharging = sqlite3_column_int(statement, 2) != 0
            // BatteryUI table has no ExternalConnected column; infer plugged-in
            // when charging (definite) or level is full (almost always plugged in).
            let isPluggedIn = isCharging || level >= 100
            points.append(
                BatteryHistoryPoint(
                    date: Date(timeIntervalSince1970: sqlite3_column_double(statement, 0)),
                    percentage: clampPercent(level),
                    isPluggedIn: isPluggedIn,
                    isCharging: isCharging,
                    source: .powerlog
                )
            )
        }

        return points
    }

    private func screenBucketsFromPowerlog(since startDate: Date, database: OpaquePointer) -> [ScreenUsageBucket] {
        guard tableExists("PLDisplayAgent_Aggregate_ScreenOn", database: database) else {
            return []
        }

        let sql = """
            SELECT timestamp, timeInterval, ScreenOn
            FROM PLDisplayAgent_Aggregate_ScreenOn
            WHERE timestamp >= ?
            ORDER BY timestamp ASC
            """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            return []
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_double(statement, 1, startDate.timeIntervalSince1970)

        var buckets: [ScreenUsageBucket] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let endTimestamp = sqlite3_column_double(statement, 0)
            let interval = max(0, sqlite3_column_double(statement, 1))
            let activeSeconds = max(0, min(sqlite3_column_double(statement, 2), interval))
            guard interval > 0, activeSeconds > 0 else {
                continue
            }

            buckets.append(
                ScreenUsageBucket(
                    startDate: Date(timeIntervalSince1970: endTimestamp - interval),
                    endDate: Date(timeIntervalSince1970: endTimestamp),
                    activeSeconds: activeSeconds,
                    source: .powerlog
                )
            )
        }

        return buckets
    }

    private func tableExists(_ tableName: String, database: OpaquePointer) -> Bool {
        let sql = "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ? LIMIT 1"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            return false
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, tableName, -1, Self.sqliteTransient)
        return sqlite3_step(statement) == SQLITE_ROW
    }

    private func clampPercent(_ value: Double) -> Int {
        min(100, max(0, Int(round(value))))
    }

    private static let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
}
