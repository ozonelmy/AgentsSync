import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var viewModel: AgentsSyncAppViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("设置")
                    .font(.title.bold())

                VStack(alignment: .leading, spacing: 12) {
                    Text("目录")
                        .font(.headline)
                    ForEach(viewModel.directories, id: \.id) { directory in
                        HStack {
                            Toggle(isOn: Binding(
                                get: { directory.isEnabled },
                                set: { _ in viewModel.toggleDirectory(directory) }
                            )) {
                                VStack(alignment: .leading) {
                                    Text(directory.name)
                                    Text(directory.skillsURL.path)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                            }
                            Spacer()
                            Text(scopeText(directory.scope))
                                .foregroundStyle(.secondary)
                            Button(role: .destructive) {
                                viewModel.removeDirectory(directory)
                            } label: {
                                Label("移除", systemImage: "trash")
                            }
                            .disabled(directory.kind == .codex || directory.kind == .claude)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("添加目录")
                        .font(.headline)
                    TextField("名称", text: $viewModel.newDirectoryName)
                    HStack {
                        TextField("skills 路径", text: $viewModel.newDirectoryPath)
                        Button {
                            viewModel.chooseDirectoryPath()
                        } label: {
                            Label("选择", systemImage: "folder")
                        }
                    }
                    Picker("作用域", selection: $viewModel.newDirectoryScope) {
                        ForEach(DirectoryScopeSelection.allCases) { scope in
                            Text(scope.rawValue).tag(scope)
                        }
                    }
                    .pickerStyle(.segmented)
                    if viewModel.newDirectoryScope == .project {
                        HStack {
                            TextField("工程路径", text: $viewModel.newDirectoryProjectPath)
                            Button {
                                viewModel.chooseProjectPath()
                            } label: {
                                Label("选择", systemImage: "folder.badge.gearshape")
                            }
                        }
                    }
                    Button {
                        viewModel.addCustomDirectory()
                    } label: {
                        Label("添加", systemImage: "plus")
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Git 共享库")
                        .font(.headline)
                    HStack {
                        TextField("仓库路径", text: $viewModel.gitSharedRepositoryPath)
                            .onSubmit { viewModel.updateGitRepositoryPath() }
                        Button {
                            viewModel.chooseGitRepositoryPath()
                        } label: {
                            Label("选择", systemImage: "arrow.triangle.branch")
                        }
                        Button {
                            viewModel.refreshGitStatus()
                        } label: {
                            Label("状态", systemImage: "waveform.path.ecg")
                        }
                    }
                    if !viewModel.gitStatus.isEmpty {
                        Text(viewModel.gitStatus)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
            .padding(24)
        }
    }
}

func scopeText(_ scope: ToolDirectoryScope) -> String {
    switch scope {
    case .global:
        return "全局级"
    case .user:
        return "用户级"
    case .project(let projectRoot):
        return "工程级：\(projectRoot.lastPathComponent)"
    }
}
