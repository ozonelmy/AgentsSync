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
