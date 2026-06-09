import SwiftUI

struct OverviewHeaderView: View {
    let title: String
    let value: String
    let updatedAt: Date
    let systemImage: String
    let confidence: EstimateConfidence
    let source: String

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 10) {
                Label(title, systemImage: systemImage)
                    .font(.headline)

                Spacer()

                Text("Updated \(DurationFormatter.shortTime(updatedAt))")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Text(value)
                .font(.system(size: 38, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 8) {
                    statusChips

                    Spacer(minLength: 12)

                    UptimeHeaderChip()
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        statusChips
                    }

                    UptimeHeaderChip()
                }
            }

            if let learningMessage {
                Label(learningMessage, systemImage: "hourglass")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .batteryGlassCapsule()
                    .accessibilityLabel(learningMessage)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .batteryGlassPanel(cornerRadius: 18)
        .help("\(title). \(value). Estimate source: \(source). \(confidence.explanation)")
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var statusChips: some View {
        StatusChip(
            title: "Estimate: \(source)",
            systemImage: "waveform.path.ecg"
        )

        if confidence != .learning && confidence != .unavailable {
            StatusChip(
                title: confidence.title,
                systemImage: confidence.systemImage
            )
        }
    }

    private var learningMessage: String? {
        guard confidence == .learning else {
            return nil
        }

        return "Battery-time confidence improves after about 10 minutes of samples. Keep Battery Time open while you use your Mac."
    }
}

private struct UptimeHeaderChip: View {
    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let uptime = SystemUptimeFormatter.uptimeText(now: context.date)

            Label {
                HStack(spacing: 5) {
                    Text("Uptime")
                        .foregroundStyle(.secondary)

                    Text(uptime)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                        .monospacedDigit()
                }
            } icon: {
                Image(systemName: "clock.arrow.circlepath")
                    .symbolRenderingMode(.hierarchical)
            }
            .font(.callout)
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .batteryGlassCapsule()
            .help("Uptime: \(uptime)")
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Uptime, \(uptime)")
        }
    }
}

private struct StatusChip: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.callout)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .batteryGlassCapsule()
            .help(title)
    }
}
