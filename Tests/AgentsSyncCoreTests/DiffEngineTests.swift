import XCTest
@testable import AgentsSyncCore

final class DiffEngineTests: XCTestCase {
    func test_identicalSkillInAllDirectoriesProducesNoOperation() {
        let codex = ToolDirectory(id: "codex", name: "Codex", skillsURL: URL(fileURLWithPath: "/codex"), kind: .codex, isEnabled: true)
        let claude = ToolDirectory(id: "claude", name: "Claude", skillsURL: URL(fileURLWithPath: "/claude"), kind: .claude, isEnabled: true)
        let fingerprint = "same"
        let scan = [
            ScanResult(directory: codex, skills: [SkillSnapshot(name: "writer", relativePath: "writer", fingerprint: fingerprint)]),
            ScanResult(directory: claude, skills: [SkillSnapshot(name: "writer", relativePath: "writer", fingerprint: fingerprint)])
        ]

        let diffs = DiffEngine().diff(scanResults: scan)

        XCTAssertEqual(diffs, [.noDifference(skillName: "writer", directoryIDs: ["claude", "codex"])])
    }

    func test_skillExistingInOneDirectoryProducesMissingDiffForOtherDirectory() {
        let codex = ToolDirectory(id: "codex", name: "Codex", skillsURL: URL(fileURLWithPath: "/codex"), kind: .codex, isEnabled: true)
        let claude = ToolDirectory(id: "claude", name: "Claude", skillsURL: URL(fileURLWithPath: "/claude"), kind: .claude, isEnabled: true)
        let scan = [
            ScanResult(directory: codex, skills: [SkillSnapshot(name: "writer", relativePath: "writer", fingerprint: "a")]),
            ScanResult(directory: claude, skills: [])
        ]

        let diffs = DiffEngine().diff(scanResults: scan)

        XCTAssertEqual(diffs, [.missing(skillName: "writer", sourceDirectoryID: "codex", targetDirectoryIDs: ["claude"])])
    }

    func test_sameSkillWithDifferentFingerprintsProducesConflict() {
        let codex = ToolDirectory(id: "codex", name: "Codex", skillsURL: URL(fileURLWithPath: "/codex"), kind: .codex, isEnabled: true)
        let claude = ToolDirectory(id: "claude", name: "Claude", skillsURL: URL(fileURLWithPath: "/claude"), kind: .claude, isEnabled: true)
        let scan = [
            ScanResult(directory: codex, skills: [SkillSnapshot(name: "writer", relativePath: "writer", fingerprint: "a")]),
            ScanResult(directory: claude, skills: [SkillSnapshot(name: "writer", relativePath: "writer", fingerprint: "b")])
        ]

        let diffs = DiffEngine().diff(scanResults: scan)

        XCTAssertEqual(diffs, [.conflict(skillName: "writer", sourceDirectoryIDs: ["claude", "codex"])])
    }

    func test_sameSkillAcrossUserAndProjectScopesProducesScopeOverrideInsteadOfConflict() {
        let userDirectory = ToolDirectory(id: "user", name: "用户级", skillsURL: URL(fileURLWithPath: "/user"), kind: .custom, isEnabled: true, scope: .user)
        let projectDirectory = ToolDirectory(
            id: "project",
            name: "工程级",
            skillsURL: URL(fileURLWithPath: "/project/.codex/skills"),
            kind: .custom,
            isEnabled: true,
            scope: .project(projectRoot: URL(fileURLWithPath: "/project"))
        )
        let scan = [
            ScanResult(directory: userDirectory, skills: [SkillSnapshot(name: "writer", relativePath: "writer", fingerprint: "user")]),
            ScanResult(directory: projectDirectory, skills: [SkillSnapshot(name: "writer", relativePath: "writer", fingerprint: "project")])
        ]

        let diffs = DiffEngine().diff(scanResults: scan)

        XCTAssertEqual(diffs, [
            .scopeOverride(skillName: "writer", effectiveDirectoryID: "project", overriddenDirectoryIDs: ["user"])
        ])
    }

