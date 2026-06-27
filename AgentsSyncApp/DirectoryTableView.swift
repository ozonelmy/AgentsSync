import SwiftUI

struct DirectoryTableView: View {
    @EnvironmentObject private var viewModel: AgentsSyncAppViewModel

    var body: some View {
        Table(viewModel.directories) {
            TableColumn("名称") { directory in
                Label(directory.name, systemImage: iconName(for: directory.kind))
            }
            TableColumn("作用域") { directory in
                Text(scopeText(directory.scope))
            }
            TableColumn("状态") { directory in
                Text(directory.isEnabled ? "启用" : "停用")
            }
            TableColumn("路径") { directory in
                Text(directory.skillsURL.path)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            }
        }
        .frame(minHeight: 260)
    }

    private func iconName(for kind: ToolDirectoryKind) -> String {
        switch kind {
        case .codex:
            return "terminal"
        case .claude:
            return "sparkles"
        case .custom:
            return "folder"
        case .gitShared:
            return "arrow.triangle.branch"
        }
    }
}
