import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var viewModel: AgentsSyncAppViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("历史")
                .font(.title.bold())

            List(viewModel.history, id: \.id) { entry in
                HistoryEntryRow(entry: entry)
            }
            .listStyle(.inset)
        }
        .padding(24)
    }
}

private struct HistoryEntryRow: View {
    let entry: SyncHistoryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(statusTitle, systemImage: statusIcon)
                Spacer()
                Text(entry.date.formatted(date: .abbreviated, time: .standard))
                    .foregroundStyle(.secondary)
            }
            Text(entry.message)
                .foregroundColor(entry.status == .succeeded ? Color.secondary : Color.red)
            if !entry.operations.isEmpty {
                Text("操作：\(entry.operations.count)")
                    .foregroundStyle(.secondary)
            }
            ForEach(entry.backups, id: \.self) { backup in
                RestoreBackupRow(snapshot: backup)
            }
        }
        .padding(.vertical, 6)
    }

    private var statusTitle: String {
        entry.status == .succeeded ? "成功" : "失败"
    }

    private var statusIcon: String {
        entry.status == .succeeded ? "checkmark.circle" : "xmark.octagon"
    }
}

private struct RestoreBackupRow: View {
    @EnvironmentObject private var viewModel: AgentsSyncAppViewModel
    let snapshot: BackupSnapshot
    @State private var targetDirectoryID = ""

    var body: some View {
        HStack {
            Text("备份：\(snapshot.skillName)")
            Spacer()
            Picker("目标", selection: $targetDirectoryID) {
                ForEach(viewModel.directories, id: \.id) { directory in
                    Text(directory.name).tag(directory.id)
                }
            }
            .frame(width: 180)
            Button {
                if let directory = viewModel.directories.first(where: { $0.id == targetDirectoryID }) ?? viewModel.directories.first {
                    viewModel.restore(snapshot, to: directory)
                }
            } label: {
                Label("恢复", systemImage: "arrow.counterclockwise")
            }
        }
        .onAppear {
            if targetDirectoryID.isEmpty {
                targetDirectoryID = viewModel.directories.first?.id ?? ""
            }
        }
    }
}
