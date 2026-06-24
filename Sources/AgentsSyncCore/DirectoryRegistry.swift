import Foundation

// 中文注释：DirectoryRegistry 负责生成内置目录预设，并过滤用户启用的目录。
public struct DirectoryRegistry {
    private let homeDirectory: URL

    public init(homeDirectory: URL) {
        self.homeDirectory = homeDirectory
    }

    public func defaultDirectories() -> [ToolDirectory] {
        [
            ToolDirectory(
                id: "codex",
                name: "Codex",
                skillsURL: homeDirectory.appendingPathComponent(".codex/skills", isDirectory: true),
                kind: .codex,
                isEnabled: true,
                scope: .user
            ),
            ToolDirectory(
                id: "claude",
                name: "Claude Code",
                skillsURL: homeDirectory.appendingPathComponent(".claude/skills", isDirectory: true),
                kind: .claude,
                isEnabled: true,
                scope: .user
            )
        ]
    }

    public func customDirectory(name: String, skillsURL: URL, scope: ToolDirectoryScope = .user) -> ToolDirectory {
        ToolDirectory(id: "custom-\(UUID().uuidString)", name: name, skillsURL: skillsURL, kind: .custom, isEnabled: true, scope: scope)
    }

    public static func activeDirectories(from directories: [ToolDirectory]) -> [ToolDirectory] {
        directories.filter(\.isEnabled)
    }
}
