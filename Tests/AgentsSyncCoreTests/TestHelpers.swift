import Foundation

struct TemporaryDirectory {
    let url: URL

    init() throws {
        // 中文注释：每个测试使用独立临时目录，避免读写用户真实工具目录。
        url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }
}

func makeSkill(named name: String, in skillsDirectory: URL, files: [String: String]) throws {
    // 中文注释：按 spec 构造目录级 skill，包含 SKILL.md 与可选资源文件。
    let skillURL = skillsDirectory.appendingPathComponent(name, isDirectory: true)
    try FileManager.default.createDirectory(at: skillURL, withIntermediateDirectories: true)
    for (relativePath, content) in files {
        let fileURL = skillURL.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
    }
}
