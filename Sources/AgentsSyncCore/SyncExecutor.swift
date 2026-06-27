import Foundation

public protocol SkillSyncExecuting {
    func execute(operations: [SyncOperation], directoriesByID: [String: ToolDirectory]) throws -> SyncExecutionResult
}

// 中文注释：SyncExecutor 执行目录级复制，并在覆盖前调用 BackupStore。
public struct SyncExecutor: SkillSyncExecuting {
    private let fileManager: FileManager
    private let backupStore: BackupStore

    public init(fileManager: FileManager, backupStore: BackupStore) {
        self.fileManager = fileManager
        self.backupStore = backupStore
    }

    @discardableResult
    public func execute(operations: [SyncOperation], directoriesByID: [String: ToolDirectory]) throws -> SyncExecutionResult {
        var backups: [BackupSnapshot] = []
        for operation in operations {
            switch operation {
            case .copySkill(let skillName, let sourceDirectoryID, let targetDirectoryID):
                guard let sourceDirectory = directoriesByID[sourceDirectoryID] else {
                    throw SyncError.directoryNotFound(sourceDirectoryID)
                }
                guard let targetDirectory = directoriesByID[targetDirectoryID] else {
                    throw SyncError.directoryNotFound(targetDirectoryID)
                }

                let sourceSkillURL = sourceDirectory.skillsURL.appendingPathComponent(skillName, isDirectory: true)
                let targetSkillURL = targetDirectory.skillsURL.appendingPathComponent(skillName, isDirectory: true)
                guard fileManager.fileExists(atPath: sourceSkillURL.path) else {
                    throw SyncError.skillNotFound(skillName)
                }

                try fileManager.createDirectory(at: targetDirectory.skillsURL, withIntermediateDirectories: true)
                if fileManager.fileExists(atPath: targetSkillURL.path) {
                    let backup = try backupStore.backupSkill(named: skillName, from: targetSkillURL)
                    backups.append(backup)
                    try fileManager.removeItem(at: targetSkillURL)
                }
                try fileManager.copyItem(at: sourceSkillURL, to: targetSkillURL)
            }
        }
        return SyncExecutionResult(backups: backups)
    }
}
