import AppKit
import SwiftUI

struct ContentView: View {
    @State private var selection: DashboardSection = .overview
    @State private var isSidebarVisible = false

    var body: some View {
        VStack(spacing: 0) {
            AppTitlebarView(
                sectionTitle: selection.title,
                isSidebarVisible: isSidebarVisible,
                toggleSidebar: toggleSidebar
            )

            HStack(spacing: 0) {
                if isSidebarVisible {
                    sidebar
                        .transition(.move(edge: .leading).combined(with: .opacity))
                } else {
                    collapsedSidebar
                        .transition(.opacity)
                }

                Divider()

                detail
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: BatteryTimeAppModel.toggleSidebarNotification)) { _ in
            toggleSidebar()
        }
        .ignoresSafeArea(.container, edges: .top)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(DashboardSection.allCases) { section in
                SidebarSectionButton(
                    section: section,
                    isSelected: selection == section
                ) {
                    selection = section
                }
            }

            Spacer()

            SidebarQuitButton(collapsed: false)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
        .frame(width: 210)
        .frame(maxHeight: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.primary.opacity(0.03))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.10))
        }
        .padding(8)
    }

    private var collapsedSidebar: some View {
        VStack(spacing: 8) {
            ForEach(DashboardSection.allCases) { section in
                CollapsedSidebarButton(
                    section: section,
                    isSelected: selection == section
                ) {
                    selection = section
                }
            }

            Spacer()

            SidebarQuitButton(collapsed: true)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 14)
        .frame(width: 58)
        .frame(maxHeight: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.primary.opacity(0.03))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.10))
        }
        .padding(8)
        .accessibilityLabel("Collapsed navigation")
    }

    @ViewBuilder
    private var detail: some View {
        switch selection {
        case .overview:
            BatteryDetailView()
        case .usage:
            BatteryUsageView()
        }
    }

    private func toggleSidebar() {
        withAnimation(.easeInOut(duration: 0.18)) {
            isSidebarVisible.toggle()
        }
    }
}

private struct SidebarSectionButton: View {
    let section: DashboardSection
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: section.systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .frame(width: 18)

                Text(section.title)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
        .frame(height: 34)
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(isSelected ? Color.white : Color.primary)
        .background {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(backgroundColor)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(borderColor)
        }
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .onHover { isHovering = $0 }
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .animation(.easeInOut(duration: 0.12), value: isHovering)
        .animation(.easeInOut(duration: 0.12), value: isSelected)
    }

    private var backgroundColor: Color {
        if isSelected {
            return Color.accentColor
        }

        return isHovering ? Color.primary.opacity(0.08) : .clear
    }

    private var borderColor: Color {
        if isSelected {
            return Color.white.opacity(0.22)
        }

        return isHovering ? Color.primary.opacity(0.10) : .clear
    }
}

private struct SidebarQuitButton: View {
    let collapsed: Bool
    @State private var isHovering = false

    var body: some View {
        Button {
            NSApp.terminate(nil)
        } label: {
            if collapsed {
                Image(systemName: "power")
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 34, height: 34)
                    .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            } else {
                HStack(spacing: 10) {
                    Image(systemName: "power")
                        .font(.system(size: 14, weight: .medium))
                        .frame(width: 18)

                    Text("Quit")
                        .font(.system(size: 14, weight: .medium))

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            }
        }
        .buttonStyle(.plain)
        .frame(height: 34)
        .frame(maxWidth: collapsed ? nil : .infinity)
        .foregroundStyle(isHovering ? Color.primary.opacity(0.7) : Color.secondary.opacity(0.6))
        .background {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(isHovering ? Color.primary.opacity(0.07) : .clear)
        }
        .onHover { isHovering = $0 }
        .help("Quit Battery Time")
        .keyboardShortcut("q")
        .animation(.easeInOut(duration: 0.12), value: isHovering)
    }
}

private struct CollapsedSidebarButton: View {
    let section: DashboardSection
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Label(section.title, systemImage: section.systemImage)
                .labelStyle(.iconOnly)
                .font(.system(size: 15, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .frame(width: 34, height: 34)
                .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? Color.white : Color.primary)
        .background {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(backgroundColor)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(borderColor)
        }
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .help("Show \(section.title)")
        .accessibilityLabel("Show \(section.title)")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .onHover { isHovering = $0 }
        .animation(.easeInOut(duration: 0.12), value: isHovering)
        .animation(.easeInOut(duration: 0.12), value: isSelected)
    }

    private var backgroundColor: Color {
        if isSelected {
            return Color.accentColor
        }

        return isHovering ? Color.primary.opacity(0.08) : .clear
    }

    private var borderColor: Color {
        if isSelected {
            return Color.white.opacity(0.22)
        }

        return isHovering ? Color.primary.opacity(0.10) : .clear
    }
}
