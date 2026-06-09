import SwiftUI

struct AppTitlebarView: View {
    @EnvironmentObject private var batteryMonitor: BatteryMonitor

    let sectionTitle: String
    let isSidebarVisible: Bool
    let toggleSidebar: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            appIdentity

            Spacer(minLength: 12)

            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    BatteryTitlebarStatusBadge(
                        title: statusTitle,
                        subtitle: batteryMonitor.snapshot.stateTitle,
                        systemImage: batteryMonitor.snapshot.symbolName
                    )

                    TitlebarActionsView(
                        isSidebarVisible: isSidebarVisible,
                        toggleSidebar: toggleSidebar,
                        refresh: {
                            batteryMonitor.refresh()
                        }
                    )
                }
            }
        }
        .padding(.leading, 80)
        .padding(.trailing, 18)
        .frame(height: 52)
        .frame(maxWidth: .infinity)
        .background {
            Rectangle()
                .fill(.regularMaterial)
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.primary.opacity(0.08))
                .frame(height: 1)
        }
        .accessibilityElement(children: .contain)
    }

    private var appIdentity: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.accentColor.opacity(0.14))

                Image(systemName: "battery.75percent")
                    .font(.system(size: 15, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color.accentColor)
            }
            .frame(width: 28, height: 28)
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.accentColor.opacity(0.18))
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("Battery Time")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)

                Text(sectionTitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .lineLimit(1)
        }
        .help("Battery Time")
        .accessibilityElement(children: .combine)
    }

    private var statusTitle: String {
        guard let percentage = batteryMonitor.percentageText else {
            return "No battery data"
        }

        guard let time = batteryMonitor.timeText else {
            return percentage
        }

        return "\(percentage) | \(time)"
    }
}

private struct BatteryTitlebarStatusBadge: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .monospacedDigit()

                Text(subtitle)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .lineLimit(1)
        } icon: {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .batteryGlassCapsule()
        .overlay {
            Capsule()
                .strokeBorder(Color.primary.opacity(0.08))
        }
        .help("\(title), \(subtitle)")
        .accessibilityElement(children: .combine)
    }
}
