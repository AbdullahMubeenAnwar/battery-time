import SwiftUI

struct DiagnosticSectionView: View {
    let title: String
    let rows: [(String, String)]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.headline)

            VStack(spacing: 0) {
                ForEach(rows.indices, id: \.self) { index in
                    DiagnosticRow(
                        title: rows[index].0,
                        value: rows[index].1,
                        showsDivider: index != rows.indices.last
                    )
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .batteryGlassPanel()
    }
}

private struct DiagnosticRow: View {
    let title: String
    let value: String
    let showsDivider: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer(minLength: 24)

                Text(value)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                    .monospacedDigit()
            }
            .font(.callout)
            .frame(minHeight: 28)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(title), \(value)")

            if showsDivider {
                Divider()
                    .opacity(0.45)
            }
        }
    }
}
