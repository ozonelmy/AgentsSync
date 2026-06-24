import Foundation

// 中文注释：SyncPlanner 将差异结果转换为可执行操作和待处理冲突。
public struct SyncPlanner {
    public init() {}

    public func makePlan(from diffs: [SkillDiff]) -> SyncPlan {
        var plan = SyncPlan()
        for diff in diffs {
            switch diff {
            case .missing(let skillName, let sourceDirectoryID, let targetDirectoryIDs):
                plan.operations.append(contentsOf: targetDirectoryIDs.map {
                    .copySkill(skillName: skillName, sourceDirectoryID: sourceDirectoryID, targetDirectoryID: $0)
                })
            case .conflict(let skillName, let sourceDirectoryIDs):
                plan.conflicts.append(SkillConflict(skillName: skillName, sourceDirectoryIDs: sourceDirectoryIDs))
            case .confirmationRequired(let skillName, let sourceDirectoryID, let targetDirectoryID, let reason):
                plan.confirmations.append(ConfirmationRequiredOperation(
                    skillName: skillName,
                    sourceDirectoryID: sourceDirectoryID,
                    targetDirectoryID: targetDirectoryID,
                    reason: reason
                ))
            case .scopeOverride:
                break
            case .noDifference:
                break
            }
        }
        return plan
    }
}
