import Foundation

struct BatteryEstimator {
    private enum Mode {
        case discharging
        case charging
        case pluggedIn
        case unavailable
    }

    func estimate(snapshot: BatterySnapshot, samples: [BatterySample]) -> BatteryEstimate {
        guard snapshot.isAvailable else {
            return BatteryEstimate(
                minutes: nil,
                systemMinutes: nil,
                ratePercentPerHour: nil,
                confidence: .unavailable,
                windowMinutes: nil
            )
        }

        let mode = mode(for: snapshot)
        let systemMinutes = snapshot.displayMinutes

        guard mode != .pluggedIn else {
            return BatteryEstimate(
                minutes: systemMinutes,
                systemMinutes: systemMinutes,
                ratePercentPerHour: nil,
                confidence: .pluggedIn,
                windowMinutes: nil
            )
        }

        guard let percentage = snapshot.percentage else {
            return BatteryEstimate(
                minutes: systemMinutes,
                systemMinutes: systemMinutes,
                ratePercentPerHour: nil,
                confidence: .learning,
                windowMinutes: nil
            )
        }

        let rates = rollingRates(mode: mode, samples: samples, now: snapshot.collectedAt)
        guard let preferredRate = rates.first else {
            return BatteryEstimate(
                minutes: systemMinutes,
                systemMinutes: systemMinutes,
                ratePercentPerHour: nil,
                confidence: .learning,
                windowMinutes: nil
            )
        }

        let customMinutes = minutesRemaining(
            mode: mode,
            percentage: percentage,
            ratePercentPerHour: preferredRate.percentPerHour
        )

        let confidence = confidence(for: rates)

        return BatteryEstimate(
            minutes: systemMinutes ?? customMinutes,
            systemMinutes: systemMinutes,
            ratePercentPerHour: preferredRate.percentPerHour,
            confidence: confidence,
            windowMinutes: preferredRate.windowMinutes
        )
    }

    private func mode(for snapshot: BatterySnapshot) -> Mode {
        if snapshot.isCharging {
            return .charging
        }

        if snapshot.isPluggedIn {
            return .pluggedIn
        }

        return .discharging
    }

    private func rollingRates(mode: Mode, samples: [BatterySample], now: Date) -> [RollingRate] {
        [10, 30, 60].compactMap { windowMinutes in
            rollingRate(mode: mode, samples: samples, now: now, windowMinutes: windowMinutes)
        }
    }

    private func rollingRate(mode: Mode, samples: [BatterySample], now: Date, windowMinutes: Int) -> RollingRate? {
        let cutoff = now.addingTimeInterval(TimeInterval(-windowMinutes * 60))
        let relevantSamples = samples
            .filter { $0.date >= cutoff && matches(mode: mode, sample: $0) }
            .sorted { $0.date < $1.date }

        guard let first = relevantSamples.first,
              let last = relevantSamples.last,
              first.id != last.id else {
            return nil
        }

        let elapsedHours = last.date.timeIntervalSince(first.date) / 3600
        guard elapsedHours >= 0.08 else {
            return nil
        }

        let delta: Double
        switch mode {
        case .discharging:
            delta = Double(first.percentage - last.percentage)
        case .charging:
            delta = Double(last.percentage - first.percentage)
        case .pluggedIn, .unavailable:
            delta = 0
        }

        guard delta > 0 else {
            return nil
        }

        return RollingRate(
            windowMinutes: windowMinutes,
            percentPerHour: delta / elapsedHours
        )
    }

    private func matches(mode: Mode, sample: BatterySample) -> Bool {
        switch mode {
        case .discharging:
            return !sample.isPluggedIn
        case .charging:
            return sample.isCharging
        case .pluggedIn:
            return sample.isPluggedIn && !sample.isCharging
        case .unavailable:
            return false
        }
    }

    private func minutesRemaining(mode: Mode, percentage: Int, ratePercentPerHour: Double) -> Int? {
        guard ratePercentPerHour > 0 else {
            return nil
        }

        let remainingPercent: Double
        switch mode {
        case .discharging:
            remainingPercent = Double(percentage)
        case .charging:
            remainingPercent = Double(100 - percentage)
        case .pluggedIn, .unavailable:
            return nil
        }

        return Int((remainingPercent / ratePercentPerHour) * 60)
    }

    private func confidence(for rates: [RollingRate]) -> EstimateConfidence {
        guard rates.count >= 2 else {
            return .learning
        }

        let values = rates.map(\.percentPerHour)
        guard let minRate = values.min(), let maxRate = values.max(), maxRate > 0 else {
            return .learning
        }

        let spread = (maxRate - minRate) / maxRate
        return spread > 0.35 ? .changingFast : .stable
    }
}

private struct RollingRate {
    let windowMinutes: Int
    let percentPerHour: Double
}
