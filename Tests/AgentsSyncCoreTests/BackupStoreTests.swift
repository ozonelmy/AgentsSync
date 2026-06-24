import XCTest
@testable import AgentsSyncCore

final class BackupStoreTests: XCTestCase {
    func test_createsSnapshotBeforeOverwriteAndCanRestoreIt() throws {
        let root = try TemporaryDirectory()
        let backupRoot = root.url.appendingPathComponent("backups")
        let targetSkills = root.url.appendingPathComponent("target/skills")
        try makeSkill(named: "writer", in: targetSkills, files: ["SKILL.md": "old"])

        let store = BackupStore(rootURL: backupRoot, fileManager: .default)
        let snapshot = try store.backupSkill(named: "writer", from: targetSkills.appendingPathComponent("writer"))

        try "new".write(to: targetSkills.appendingPathComponent("writer/SKILL.md"), atomically: true, encoding: .utf8)
        try store.restore(snapshot: snapshot, to: targetSkills.appendingPathComponent("writer"))

        let restored = try String(contentsOf: targetSkills.appendingPathComponent("writer/SKILL.md"), encoding: .utf8)
        XCTAssertEqual(restored, "old")
        XCTAssertEqual(snapshot.skillName, "writer")
    }

    func test_listsSnapshotsForHistoryLookup() throws {
        let root = try TemporaryDirectory()
        let backupRoot = root.url.appendingPathComponent("backups")
        let targetSkills = root.url.appendingPathComponent("target/skills")
        try makeSkill(named: "writer", in: targetSkills, files: ["SKILL.md": "old"])

        let store = BackupStore(rootURL: backupRoot, fileManager: .default)
        _ = try store.backupSkill(named: "writer", from: targetSkills.appendingPathComponent("writer"))

        let snapshots = try store.listSnapshots()

        XCTAssertEqual(snapshots.map(\.skillName), ["writer"])
        XCTAssertTrue(snapshots.first?.snapshotURL.path.contains("writer") == true)
    }
}
