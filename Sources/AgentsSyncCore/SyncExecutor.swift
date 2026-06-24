import Foundation

// 中文注释：SyncExecutor 执行目录级复制，并在覆盖前调用 BackupStore。
public struct SyncExecutor {
    private let fileManager: FileManager
    private let backupStore: BackupStore

    public init(fileManager: FileManager, backupStore: BackupStore) {
        self.fileManager = fileManager
        self.backupStore = backupStore
    }

    public func execute(operations: [SyncOperation], directoriesByID: [String: ToolDirectory]) throws {
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
                    _ = try backupStore.backupSkill(named: skillName, from: targetSkillURL)
                    try fileManager.removeItem(at: targetSkillURL)
                }
                try fileManager.copyItem(at: sourceSkillURL, to: targetSkillURL)
            }
        }
    }
}
