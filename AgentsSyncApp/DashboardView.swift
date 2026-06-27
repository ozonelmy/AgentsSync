import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var viewModel: AgentsSyncAppViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("AgentsSync")
                        .font(.largeTitle.bold())
                    Text(lastScanText)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    viewModel.scanDifferences()
                } label: {
                    Label("扫描差异", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderedProminent)
            }

            HStack(spacing: 16) {
                MetricTile(title: "目录", value: "\(viewModel.directories.count)")
                MetricTile(title: "差异", value: "\(viewModel.differenceCount)")
                MetricTile(title: "冲突", value: "\(viewModel.conflictCount)")
                MetricTile(title: "历史", value: "\(viewModel.history.count)")
            }

            DirectoryTableView()

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            }
        }
        .padding(24)
    }

    private var lastScanText: String {
        guard let date = viewModel.lastScanDate else { return "最近扫描：尚未扫描" }
        return "最近扫描：\(date.formatted(date: .abbreviated, time: .standard))"
    }
}

private struct MetricTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.monospacedDigit().bold())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
    }
}
