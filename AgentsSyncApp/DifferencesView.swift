import SwiftUI

struct DifferencesView: View {
    @EnvironmentObject private var viewModel: AgentsSyncAppViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("差异")
                    .font(.title.bold())
                Spacer()
                Button {
                    viewModel.executePlan()
                } label: {
                    Label("执行同步", systemImage: "play.fill")
                }
                .disabled(!viewModel.plan.conflicts.isEmpty || viewModel.plan.operations.isEmpty)
            }

            List {
                ForEach(viewModel.diffs.indices, id: \.self) { index in
                    DifferenceRow(diff: viewModel.diffs[index])
                }

                if !viewModel.plan.confirmations.isEmpty {
                    Section("待确认") {
                        ForEach(viewModel.plan.confirmations, id: \.identity) { confirmation in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(confirmation.skillName).font(.headline)
                                    Text(confirmation.reason.displayText)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button {
                                    viewModel.confirm(confirmation)
                                } label: {
                                    Label("确认", systemImage: "checkmark.circle")
                                }
                            }
                        }
                    }
                }

                if !viewModel.plan.conflicts.isEmpty {
                    Section("冲突") {
                        ForEach(viewModel.plan.conflicts, id: \.skillName) { conflict in
                            ConflictRow(conflict: conflict)
                        }
                    }
                }
            }
            .listStyle(.inset)
        }
        .padding(24)
    }
}

private struct DifferenceRow: View {
    let diff: SkillDiff

    var body: some View {
        HStack {
            Label(title, systemImage: systemImage)
            Spacer()
            Text(detail)
                .foregroundStyle(.secondary)
        }
    }

    private var title: String {
        switch diff {
        case .missing(let skillName, _, _),
             .conflict(let skillName, _),
             .noDifference(let skillName, _),
             .scopeOverride(let skillName, _, _),
             .confirmationRequired(let skillName, _, _, _):
            return skillName
        }
    }

    private var detail: String {
        switch diff {
        case .missing(_, let sourceDirectoryID, let targetDirectoryIDs):
            return "新增/缺失：\(sourceDirectoryID) -> \(targetDirectoryIDs.joined(separator: ", "))"
        case .conflict(_, let sourceDirectoryIDs):
            return "冲突：\(sourceDirectoryIDs.joined(separator: ", "))"
        case .noDifference(_, let directoryIDs):
            return "无差异：\(directoryIDs.joined(separator: ", "))"
        case .scopeOverride(_, let effectiveDirectoryID, let overriddenDirectoryIDs):
            return "作用域覆盖：\(effectiveDirectoryID) 覆盖 \(overriddenDirectoryIDs.joined(separator: ", "))"
        case .confirmationRequired(_, let sourceDirectoryID, let targetDirectoryID, let reason):
            return "\(reason.displayText)：\(sourceDirectoryID) -> \(targetDirectoryID)"
        }
    }

    private var systemImage: String {
        switch diff {
        case .missing:
            return "plus.circle"
        case .conflict:
            return "exclamationmark.triangle"
        case .noDifference:
            return "checkmark.circle"
        case .scopeOverride:
            return "square.2.layers.3d"
        case .confirmationRequired:
            return "hand.raised"
        }
    }
}

private struct ConflictRow: View {
    @EnvironmentObject private var viewModel: AgentsSyncAppViewModel
    let conflict: SkillConflict

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(conflict.skillName)
                .font(.headline)
            HStack {
                ForEach(conflict.sourceDirectoryIDs, id: \.self) { sourceID in
                    Button {
                        viewModel.resolve(conflict, choosing: sourceID)
                    } label: {
                        Label(sourceID, systemImage: "checkmark.circle")
                    }
                }
                Button(role: .cancel) {
                    viewModel.skip(conflict)
                } label: {
                    Label("跳过", systemImage: "minus.circle")
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private extension ConfirmationRequiredOperation {
    var identity: String {
        "\(skillName)-\(sourceDirectoryID)-\(targetDirectoryID)"
    }
}

extension ConfirmationReason {
    var displayText: String {
        switch self {
        case .userToProject:
            return "添加到当前工程"
        case .projectToUser:
            return "提升为用户级，需检查私有信息"
        case .globalImport:
            return "导入副本"
        }
    }
}
