import Foundation

// 中文注释：BackupStore 在覆盖前保存目录级 skill 快照，并支持恢复。
public struct BackupStore {
    private let rootURL: URL
    private let fileManager: FileManager

    public init(rootURL: URL, fileManager: FileManager) {
        self.rootURL = rootURL
        self.fileManager = fileManager
    }

    public func backupSkill(named skillName: String, from skillURL: URL) throws -> BackupSnapshot {
        guard fileManager.fileExists(atPath: skillURL.path) else {
            throw SyncError.skillNotFound(skillName)
        }
        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        let snapshotContainerURL = rootURL.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: snapshotContainerURL, withIntermediateDirectories: true)
        let snapshotURL = snapshotContainerURL.appendingPathComponent(skillName, isDirectory: true)
        try fileManager.copyItem(at: skillURL, to: snapshotURL)
        return BackupSnapshot(skillName: skillName, snapshotURL: snapshotURL)
    }

    public func restore(snapshot: BackupSnapshot, to targetURL: URL) throws {
        if fileManager.fileExists(atPath: targetURL.path) {
            try fileManager.removeItem(at: targetURL)
        }
        try fileManager.copyItem(at: snapshot.snapshotURL, to: targetURL)
    }

    public func listSnapshots() throws -> [BackupSnapshot] {
        guard fileManager.fileExists(atPath: rootURL.path) else { return [] }
        let containers = try fileManager.contentsOfDirectory(at: rootURL, includingPropertiesForKeys: [.isDirectoryKey])
        var snapshots: [BackupSnapshot] = []
        for container in containers {
            let containerValues = try container.resourceValues(forKeys: [.isDirectoryKey])
            guard containerValues.isDirectory == true else { continue }
            let skillDirectories = try fileManager.contentsOfDirectory(at: container, includingPropertiesForKeys: [.isDirectoryKey])
            for skillURL in skillDirectories {
                let skillValues = try skillURL.resourceValues(forKeys: [.isDirectoryKey])
                guard skillValues.isDirectory == true else { continue }
                // 中文注释：快照目录使用 skill 名称作为最后一级路径，历史记录可直接读取。
                snapshots.append(BackupSnapshot(skillName: skillURL.lastPathComponent, snapshotURL: skillURL))
            }
        }
        return snapshots.sorted { $0.snapshotURL.path < $1.snapshotURL.path }
    }
}
