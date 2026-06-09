import SwiftUI

struct BatteryGlassPanelModifier: ViewModifier {
    let cornerRadius: CGFloat
    let interactive: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
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
    }
}

struct BatteryGlassCapsuleModifier: ViewModifier {
    let interactive: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if interactive {
            content.glassEffect(.regular.interactive(), in: Capsule())
        } else {
            content.glassEffect(.regular, in: Capsule())
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
