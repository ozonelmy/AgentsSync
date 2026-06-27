import XCTest
@testable import AgentsSyncCore

final class MainWindowViewModelTests: XCTestCase {
    func test_scanUpdatesCountsAndConflicts() throws {
        let codex = ToolDirectory(id: "codex", name: "Codex", skillsURL: URL(fileURLWithPath: "/codex"), kind: .codex, isEnabled: true)
        let claude = ToolDirectory(id: "claude", name: "Claude", skillsURL: URL(fileURLWithPath: "/claude"), kind: .claude, isEnabled: true)
        let viewModel = MainWindowViewModel(
            directories: [codex, claude],
            scanner: StubScanner(results: [
                ScanResult(directory: codex, skills: [SkillSnapshot(name: "writer", relativePath: "writer", fingerprint: "a")]),
                ScanResult(directory: claude, skills: [SkillSnapshot(name: "writer", relativePath: "writer", fingerprint: "b")])
            ])
        )

        try viewModel.scanDifferences()

        XCTAssertEqual(viewModel.differenceCount, 1)
        XCTAssertEqual(viewModel.conflictCount, 1)
        XCTAssertFalse(viewModel.plan.conflicts.isEmpty)
        XCTAssertNotNil(viewModel.lastScanDate)
    }

    func test_resolvingConflictAddsCopyOperationsForChosenSource() throws {
        let codex = ToolDirectory(id: "codex", name: "Codex", skillsURL: URL(fileURLWithPath: "/codex"), kind: .codex, isEnabled: true)
        let claude = ToolDirectory(id: "claude", name: "Claude", skillsURL: URL(fileURLWithPath: "/claude"), kind: .claude, isEnabled: true)
        let viewModel = MainWindowViewModel(
            directories: [codex, claude],
            scanner: StubScanner(results: [
                ScanResult(directory: codex, skills: [SkillSnapshot(name: "writer", relativePath: "writer", fingerprint: "a")]),
                ScanResult(directory: claude, skills: [SkillSnapshot(name: "writer", relativePath: "writer", fingerprint: "b")])
            ])
        )
        try viewModel.scanDifferences()

        viewModel.resolveConflict(skillName: "writer", chosenSourceDirectoryID: "codex")

        XCTAssertEqual(viewModel.plan.operations, [
            .copySkill(skillName: "writer", sourceDirectoryID: "codex", targetDirectoryID: "claude")
        ])
        XCTAssertTrue(viewModel.plan.conflicts.isEmpty)
    }

    func test_confirmingCrossScopeActionAddsCopyOperation() throws {
        let userDirectory = ToolDirectory(id: "user", name: "用户级", skillsURL: URL(fileURLWithPath: "/user"), kind: .custom, isEnabled: true, scope: .user)
        let projectDirectory = ToolDirectory(
            id: "project",
            name: "工程级",
            skillsURL: URL(fileURLWithPath: "/project/.codex/skills"),
            kind: .custom,
            isEnabled: true,
            scope: .project(projectRoot: URL(fileURLWithPath: "/project"))
        )
        let viewModel = MainWindowViewModel(
            directories: [userDirectory, projectDirectory],
            scanner: StubScanner(results: [
                ScanResult(directory: userDirectory, skills: [SkillSnapshot(name: "writer", relativePath: "writer", fingerprint: "a")]),
                ScanResult(directory: projectDirectory, skills: [])
            ])
        )
        try viewModel.scanDifferences()

        viewModel.confirmOperation(skillName: "writer", sourceDirectoryID: "user", targetDirectoryID: "project")

        XCTAssertEqual(viewModel.plan.operations, [
            .copySkill(skillName: "writer", sourceDirectoryID: "user", targetDirectoryID: "project")
        ])
        XCTAssertTrue(viewModel.plan.confirmations.isEmpty)
    }

    func test_executeSuccessfulPlanRecordsHistory() throws {
        let codex = ToolDirectory(id: "codex", name: "Codex", skillsURL: URL(fileURLWithPath: "/codex"), kind: .codex, isEnabled: true)
        let operation = SyncOperation.copySkill(skillName: "writer", sourceDirectoryID: "codex", targetDirectoryID: "claude")
        let viewModel = MainWindowViewModel(
            directories: [codex],
            scanner: StubScanner(results: []),
            coordinator: StubCoordinator(result: SyncHistoryEntry(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!,
                date: Date(timeIntervalSince1970: 4),
                status: .succeeded,
                message: "同步完成",
                operations: [operation],
                backups: []
            ))
        )
        viewModel.plan = SyncPlan(operations: [operation])

        viewModel.executePlan(commitMessage: "Sync skills")

        XCTAssertEqual(viewModel.history.map(\.status), [.succeeded])
        XCTAssertNil(viewModel.lastErrorMessage)
    }

    func test_executeFailedPlanKeepsErrorVisible() throws {
        let operation = SyncOperation.copySkill(skillName: "writer", sourceDirectoryID: "codex", targetDirectoryID: "claude")
        let viewModel = MainWindowViewModel(
            directories: [],
            scanner: StubScanner(results: []),
            coordinator: StubCoordinator(result: SyncHistoryEntry(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000005")!,
                date: Date(timeIntervalSince1970: 5),
                status: .failed,
                message: "Git 执行失败：pull failed",
                operations: [operation],
                backups: []
            ))
        )
        viewModel.plan = SyncPlan(operations: [operation])

        viewModel.executePlan(commitMessage: "Sync skills")

        XCTAssertEqual(viewModel.history.map(\.status), [.failed])
        XCTAssertEqual(viewModel.lastErrorMessage, "Git 执行失败：pull failed")
        XCTAssertEqual(viewModel.plan.operations, [operation])
    }
}

private struct StubScanner: SkillScanning {
    let results: [ScanResult]

    // 中文注释：测试替身只返回固定扫描结果，让 ViewModel 测试聚焦状态流。
    func scan(directory: ToolDirectory) throws -> ScanResult {
        guard let result = results.first(where: { $0.directory.id == directory.id }) else {
            throw SyncError.directoryNotFound(directory.id)
        }
        return result
    }
}

private struct StubCoordinator: SyncCoordinating {
    let result: SyncHistoryEntry

    func execute(plan: SyncPlan, directoriesByID: [String: ToolDirectory], commitMessage: String) -> SyncHistoryEntry {
        result
    }
}
