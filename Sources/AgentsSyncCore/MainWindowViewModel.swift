import Foundation

// 中文注释：MainWindowViewModel 表达主窗口状态流，后续 SwiftUI View 保持轻量。
public final class MainWindowViewModel {
    public private(set) var directories: [ToolDirectory]
    public private(set) var differenceCount: Int = 0
    public private(set) var conflictCount: Int = 0
    public private(set) var plan = SyncPlan()

    private let scanner: SkillScanning
    private let diffEngine: DiffEngine
    private let planner: SyncPlanner

    public init(
        directories: [ToolDirectory],
        scanner: SkillScanning,
        diffEngine: DiffEngine = DiffEngine(),
        planner: SyncPlanner = SyncPlanner()
    ) {
        self.directories = directories
        self.scanner = scanner
        self.diffEngine = diffEngine
        self.planner = planner
    }

    public func scanDifferences() throws {
        let activeDirectories = DirectoryRegistry.activeDirectories(from: directories)
        let results = try activeDirectories.map { try scanner.scan(directory: $0) }
        let diffs = diffEngine.diff(scanResults: results)
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
        differenceCount = plan.operations.count + plan.conflicts.count
    }
}
