import AppKit
import Foundation

final class ScreenActivityMonitor {
    private var lastTickDate: Date
    private let maximumContinuousTick: TimeInterval = 150

    init(startDate: Date = Date()) {
        self.lastTickDate = startDate
    }

    func recordTick(at date: Date = Date()) -> ScreenActivitySample? {
        defer { lastTickDate = date }

        let elapsed = date.timeIntervalSince(lastTickDate)
        guard elapsed > 0, elapsed <= maximumContinuousTick, !isScreenLocked else {
            return nil
        }

        return ScreenActivitySample(
            startDate: lastTickDate,
            endDate: date,
            activeSeconds: elapsed
        )
    }

    private var isScreenLocked: Bool {
        guard let session = CGSessionCopyCurrentDictionary() as? [String: Any] else {
            return false
        }

        return session["CGSSessionScreenIsLocked"] as? Bool ?? false
    }
}
