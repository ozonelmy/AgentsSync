import Foundation

public protocol SyncCoordinating {
    func execute(plan: SyncPlan, directoriesByID: [String: ToolDirectory], commitMessage: String) -> SyncHistoryEntry
}

public struct SyncCoordinator: SyncCoordinating {
    private let executor: SkillSyncExecuting
    private let gitRepository: GitWorkingCopy?
    private let clock: () -> Date
    private let idGenerator: () -> UUID

    public init(
        executor: SkillSyncExecuting,
        gitRepository: GitWorkingCopy? = nil,
        clock: @escaping () -> Date = Date.init,
        idGenerator: @escaping () -> UUID = UUID.init
    ) {
        self.executor = executor
        self.gitRepository = gitRepository
        self.clock = clock
        self.idGenerator = idGenerator
    }

    public func execute(plan: SyncPlan, directoriesByID: [String: ToolDirectory], commitMessage: String) -> SyncHistoryEntry {
        do {
            if let gitRepository {
                _ = try gitRepository.pull()
            }
            let result = try executor.execute(operations: plan.operations, directoriesByID: directoriesByID)
            if let gitRepository {
                _ = try gitRepository.commit(message: commitMessage)
                _ = try gitRepository.push()
            }
            return SyncHistoryEntry(
                id: idGenerator(),
                date: clock(),
                status: .succeeded,
                message: "同步完成",
                operations: plan.operations,
                backups: result.backups
            )
        } catch {
            return SyncHistoryEntry(
                id: idGenerator(),
                date: clock(),
                status: .failed,
                message: String(describing: error),
                operations: plan.operations,
                backups: []
            )
        }
    }
}
