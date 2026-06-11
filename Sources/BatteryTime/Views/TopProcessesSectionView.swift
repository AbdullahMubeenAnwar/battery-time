import SwiftUI

struct TopProcessesSectionView: View {
    let processes: [ProcessSample]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Energy Impact")
                    .font(.headline)

                Text("Higher energy impact can reduce remaining runtime.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if processes.isEmpty {
                if #available(macOS 14, *) {
                    ContentUnavailableView(
                        "No Process Data",
                        systemImage: "list.bullet.rectangle",
                        description: Text("Refresh to sample current energy impact.")
                    )
                    .frame(minHeight: 120)
                } else {
                    VStack(spacing: 6) {
                        Image(systemName: "list.bullet.rectangle")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text("No Process Data")
                            .font(.callout.weight(.semibold))
                        Text("Refresh to sample current energy impact.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 120)
                }
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(processes.enumerated()), id: \.element.id) { index, process in
                        ProcessImpactRow(
                            process: process,
                            showsDivider: index != processes.count - 1
                        )
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .batteryGlassPanel()
    }
}

private struct ProcessImpactRow: View {
    let process: ProcessSample
    let showsDivider: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                Text(process.name)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer(minLength: 24)

                Text(process.usageText)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .font(.callout)
            .frame(minHeight: 32)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(process.accessibilityText)

            if showsDivider {
                Divider()
                    .opacity(0.45)
            }
        }
    }
}
