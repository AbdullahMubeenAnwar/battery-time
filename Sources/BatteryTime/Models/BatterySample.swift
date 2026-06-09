import Foundation

struct BatterySample: Identifiable, Equatable {
    let id = UUID()
    let date: Date
    let percentage: Int
    let isPluggedIn: Bool
    let isCharging: Bool
}
