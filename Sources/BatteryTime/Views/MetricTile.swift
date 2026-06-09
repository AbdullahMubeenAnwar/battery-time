import SwiftUI

struct MetricTile: View {
    let title: String
    let value: String
    let caption: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(title, systemImage: systemImage)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
            }

            Text(value)
                .font(.title2.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .monospacedDigit()

            Text(caption)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
        .batteryGlassPanel()
        .help("\(title): \(value). \(caption)")
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(value), \(caption)")
    }
}
