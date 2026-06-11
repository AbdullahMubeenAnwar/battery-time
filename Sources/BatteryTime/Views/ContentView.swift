import AppKit
import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 0) {
            AppTitlebarView()
            BatteryDetailView()
        }
        .ignoresSafeArea(.container, edges: .top)
    }
}
