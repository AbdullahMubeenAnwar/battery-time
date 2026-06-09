import Darwin
import Foundation

enum SystemUptimeFormatter {
    static func uptimeText(now: Date = Date()) -> String {
        guard let bootDate = bootDate() else {
            return "Unknown"
        }

        let formatter = DateComponentsFormatter()
        formatter.maximumUnitCount = 2
        formatter.unitsStyle = .full
        formatter.allowedUnits = [.day, .hour, .minute]

        return formatter.string(from: bootDate, to: now) ?? "Unknown"
    }

    private static func bootDate() -> Date? {
        var mib = [CTL_KERN, KERN_BOOTTIME]
        var bootTime = timeval()
        var bootTimeSize = MemoryLayout<timeval>.size

        let result = sysctl(&mib, UInt32(mib.count), &bootTime, &bootTimeSize, nil, 0)
        guard result == 0 else {
            return nil
        }

        return Date(timeIntervalSince1970: Double(bootTime.tv_sec) + Double(bootTime.tv_usec) / 1_000_000)
    }
}
