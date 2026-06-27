import SwiftUI

struct MainWindowView: View {
    @EnvironmentObject private var viewModel: AgentsSyncAppViewModel
    @State private var selection: SectionSelection? = .dashboard

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Label("首页", systemImage: "square.grid.2x2").tag(SectionSelection.dashboard)
                Label("差异", systemImage: "arrow.left.arrow.right").tag(SectionSelection.differences)
                Label("历史", systemImage: "clock.arrow.circlepath").tag(SectionSelection.history)
                Label("设置", systemImage: "gearshape").tag(SectionSelection.settings)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        } detail: {
            switch selection ?? .dashboard {
            case .dashboard:
                DashboardView()
            case .differences:
                DifferencesView()
            case .history:
                HistoryView()
            case .settings:
                SettingsView()
            }
        }
    }
}

private enum SectionSelection: Hashable {
    case dashboard
    case differences
    case history
    case settings
}