    func test_globalDirectoryDoesNotBecomeSilentWriteTarget() {
        let globalDirectory = ToolDirectory(id: "global", name: "全局级", skillsURL: URL(fileURLWithPath: "/global"), kind: .custom, isEnabled: true, scope: .global)
        let userDirectory = ToolDirectory(id: "user", name: "用户级", skillsURL: URL(fileURLWithPath: "/user"), kind: .custom, isEnabled: true, scope: .user)
        let scan = [
            ScanResult(directory: globalDirectory, skills: []),
            ScanResult(directory: userDirectory, skills: [SkillSnapshot(name: "writer", relativePath: "writer", fingerprint: "user")])
        ]

        let diffs = DiffEngine().diff(scanResults: scan)

        XCTAssertEqual(diffs, [])
    }

    func test_userSkillMissingFromProjectProducesConfirmationInsteadOfAutomaticWrite() {
        let userDirectory = ToolDirectory(id: "user", name: "用户级", skillsURL: URL(fileURLWithPath: "/user"), kind: .custom, isEnabled: true, scope: .user)
        let projectDirectory = ToolDirectory(
            id: "project",
            name: "工程级",
            skillsURL: URL(fileURLWithPath: "/project/.codex/skills"),
            kind: .custom,
            isEnabled: true,
            scope: .project(projectRoot: URL(fileURLWithPath: "/project"))
        )
        let scan = [
            ScanResult(directory: userDirectory, skills: [SkillSnapshot(name: "writer", relativePath: "writer", fingerprint: "same")]),
            ScanResult(directory: projectDirectory, skills: [])
        ]

        let diffs = DiffEngine().diff(scanResults: scan)

        XCTAssertEqual(diffs, [
            .confirmationRequired(skillName: "writer", sourceDirectoryID: "user", targetDirectoryID: "project", reason: .userToProject)
        ])
    }

    func test_projectSkillMissingFromUserProducesPromotionConfirmation() {
        let userDirectory = ToolDirectory(id: "user", name: "用户级", skillsURL: URL(fileURLWithPath: "/user"), kind: .custom, isEnabled: true, scope: .user)
        let projectDirectory = ToolDirectory(
            id: "project",
            name: "工程级",
            skillsURL: URL(fileURLWithPath: "/project/.codex/skills"),
            kind: .custom,
            isEnabled: true,
            scope: .project(projectRoot: URL(fileURLWithPath: "/project"))
        )
        let scan = [
            ScanResult(directory: userDirectory, skills: []),
            ScanResult(directory: projectDirectory, skills: [SkillSnapshot(name: "writer", relativePath: "writer", fingerprint: "same")])
        ]

        let diffs = DiffEngine().diff(scanResults: scan)

        XCTAssertEqual(diffs, [
            .confirmationRequired(skillName: "writer", sourceDirectoryID: "project", targetDirectoryID: "user", reason: .projectToUser)
        ])
    }

    func test_globalSkillMissingFromUserProducesImportConfirmation() {
        let globalDirectory = ToolDirectory(id: "global", name: "全局级", skillsURL: URL(fileURLWithPath: "/global"), kind: .custom, isEnabled: true, scope: .global)
        let userDirectory = ToolDirectory(id: "user", name: "用户级", skillsURL: URL(fileURLWithPath: "/user"), kind: .custom, isEnabled: true, scope: .user)
        let scan = [
            ScanResult(directory: globalDirectory, skills: [SkillSnapshot(name: "writer", relativePath: "writer", fingerprint: "same")]),
            ScanResult(directory: userDirectory, skills: [])
        ]

        let diffs = DiffEngine().diff(scanResults: scan)

        XCTAssertEqual(diffs, [
            .confirmationRequired(skillName: "writer", sourceDirectoryID: "global", targetDirectoryID: "user", reason: .globalImport)
        ])
    }
}
