import SwiftUI

struct UsageChartCallout: View {
    let title: String
    let rows: [String]
    let tint: Color
    let isPinned: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                if isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption2)
                        .foregroundStyle(tint)
                }

                Text(title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .monospacedDigit()
            }

            ForEach(rows, id: \.self) { row in
                Text(row)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .frame(maxWidth: 190, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(tint.opacity(isPinned ? 0.65 : 0.35), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.18), radius: 10, y: 4)
        .accessibilityElement(children: .combine)
    }
}
