import Foundation

enum EstimateConfidence: String, Equatable {
    case stable
    case changingFast
    case learning
    case pluggedIn
    case unavailable

    var title: String {
        switch self {
        case .stable:
            return "Stable drain rate"
        case .changingFast:
            return "Drain rate changing"
        case .learning:
            return "Learning drain rate"
        case .pluggedIn:
            return "Plugged in"
        case .unavailable:
            return "Unavailable"
        }
    }

    var explanation: String {
        switch self {
        case .stable:
            return "Recent battery usage is consistent."
        case .changingFast:
            return "Recent usage changed, so runtime can move quickly."
        case .learning:
            return "Needs 10 minutes of battery samples."
        case .pluggedIn:
            return "The battery is connected to power."
        case .unavailable:
            return "Battery estimate data is unavailable."
        }
    }

    var systemImage: String {
        switch self {
        case .stable:
            return "checkmark.seal"
        case .changingFast:
            return "exclamationmark.triangle"
        case .learning:
            return "hourglass"
        case .pluggedIn:
            return "powerplug"
        case .unavailable:
            return "questionmark.circle"
        }
    }
}
