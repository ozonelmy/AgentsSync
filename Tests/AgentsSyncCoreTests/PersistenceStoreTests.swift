import XCTest
@testable import AgentsSyncCore

final class PersistenceStoreTests: XCTestCase {
    func test_missingStoreLoadsDefaultPresetDirectories() throws {
        let root = try TemporaryDirectory()
        let store = JSONAppStorage(
            fileURL: root.url.appendingPathComponent("Application Support/AgentsSync/state.json"),
            defaults: DirectoryRegistry(homeDirectory: URL(fileURLWithPath: "/Users/example")).defaultDirectories()
        )

        let state = try store.load()

        XCTAssertEqual(state.directories.map(\.id), ["codex", "claude"])
        XCTAssertNil(state.gitSharedRepositoryURL)
        XCTAssertTrue(state.history.isEmpty)
    }

    func test_savesAndLoadsDirectoriesGitPathAndHistory() throws {
        let root = try TemporaryDirectory()
        let fileURL = root.url.appendingPathComponent("Application Support/AgentsSync/state.json")
        let store = JSONAppStorage(fileURL: fileURL, defaults: [])
        let projectRoot = URL(fileURLWithPath: "/Users/example/project")
        let state = AgentsSyncStoredState(
            directories: [
                ToolDirectory(
                    id: "project",
                    name: "工程级 Codex",
                    skillsURL: projectRoot.appendingPathComponent(".codex/skills"),
                    kind: .custom,
                    isEnabled: false,
                    scope: .project(projectRoot: projectRoot)
                )
            ],
            gitSharedRepositoryURL: URL(fileURLWithPath: "/Users/example/shared-skills"),
            history: [
                SyncHistoryEntry(
                    id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                    date: Date(timeIntervalSince1970: 100),
                    status: .succeeded,
                    message: "同步完成",
                    operations: [.copySkill(skillName: "writer", sourceDirectoryID: "codex", targetDirectoryID: "claude")],
                    backups: [BackupSnapshot(skillName: "writer", snapshotURL: URL(fileURLWithPath: "/backup/writer"))]
                )
            ]
        )

        try store.save(state)
        let loaded = try store.load()

        XCTAssertEqual(loaded, state)
    }

    func test_corruptJSONThrowsAndDoesNotOverwriteUserFile() throws {
        let root = try TemporaryDirectory()
        let fileURL = root.url.appendingPathComponent("state.json")
        try "{ broken".write(to: fileURL, atomically: true, encoding: .utf8)
        let store = JSONAppStorage(fileURL: fileURL, defaults: [])

        XCTAssertThrowsError(try store.load())
        let currentContent = try String(contentsOf: fileURL, encoding: .utf8)
        XCTAssertEqual(currentContent, "{ broken")
    }
}
