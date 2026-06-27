import SwiftUI

@main
struct AgentsSyncApplication: App {
    @StateObject private var viewModel = AgentsSyncAppViewModel()

    var body: some Scene {
        WindowGroup {
            MainWindowView()
                .environmentObject(viewModel)
                .frame(minWidth: 1120, minHeight: 720)
        }
        .windowStyle(.titleBar)
    }
}
