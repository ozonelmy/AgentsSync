import XCTest
@testable import AgentsSyncCore

final class SyncCoordinatorTests: XCTestCase {
    func test_gitPullFailureStopsDependentWriteOperations() throws {
        let executor = RecordingSyncExecutor()
        let coordinator = SyncCoordinator(
            executor: executor,
            gitRepository: FailingPullRepository(),
            clock: { Date(timeIntervalSince1970: 1) },
            idGenerator: { UUID(uuidString: "00000000-0000-0000-0000-000000000002")! }
        )

        let result = coordinator.execute(
            plan: SyncPlan(operations: [.copySkill(skillName: "writer", sourceDirectoryID: "codex", targetDirectoryID: "claude")]),
            directoriesByID: [:],
            commitMessage: "Sync skills"
        )

        XCTAssertFalse(executor.didExecute)
        XCTAssertEqual(result.status, .failed)
        XCTAssertTrue(result.message.contains("pull failed"))
    }

    func test_successfulGitFlowRunsPullWriteCommitPushAndReturnsHistory() throws {
        let executor = RecordingSyncExecutor(result: SyncExecutionResult(backups: [
            BackupSnapshot(skillName: "writer", snapshotURL: URL(fileURLWithPath: "/backup/writer"))
        ]))
        let git = RecordingGitRepository()
        let coordinator = SyncCoordinator(
            executor: executor,
            gitRepository: git,
            clock: { Date(timeIntervalSince1970: 2) },
            idGenerator: { UUID(uuidString: "00000000-0000-0000-0000-000000000003")! }
        )
        let operation = SyncOperation.copySkill(skillName: "writer", sourceDirectoryID: "codex", targetDirectoryID: "claude")

        let result = coordinator.execute(
            plan: SyncPlan(operations: [operation]),
            directoriesByID: ["codex": ToolDirectory(id: "codex", name: "Codex", skillsURL: URL(fileURLWithPath: "/codex"), kind: .codex, isEnabled: true)],
            commitMessage: "Sync skills"
        )

        XCTAssertEqual(git.calls, ["pull", "commit:Sync skills", "push"])
        XCTAssertTrue(executor.didExecute)
        XCTAssertEqual(result, SyncHistoryEntry(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
            date: Date(timeIntervalSince1970: 2),
            status: .succeeded,
            message: "同步完成",
            operations: [operation],
            backups: [BackupSnapshot(skillName: "writer", snapshotURL: URL(fileURLWithPath: "/backup/writer"))]
        ))
    }
}

private final class RecordingSyncExecutor: SkillSyncExecuting {
    private let result: SyncExecutionResult
    private(set) var didExecute = false

    init(result: SyncExecutionResult = SyncExecutionResult()) {
        self.result = result
    }

    func execute(operations: [SyncOperation], directoriesByID: [String: ToolDirectory]) throws -> SyncExecutionResult {
        didExecute = true
        return result
    }
}

private struct FailingPullRepository: GitWorkingCopy {
    func status() throws -> String { "" }
    func pull() throws -> String { throw SyncError.gitFailed("pull failed") }
    func commit(message: String) throws -> String { "" }
    func push() throws -> String { "" }
}

private final class RecordingGitRepository: GitWorkingCopy {
    private(set) var calls: [String] = []

    func status() throws -> String { "" }

    func pull() throws -> String {
        calls.append("pull")
        return ""
    }

    func commit(message: String) throws -> String {
        calls.append("commit:\(message)")
        return ""
    }

    func push() throws -> String {
        calls.append("push")
        return ""
    }
}
