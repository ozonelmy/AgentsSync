import Foundation

// 中文注释：MainWindowViewModel 表达主窗口状态流，后续 SwiftUI View 保持轻量。
public final class MainWindowViewModel {
    public private(set) var directories: [ToolDirectory]
    public private(set) var differenceCount: Int = 0
    public private(set) var conflictCount: Int = 0
    public private(set) var lastScanDate: Date?
    public private(set) var diffs: [SkillDiff] = []
    public var plan = SyncPlan()
    public private(set) var history: [SyncHistoryEntry]
    public private(set) var lastErrorMessage: String?

    private let scanner: SkillScanning
    private let diffEngine: DiffEngine
    private let planner: SyncPlanner
    private let coordinator: SyncCoordinating?
    private let clock: () -> Date

    public init(
        directories: [ToolDirectory],
        scanner: SkillScanning,
        diffEngine: DiffEngine = DiffEngine(),
        planner: SyncPlanner = SyncPlanner(),
        coordinator: SyncCoordinating? = nil,
        history: [SyncHistoryEntry] = [],
        clock: @escaping () -> Date = Date.init
    ) {
        self.directories = directories
        self.scanner = scanner
        self.diffEngine = diffEngine
        self.planner = planner
        self.coordinator = coordinator
        self.history = history
        self.clock = clock
    }

    public func scanDifferences() throws {
        let activeDirectories = DirectoryRegistry.activeDirectories(from: directories)
        let results = try activeDirectories.map { try scanner.scan(directory: $0) }
        diffs = diffEngine.diff(scanResults: results)
        lastScanDate = clock()
        differenceCount = diffs.filter {
            if case .noDifference = $0 { return false }
            return true
        }.count
        plan = planner.makePlan(from: diffs)
        conflictCount = plan.conflicts.count
    }

    public func resolveConflict(skillName: String, chosenSourceDirectoryID: String) {
        guard let conflict = plan.conflicts.first(where: { $0.skillName == skillName }) else { return }
        let newOperations = conflict.sourceDirectoryIDs
            .filter { $0 != chosenSourceDirectoryID }
            .map { SyncOperation.copySkill(skillName: skillName, sourceDirectoryID: chosenSourceDirectoryID, targetDirectoryID: $0) }
        plan.operations.append(contentsOf: newOperations)
        plan.conflicts.removeAll { $0.skillName == skillName }
        conflictCount = plan.conflicts.count
        updateDifferenceCountFromPlan()
    }

    public func skipConflict(skillName: String) {
        plan.conflicts.removeAll { $0.skillName == skillName }
        conflictCount = plan.conflicts.count
        updateDifferenceCountFromPlan()
    }

    public func confirmOperation(skillName: String, sourceDirectoryID: String, targetDirectoryID: String) {
        guard plan.confirmations.contains(where: {
            $0.skillName == skillName &&
                $0.sourceDirectoryID == sourceDirectoryID &&
                $0.targetDirectoryID == targetDirectoryID
        }) else {
            return
        }
        plan.operations.append(.copySkill(
            skillName: skillName,
            sourceDirectoryID: sourceDirectoryID,
            targetDirectoryID: targetDirectoryID
        ))
        plan.confirmations.removeAll {
            $0.skillName == skillName &&
                $0.sourceDirectoryID == sourceDirectoryID &&
                $0.targetDirectoryID == targetDirectoryID
        }
        updateDifferenceCountFromPlan()
    }

    public func executePlan(commitMessage: String) {
        guard let coordinator else {
            let entry = SyncHistoryEntry(
                id: UUID(),
                date: clock(),
                status: .failed,
                message: "未配置同步执行器",
                operations: plan.operations,
                backups: []
            )
            record(entry)
            return
        }
        let directoriesByID = Dictionary(uniqueKeysWithValues: directories.map { ($0.id, $0) })
        let entry = coordinator.execute(plan: plan, directoriesByID: directoriesByID, commitMessage: commitMessage)
        record(entry)
    }

    public func replaceDirectories(_ directories: [ToolDirectory]) {
        self.directories = directories
    }

    private func record(_ entry: SyncHistoryEntry) {
        history.insert(entry, at: 0)
        lastErrorMessage = entry.status == .failed ? entry.message : nil
    }

    private func updateDifferenceCountFromPlan() {
        differenceCount = plan.operations.count + plan.conflicts.count + plan.confirmations.count
    }
}
