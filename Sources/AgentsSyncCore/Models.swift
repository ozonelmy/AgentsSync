import Foundation

// 中文注释：ToolDirectory 描述一个参与同步的 skills 根目录，不直接绑定真实用户目录。
public struct ToolDirectory: Equatable, Hashable, Codable, Identifiable {
    public let id: String
    public let name: String
    public let skillsURL: URL
    public let kind: ToolDirectoryKind
    public let isEnabled: Bool
    public let scope: ToolDirectoryScope

    public init(id: String, name: String, skillsURL: URL, kind: ToolDirectoryKind, isEnabled: Bool, scope: ToolDirectoryScope = .user) {
        self.id = id
        self.name = name
        self.skillsURL = skillsURL
        self.kind = kind
        self.isEnabled = isEnabled
        self.scope = scope
    }
}

// 中文注释：目录类型用于区分内置预设、用户自定义目录和 Git 共享库。
public enum ToolDirectoryKind: Equatable, Hashable, Codable {
    case codex
    case claude
    case custom
    case gitShared
}

// 中文注释：作用域决定 skill 的同步边界、覆盖关系和写入风险。
public enum ToolDirectoryScope: Equatable, Hashable, Codable {
    case global
    case user
    case project(projectRoot: URL)

    var priority: Int {
        switch self {
        case .global:
            return 0
        case .user:
            return 1
        case .project:
            return 2
        }
    }

    func isSameSyncGroup(as other: ToolDirectoryScope) -> Bool {
        switch (self, other) {
        case (.global, .global), (.user, .user):
            return true
        case (.project(let left), .project(let right)):
            return left == right
        default:
            return false
        }
    }

    public func confirmationReasonWhenWriting(to target: ToolDirectoryScope) -> ConfirmationReason? {
        switch (self, target) {
        case (.user, .project):
            return .userToProject
        case (.project, .user):
            return .projectToUser
        case (.global, .user), (.global, .project):
            return .globalImport
        default:
            return nil
        }
    }
}

// 中文注释：SkillSnapshot 是扫描阶段得到的目录级 skill 摘要。
public struct SkillSnapshot: Equatable, Hashable, Codable {
    public let name: String
    public let relativePath: String
    public let fingerprint: String

    public init(name: String, relativePath: String, fingerprint: String) {
        self.name = name
        self.relativePath = relativePath
        self.fingerprint = fingerprint
    }
}

// 中文注释：ScanResult 保留某个工具目录的一次扫描结果。
public struct ScanResult: Equatable, Codable {
    public let directory: ToolDirectory
    public let skills: [SkillSnapshot]

    public init(directory: ToolDirectory, skills: [SkillSnapshot]) {
        self.directory = directory
        self.skills = skills
    }
}

// 中文注释：SkillDiff 表达从 spec 推导出的最小差异状态。
public enum SkillDiff: Equatable {
    case missing(skillName: String, sourceDirectoryID: String, targetDirectoryIDs: [String])
    case conflict(skillName: String, sourceDirectoryIDs: [String])
    case noDifference(skillName: String, directoryIDs: [String])
    case scopeOverride(skillName: String, effectiveDirectoryID: String, overriddenDirectoryIDs: [String])
    case confirmationRequired(skillName: String, sourceDirectoryID: String, targetDirectoryID: String, reason: ConfirmationReason)
}

// 中文注释：SyncOperation 是执行器当前支持的最小写入动作。
public enum SyncOperation: Equatable, Codable {
    case copySkill(skillName: String, sourceDirectoryID: String, targetDirectoryID: String)
}

// 中文注释：SkillConflict 让 UI 可以要求用户选择来源版本或跳过。
public struct SkillConflict: Equatable, Codable {
    public let skillName: String
    public let sourceDirectoryIDs: [String]

    public init(skillName: String, sourceDirectoryIDs: [String]) {
        self.skillName = skillName
        self.sourceDirectoryIDs = sourceDirectoryIDs
    }
}

// 中文注释：跨作用域写入必须进入确认队列，避免静默污染工程或用户目录。
public struct ConfirmationRequiredOperation: Equatable, Codable {
    public let skillName: String
    public let sourceDirectoryID: String
    public let targetDirectoryID: String
    public let reason: ConfirmationReason

    public init(skillName: String, sourceDirectoryID: String, targetDirectoryID: String, reason: ConfirmationReason) {
        self.skillName = skillName
        self.sourceDirectoryID = sourceDirectoryID
        self.targetDirectoryID = targetDirectoryID
        self.reason = reason
    }
}

// 中文注释：确认原因用于 UI 展示风险提示。
public enum ConfirmationReason: Equatable, Codable {
    case userToProject
    case projectToUser
    case globalImport
}

// 中文注释：SyncPlan 汇总可自动执行的操作和需要用户处理的冲突。
public struct SyncPlan: Equatable, Codable {
    public var operations: [SyncOperation]
    public var conflicts: [SkillConflict]
    public var confirmations: [ConfirmationRequiredOperation]

    public init(operations: [SyncOperation] = [], conflicts: [SkillConflict] = [], confirmations: [ConfirmationRequiredOperation] = []) {
        self.operations = operations
        self.conflicts = conflicts
        self.confirmations = confirmations
    }
}

// 中文注释：BackupSnapshot 指向覆盖写入前保存的本地快照。
public struct BackupSnapshot: Equatable, Hashable, Codable {
    public let skillName: String
    public let snapshotURL: URL

    public init(skillName: String, snapshotURL: URL) {
        self.skillName = skillName
        self.snapshotURL = snapshotURL
    }
}

// 中文注释：执行器返回本次写入过程中产生的备份，供历史记录与恢复入口展示。
public struct SyncExecutionResult: Equatable, Codable {
    public let backups: [BackupSnapshot]

    public init(backups: [BackupSnapshot] = []) {
        self.backups = backups
    }
}

public enum SyncHistoryStatus: Equatable, Codable {
    case succeeded
    case failed
}

// 中文注释：历史记录保存一次用户确认后的同步结果，不保存扫描中的临时状态。
public struct SyncHistoryEntry: Equatable, Codable {
    public let id: UUID
    public let date: Date
    public let status: SyncHistoryStatus
    public let message: String
    public let operations: [SyncOperation]
    public let backups: [BackupSnapshot]

    public init(id: UUID, date: Date, status: SyncHistoryStatus, message: String, operations: [SyncOperation], backups: [BackupSnapshot]) {
        self.id = id
        self.date = date
        self.status = status
        self.message = message
        self.operations = operations
        self.backups = backups
    }
}

public struct AgentsSyncStoredState: Equatable, Codable {
    public var directories: [ToolDirectory]
    public var gitSharedRepositoryURL: URL?
    public var history: [SyncHistoryEntry]

    public init(directories: [ToolDirectory], gitSharedRepositoryURL: URL? = nil, history: [SyncHistoryEntry] = []) {
        self.directories = directories
        self.gitSharedRepositoryURL = gitSharedRepositoryURL
        self.history = history
    }
}

// 中文注释：SyncError 统一表达测试覆盖到的同步失败原因。
public enum SyncError: Error, Equatable, CustomStringConvertible {
    case directoryNotFound(String)
    case skillNotFound(String)
    case gitFailed(String)

    public var description: String {
        switch self {
        case .directoryNotFound(let id):
            return "目录不存在：\(id)"
        case .skillNotFound(let name):
            return "Skill 不存在：\(name)"
        case .gitFailed(let message):
            return "Git 执行失败：\(message)"
        }
    }
}
