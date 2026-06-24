import XCTest
@testable import AgentsSyncCore

final class DirectoryRegistryTests: XCTestCase {
    func test_registersPresetAndCustomDirectories() throws {
        let registry = DirectoryRegistry(homeDirectory: URL(fileURLWithPath: "/Users/example"))
        let customURL = URL(fileURLWithPath: "/tmp/shared-skills")

        let directories = registry.defaultDirectories() + [
            registry.customDirectory(name: "Cursor 手动目录", skillsURL: customURL)
        ]

        XCTAssertTrue(directories.contains { $0.kind == .codex && $0.skillsURL.path == "/Users/example/.codex/skills" })
        XCTAssertTrue(directories.contains { $0.kind == .claude && $0.skillsURL.path == "/Users/example/.claude/skills" })
        XCTAssertTrue(directories.contains { $0.kind == .custom && $0.skillsURL == customURL })
    }

    func test_presetsAreUserScoped() {
        let registry = DirectoryRegistry(homeDirectory: URL(fileURLWithPath: "/Users/example"))

        let directories = registry.defaultDirectories()

        XCTAssertTrue(directories.allSatisfy { $0.scope == .user })
    }

    func test_customProjectDirectoryRecordsProjectRoot() {
        let registry = DirectoryRegistry(homeDirectory: URL(fileURLWithPath: "/Users/example"))
        let projectRoot = URL(fileURLWithPath: "/Users/example/project")

        let directory = registry.customDirectory(
            name: "工程级 Codex",
            skillsURL: projectRoot.appendingPathComponent(".codex/skills"),
            scope: .project(projectRoot: projectRoot)
        )

        XCTAssertEqual(directory.scope, .project(projectRoot: projectRoot))
    }

    func test_ignoresDisabledDirectoriesWhenListingActiveOnes() {
        let enabled = ToolDirectory(id: "enabled", name: "Enabled", skillsURL: URL(fileURLWithPath: "/tmp/enabled"), kind: .custom, isEnabled: true)
        let disabled = ToolDirectory(id: "disabled", name: "Disabled", skillsURL: URL(fileURLWithPath: "/tmp/disabled"), kind: .custom, isEnabled: false)

        XCTAssertEqual(DirectoryRegistry.activeDirectories(from: [enabled, disabled]).map(\.id), ["enabled"])
    }
}
