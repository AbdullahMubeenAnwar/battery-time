import SwiftUI

// MARK: - Glass panel / capsule (macOS 26 liquid glass; material fallback on older OS)

struct BatteryGlassPanelModifier: ViewModifier {
    let cornerRadius: CGFloat
    let interactive: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 26, *) {
            if interactive {
                content.glassEffect(
                    .regular.interactive(),
                    in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                )
            } else {
                content.glassEffect(
                    .regular,
                    in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                )
            }
        } else {
            content
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.regularMaterial)
                )
        }
    }
}

struct BatteryGlassCapsuleModifier: ViewModifier {
    let interactive: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 26, *) {
            if interactive {
                content.glassEffect(.regular.interactive(), in: Capsule())
            } else {
                content.glassEffect(.regular, in: Capsule())
            }
        } else {
            content.background(Capsule().fill(.regularMaterial))
        }
    }
}

extension View {
    func batteryGlassPanel(cornerRadius: CGFloat = 16, interactive: Bool = false) -> some View {
        modifier(BatteryGlassPanelModifier(cornerRadius: cornerRadius, interactive: interactive))
    }

    func batteryGlassCapsule(interactive: Bool = false) -> some View {
        modifier(BatteryGlassCapsuleModifier(interactive: interactive))
    }
}

// MARK: - GlassEffectContainer compat (pass-through on macOS < 26)

struct GlassContainer<Content: View>: View {
    let spacing: CGFloat
    @ViewBuilder let content: () -> Content

    var body: some View {
        if #available(macOS 26, *) {
            GlassEffectContainer(spacing: spacing) { content() }
        } else {
            content()
        }
    }
}

// MARK: - buttonStyle(.glass) compat

private struct GlassButtonModifier: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 26, *) {
            content.buttonStyle(.glass)
        } else {
            content.buttonStyle(.bordered)
        }
    }
}

extension View {
    func glassButtonStyle() -> some View {
        modifier(GlassButtonModifier())
    }
}

// MARK: - scrollEdgeEffectStyle(.soft) compat

private struct ScrollEdgeSoftTopModifier: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 26, *) {
            content.scrollEdgeEffectStyle(.soft, for: .top)
        } else {
            content
        }
    }
}

extension View {
    func scrollEdgeSoftTop() -> some View {
        modifier(ScrollEdgeSoftTopModifier())
    }
}
