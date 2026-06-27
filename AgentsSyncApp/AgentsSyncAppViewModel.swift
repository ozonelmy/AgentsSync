import AppKit
import Combine
import Foundation

@MainActor
final class AgentsSyncAppViewModel: ObservableObject {
    @Published private(set) var directories: [ToolDirectory] = []
    @Published private(set) var diffs: [SkillDiff] = []
    @Published private(set) var plan = SyncPlan()
    @Published private(set) var history: [SyncHistoryEntry] = []
    @Published private(set) var lastScanDate: Date?
    @Published private(set) var differenceCount = 0
    @Published private(set) var conflictCount = 0
    @Published private(set) var gitStatus = ""
    @Published var gitSharedRepositoryPath = ""
    @Published var errorMessage: String?
    @Published var newDirectoryName = ""
    @Published var newDirectoryPath = ""
    @Published var newDirectoryScope = DirectoryScopeSelection.user
    @Published var newDirectoryProjectPath = ""

    private let fileManager: FileManager
    private let registry: DirectoryRegistry
    private let storage: JSONAppStorage
    private var gitSharedRepositoryURL: URL?

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        registry = DirectoryRegistry(homeDirectory: fileManager.homeDirectoryForCurrentUser)
        let storageURL = (try? JSONAppStorage.defaultFileURL(fileManager: fileManager))
            ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/AgentsSync/state.json")
        storage = JSONAppStorage(fileURL: storageURL, defaults: registry.defaultDirectories(), fileManager: fileManager)
        load()
    }

    func load() {
        do {
            let state = try storage.load()
            directories = state.directories
            history = state.history
            gitSharedRepositoryURL = state.gitSharedRepositoryURL
            gitSharedRepositoryPath = state.gitSharedRepositoryURL?.path ?? ""
            refreshGitStatus()
        } catch {
            errorMessage = String(describing: error)
            directories = registry.defaultDirectories()
        }
    }

    func scanDifferences() {
        do {
            let mainViewModel = makeMainWindowViewModel()
            try mainViewModel.scanDifferences()
            apply(mainViewModel)
        } catch {
            errorMessage = String(describing: error)
        }
    }

    func resolve(_ conflict: SkillConflict, choosing sourceDirectoryID: String) {
        let mainViewModel = makeMainWindowViewModel()
        mainViewModel.plan = plan
        mainViewModel.resolveConflict(skillName: conflict.skillName, chosenSourceDirectoryID: sourceDirectoryID)
        apply(mainViewModel)
    }

    func skip(_ conflict: SkillConflict) {
        let mainViewModel = makeMainWindowViewModel()
        mainViewModel.plan = plan
        mainViewModel.skipConflict(skillName: conflict.skillName)
        apply(mainViewModel)
    }

    func confirm(_ confirmation: ConfirmationRequiredOperation) {
        let mainViewModel = makeMainWindowViewModel()
        mainViewModel.plan = plan
        mainViewModel.confirmOperation(
            skillName: confirmation.skillName,
            sourceDirectoryID: confirmation.sourceDirectoryID,
            targetDirectoryID: confirmation.targetDirectoryID
        )
        apply(mainViewModel)
    }

    func executePlan() {
        let mainViewModel = makeMainWindowViewModel()
        mainViewModel.plan = plan
        mainViewModel.executePlan(commitMessage: "Sync skills")
        apply(mainViewModel)
        persist()
        refreshGitStatus()
    }

    func restore(_ snapshot: BackupSnapshot, to directory: ToolDirectory) {
        do {
            let store = BackupStore(rootURL: backupRootURL, fileManager: fileManager)
            let targetURL = directory.skillsURL.appendingPathComponent(snapshot.skillName, isDirectory: true)
            try store.restore(snapshot: snapshot, to: targetURL)
            history.insert(SyncHistoryEntry(
                id: UUID(),
                date: Date(),
                status: .succeeded,
                message: "已恢复 \(snapshot.skillName)",
                operations: [],
                backups: [snapshot]
            ), at: 0)
            persist()
        } catch {
            errorMessage = String(describing: error)
        }
    }

    func addCustomDirectory() {
        guard !newDirectoryName.isEmpty, !newDirectoryPath.isEmpty else { return }
        let skillsURL = URL(fileURLWithPath: newDirectoryPath, isDirectory: true)
        let scope: ToolDirectoryScope
        switch newDirectoryScope {
        case .global:
            scope = .global
        case .user:
            scope = .user
        case .project:
            guard !newDirectoryProjectPath.isEmpty else { return }
            scope = .project(projectRoot: URL(fileURLWithPath: newDirectoryProjectPath, isDirectory: true))
        }
        directories.append(registry.customDirectory(name: newDirectoryName, skillsURL: skillsURL, scope: scope))
        newDirectoryName = ""
        newDirectoryPath = ""
        newDirectoryProjectPath = ""
        persist()
    }

    func removeDirectory(_ directory: ToolDirectory) {
        directories.removeAll { $0.id == directory.id }
        persist()
    }

    func toggleDirectory(_ directory: ToolDirectory) {
        directories = directories.map { item in
            guard item.id == directory.id else { return item }
            return ToolDirectory(
                id: item.id,
                name: item.name,
                skillsURL: item.skillsURL,
                kind: item.kind,
                isEnabled: !item.isEnabled,
                scope: item.scope
            )
        }
        persist()
    }

    func chooseDirectoryPath() {
        if let url = chooseDirectory() {
            newDirectoryPath = url.path
        }
    }

    func chooseProjectPath() {
        if let url = chooseDirectory() {
            newDirectoryProjectPath = url.path
        }
    }

    func chooseGitRepositoryPath() {
        if let url = chooseDirectory() {
            gitSharedRepositoryPath = url.path
            updateGitRepositoryPath()
        }
    }

    func updateGitRepositoryPath() {
        let trimmed = gitSharedRepositoryPath.trimmingCharacters(in: .whitespacesAndNewlines)
        gitSharedRepositoryURL = trimmed.isEmpty ? nil : URL(fileURLWithPath: trimmed, isDirectory: true)
        persist()
        refreshGitStatus()
    }

    func refreshGitStatus() {
        guard let gitSharedRepositoryURL else {
            gitStatus = ""
            return
        }
        do {
            gitStatus = try GitRepository(repositoryURL: gitSharedRepositoryURL).status()
        } catch {
            gitStatus = String(describing: error)
        }
    }

    private func makeMainWindowViewModel() -> MainWindowViewModel {
        MainWindowViewModel(
            directories: effectiveDirectories,
            scanner: SkillScanner(fileManager: fileManager),
            coordinator: makeCoordinator(),
            history: history
        )
    }

    private func makeCoordinator() -> SyncCoordinator {
        SyncCoordinator(
            executor: SyncExecutor(
                fileManager: fileManager,
                backupStore: BackupStore(rootURL: backupRootURL, fileManager: fileManager)
            ),
            gitRepository: gitSharedRepositoryURL.map { GitRepository(repositoryURL: $0) }
        )
    }

    private var effectiveDirectories: [ToolDirectory] {
        guard let gitSharedRepositoryURL else { return directories }
        let gitDirectory = ToolDirectory(
            id: "git-shared",
            name: "Git 共享库",
            skillsURL: gitSharedRepositoryURL.appendingPathComponent("skills", isDirectory: true),
            kind: .gitShared,
            isEnabled: true,
            scope: .user
        )
        if directories.contains(where: { $0.id == gitDirectory.id }) {
            return directories
        }
        return directories + [gitDirectory]
    }

    private var backupRootURL: URL {
        let applicationSupportURL = (try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        return applicationSupportURL.appendingPathComponent("AgentsSync/Backups", isDirectory: true)
    }

    private func apply(_ mainViewModel: MainWindowViewModel) {
        directories = mainViewModel.directories.filter { $0.kind != .gitShared }
        diffs = mainViewModel.diffs
        plan = mainViewModel.plan
        history = mainViewModel.history
        lastScanDate = mainViewModel.lastScanDate ?? lastScanDate
        differenceCount = mainViewModel.differenceCount
        conflictCount = mainViewModel.conflictCount
        errorMessage = mainViewModel.lastErrorMessage
    }

    private func persist() {
        do {
            try storage.save(AgentsSyncStoredState(
                directories: directories,
                gitSharedRepositoryURL: gitSharedRepositoryURL,
                history: history
            ))
        } catch {
            errorMessage = String(describing: error)
        }
    }

    private func chooseDirectory() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        return panel.runModal() == .OK ? panel.url : nil
    }
}

enum DirectoryScopeSelection: String, CaseIterable, Identifiable {
    case global = "全局级"
    case user = "用户级"
    case project = "工程级"

    var id: String { rawValue }
}
