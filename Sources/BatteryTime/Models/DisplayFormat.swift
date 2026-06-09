import Foundation

enum DisplayFormat: String, CaseIterable, Identifiable {
    case iconOnly
    case innerPercentage
    case percentOnly
    case timeOnly
    case percentAndTime
    case timeAndPercent

    var id: String { rawValue }

    var title: String {
        switch self {
        case .iconOnly:
            return "None"
        case .innerPercentage:
            return "Percentage inside the icon"
        case .percentOnly:
            return "Percentage"
        case .timeOnly:
            return "Time"
        case .percentAndTime:
            return "Percentage and time"
        case .timeAndPercent:
            return "Time and percentage"
        }
    }

    var accessibilityDescription: String {
        switch self {
        case .iconOnly:
            return "Show no additional information next to the battery icon."
        case .innerPercentage:
            return "Show the battery percentage inside the battery icon."
        case .percentOnly:
            return "Show the battery percentage next to the icon."
        case .timeOnly:
            return "Show estimated time remaining next to the icon."
        case .percentAndTime:
            return "Show percentage on the first line and time remaining below it."
        case .timeAndPercent:
            return "Show time remaining on the first line and percentage below it."
        }
    }
}
