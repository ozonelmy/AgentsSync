import Foundation

// 中文注释：DiffEngine 只做纯逻辑比较，不读写文件系统。
public struct DiffEngine {
    public init() {}

    public func diff(scanResults: [ScanResult]) -> [SkillDiff] {
        let allDirectoryIDs = scanResults.map { $0.directory.id }.sorted()
        let allSkillNames = Set(scanResults.flatMap { $0.skills.map(\.name) }).sorted()

        return allSkillNames.flatMap { skillName -> [SkillDiff] in
            let present = scanResults.compactMap { result -> (directory: ToolDirectory, snapshot: SkillSnapshot)? in
                guard let snapshot = result.skills.first(where: { $0.name == skillName }) else { return nil }
                return (result.directory, snapshot)
            }
            let presentIDs = present.map { $0.directory.id }.sorted()
            let missingIDs = allDirectoryIDs.filter { !presentIDs.contains($0) }
            let fingerprints = Set(present.map { $0.snapshot.fingerprint })
            let scopes = present.map { $0.directory.scope }

            if Set(scopes).count > 1 {
                guard let effective = present.max(by: { $0.directory.scope.priority < $1.directory.scope.priority }) else {
                    return []
                }
                let overridden = present
                    .map { $0.directory }
                    .filter { $0.id != effective.directory.id }
                    .map(\.id)
                    .sorted()
                return [.scopeOverride(skillName: skillName, effectiveDirectoryID: effective.directory.id, overriddenDirectoryIDs: overridden)]
            }

            if fingerprints.count == 1, missingIDs.isEmpty {
                return [.noDifference(skillName: skillName, directoryIDs: presentIDs)]
            }

            if fingerprints.count == 1, let sourceID = presentIDs.first, !missingIDs.isEmpty {
                guard let sourceDirectory = present.first(where: { $0.directory.id == sourceID })?.directory else {
                    return []
                }
                let writableMissingIDs = scanResults
                    .filter { missingIDs.contains($0.directory.id) }
                    .filter { $0.directory.scope != .global }
                    .filter { sourceDirectory.scope.isSameSyncGroup(as: $0.directory.scope) }
                    .map { $0.directory.id }
                    .sorted()

                var diffs: [SkillDiff] = []
                if !writableMissingIDs.isEmpty {
                    diffs.append(.missing(skillName: skillName, sourceDirectoryID: sourceID, targetDirectoryIDs: writableMissingIDs))
                }

                let confirmations = scanResults
                    .filter { missingIDs.contains($0.directory.id) }
                    .filter { $0.directory.scope != .global }
                    .compactMap { target -> SkillDiff? in
                        guard let reason = sourceDirectory.scope.confirmationReasonWhenWriting(to: target.directory.scope) else {
                            return nil
                        }
                        return .confirmationRequired(
                            skillName: skillName,
                            sourceDirectoryID: sourceID,
                            targetDirectoryID: target.directory.id,
                            reason: reason
                        )
                    }
                    .sorted { left, right in
                        String(describing: left) < String(describing: right)
                    }
                diffs.append(contentsOf: confirmations)
                return diffs
            }

            return [.conflict(skillName: skillName, sourceDirectoryIDs: presentIDs)]
        }
    }
}
