import SwiftUI

struct TitlebarActionsView: View {
    @Environment(\.openSettings) private var openSettings

    let isSidebarVisible: Bool
    let toggleSidebar: () -> Void
    let refresh: () -> Void

    var body: some View {
        HStack(spacing: 3) {
            TitlebarToolbarButton(
                title: isSidebarVisible ? "Hide sidebar" : "Show sidebar",
                systemImage: "sidebar.leading",
                action: toggleSidebar
            )

            TitlebarActionDivider()

            TitlebarToolbarButton(
                title: "Refresh battery data",
                systemImage: "arrow.clockwise",
                action: refresh
            )

            TitlebarToolbarButton(
                title: "Open Battery Time settings",
                systemImage: "gearshape",
                action: {
                    openSettings()
                }
            )
        }
        .padding(4)
        .batteryGlassCapsule(interactive: true)
        .overlay {
            Capsule()
                .strokeBorder(Color.primary.opacity(0.08))
        }
        .shadow(color: Color.black.opacity(0.10), radius: 8, x: 0, y: 3)
    }
}

private struct TitlebarToolbarButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .labelStyle(.iconOnly)
                .font(.system(size: 13, weight: .semibold))
                .symbolRenderingMode(.monochrome)
        }
        .buttonStyle(TitlebarToolbarButtonStyle(isHovering: isHovering))
        .help(title)
        .onHover { isHovering = $0 }
        .accessibilityLabel(title)
    }
}

private struct TitlebarToolbarButtonStyle: ButtonStyle {
    let isHovering: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(iconColor(isPressed: configuration.isPressed))
            .frame(width: 30, height: 28)
            .background {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(buttonFill(isPressed: configuration.isPressed))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(Color.primary.opacity(configuration.isPressed ? 0.12 : 0.0))
            }
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .animation(.easeInOut(duration: 0.12), value: isHovering)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }

    private func iconColor(isPressed: Bool) -> Color {
        if isPressed {
            return Color.primary.opacity(0.68)
        }

        if isHovering {
            return Color.primary.opacity(0.96)
        }

        return Color.primary.opacity(0.78)
    }

    private func buttonFill(isPressed: Bool) -> Color {
        if isPressed {
            return Color.primary.opacity(0.13)
        }

        if isHovering {
            return Color.primary.opacity(0.075)
        }

        return .clear
    }
}

private struct TitlebarActionDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.10))
            .frame(width: 1, height: 16)
            .padding(.horizontal, 1)
    }
}
