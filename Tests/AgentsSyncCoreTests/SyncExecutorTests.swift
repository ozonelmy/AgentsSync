import XCTest
@testable import AgentsSyncCore

final class SyncExecutorTests: XCTestCase {
    func test_copiesMissingSkillIntoTargetDirectory() throws {
        let root = try TemporaryDirectory()
        let sourceSkills = root.url.appendingPathComponent("source/skills")
        let targetSkills = root.url.appendingPathComponent("target/skills")
        try makeSkill(named: "writer", in: sourceSkills, files: ["SKILL.md": "content"])
        try FileManager.default.createDirectory(at: targetSkills, withIntermediateDirectories: true)

        let executor = SyncExecutor(fileManager: .default, backupStore: BackupStore(rootURL: root.url.appendingPathComponent("backups"), fileManager: .default))
        try executor.execute(
            operations: [.copySkill(skillName: "writer", sourceDirectoryID: "source", targetDirectoryID: "target")],
            directoriesByID: [
                "source": ToolDirectory(id: "source", name: "Source", skillsURL: sourceSkills, kind: .custom, isEnabled: true),
                "target": ToolDirectory(id: "target", name: "Target", skillsURL: targetSkills, kind: .custom, isEnabled: true)
            ]
        )

        let copied = try String(contentsOf: targetSkills.appendingPathComponent("writer/SKILL.md"), encoding: .utf8)
        XCTAssertEqual(copied, "content")
    }

    func test_overwriteCreatesBackupBeforeReplacingSkill() throws {
        let root = try TemporaryDirectory()
        let sourceSkills = root.url.appendingPathComponent("source/skills")
        let targetSkills = root.url.appendingPathComponent("target/skills")
        let backupRoot = root.url.appendingPathComponent("backups")
        try makeSkill(named: "writer", in: sourceSkills, files: ["SKILL.md": "new"])
        try makeSkill(named: "writer", in: targetSkills, files: ["SKILL.md": "old"])

        let executor = SyncExecutor(fileManager: .default, backupStore: BackupStore(rootURL: backupRoot, fileManager: .default))
        try executor.execute(
            operations: [.copySkill(skillName: "writer", sourceDirectoryID: "source", targetDirectoryID: "target")],
            directoriesByID: [
                "source": ToolDirectory(id: "source", name: "Source", skillsURL: sourceSkills, kind: .custom, isEnabled: true),
                "target": ToolDirectory(id: "target", name: "Target", skillsURL: targetSkills, kind: .custom, isEnabled: true)
            ]
        )

        let updated = try String(contentsOf: targetSkills.appendingPathComponent("writer/SKILL.md"), encoding: .utf8)
        let backupFiles = try FileManager.default.contentsOfDirectory(at: backupRoot, includingPropertiesForKeys: nil)
        XCTAssertEqual(updated, "new")
        XCTAssertFalse(backupFiles.isEmpty)
    }

    func test_missingDirectoryStopsExecutionWithError() throws {
        let root = try TemporaryDirectory()
        let executor = SyncExecutor(fileManager: .default, backupStore: BackupStore(rootURL: root.url.appendingPathComponent("backups"), fileManager: .default))

        XCTAssertThrowsError(try executor.execute(
            operations: [.copySkill(skillName: "writer", sourceDirectoryID: "missing", targetDirectoryID: "target")],
            directoriesByID: [
                "target": ToolDirectory(id: "target", name: "Target", skillsURL: root.url.appendingPathComponent("target"), kind: .custom, isEnabled: true)
            ]
        ))
    }
}
