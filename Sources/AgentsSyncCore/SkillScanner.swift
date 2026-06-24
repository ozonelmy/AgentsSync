import Foundation

// 中文注释：SkillScanning 协议让 ViewModel 测试可以注入固定扫描结果。
public protocol SkillScanning {
    func scan(directory: ToolDirectory) throws -> ScanResult
}

// 中文注释：SkillScanner 按目录级 skill 规则扫描 skills 下的一级子目录。
public struct SkillScanner: SkillScanning {
    private let fileManager: FileManager

    public init(fileManager: FileManager) {
        self.fileManager = fileManager
    }

    public func scan(directory: ToolDirectory) throws -> ScanResult {
        guard fileManager.fileExists(atPath: directory.skillsURL.path) else {
            return ScanResult(directory: directory, skills: [])
        }

        let children = try fileManager.contentsOfDirectory(
            at: directory.skillsURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        let skills = try children.compactMap { child -> SkillSnapshot? in
            let values = try child.resourceValues(forKeys: [.isDirectoryKey])
            guard values.isDirectory == true else { return nil }
            let name = child.lastPathComponent
            return SkillSnapshot(name: name, relativePath: name, fingerprint: try fingerprint(for: child))
        }
        .sorted { $0.name < $1.name }

        return ScanResult(directory: directory, skills: skills)
    }

    private func fingerprint(for skillURL: URL) throws -> String {
        let files = try fileManager.subpathsOfDirectory(atPath: skillURL.path)
            .map { URL(fileURLWithPath: $0) }
            .filter { !$0.lastPathComponent.hasPrefix(".") }
            .sorted { $0.path < $1.path }

        var parts: [String] = []
        for relativeURL in files {
            let absoluteURL = skillURL.appendingPathComponent(relativeURL.path)
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: absoluteURL.path, isDirectory: &isDirectory), !isDirectory.boolValue else {
                continue
            }
            let data = try Data(contentsOf: absoluteURL)
            parts.append("\(relativeURL.path):\(data.base64EncodedString())")
        }
        return parts.joined(separator: "\n")
    }
}
