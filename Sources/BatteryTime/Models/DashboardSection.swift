import Foundation

enum DashboardSection: String, CaseIterable, Identifiable {
    case overview
    case usage

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview:
            return "Overview"
        case .usage:
            return "Usage"
        }
    }

    var systemImage: String {
        switch self {
        case .overview:
            return "battery.75percent"
        case .usage:
            return "chart.bar.xaxis"
        }
    }
}
