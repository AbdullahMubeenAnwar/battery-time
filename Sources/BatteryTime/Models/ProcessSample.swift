import Foundation

struct ProcessSample: Identifiable, Equatable {
    let id = UUID()
    let pid: Int
    let name: String
    let energyImpact: Double
    let cpuPercent: Double

    var usageText: String {
        String(format: "%.1f impact", energyImpact)
    }

    var cpuText: String {
        String(format: "%.1f%% CPU", cpuPercent)
    }

    var accessibilityText: String {
        "\(name), energy impact \(String(format: "%.1f", energyImpact)), \(cpuText). Higher energy impact can reduce remaining runtime."
    }
}
