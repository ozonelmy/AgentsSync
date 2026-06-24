import XCTest
@testable import AgentsSyncCore

final class SkillScannerTests: XCTestCase {
    func test_scansOnlyFirstLevelSkillDirectories() throws {
        let root = try TemporaryDirectory()
        let skills = root.url.appendingPathComponent("skills")
        try FileManager.default.createDirectory(at: skills, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: skills.appendingPathComponent("writer"), withIntermediateDirectories: true)
        try "writer skill".write(to: skills.appendingPathComponent("writer/SKILL.md"), atomically: true, encoding: .utf8)
        try "not a directory".write(to: skills.appendingPathComponent("loose.md"), atomically: true, encoding: .utf8)
        try FileManager.default.createDirectory(at: skills.appendingPathComponent("writer/references/nested"), withIntermediateDirectories: true)

        let scanner = SkillScanner(fileManager: .default)
        let result = try scanner.scan(directory: ToolDirectory(id: "codex", name: "Codex", skillsURL: skills, kind: .codex, isEnabled: true))

        XCTAssertEqual(result.skills.map(\.name), ["writer"])
        XCTAssertEqual(result.skills.first?.relativePath, "writer")
    }

    func test_computesSameFingerprintForEquivalentSkillDirectories() throws {
        let left = try TemporaryDirectory()
        let right = try TemporaryDirectory()
        try makeSkill(named: "writer", in: left.url.appendingPathComponent("skills"), files: [
            "SKILL.md": "content",
            "references/a.md": "A"
        ])
        try makeSkill(named: "writer", in: right.url.appendingPathComponent("skills"), files: [
            "references/a.md": "A",
            "SKILL.md": "content"
        ])

        let scanner = SkillScanner(fileManager: .default)
        let leftResult = try scanner.scan(directory: ToolDirectory(id: "left", name: "Left", skillsURL: left.url.appendingPathComponent("skills"), kind: .custom, isEnabled: true))
        let rightResult = try scanner.scan(directory: ToolDirectory(id: "right", name: "Right", skillsURL: right.url.appendingPathComponent("skills"), kind: .custom, isEnabled: true))

        XCTAssertEqual(leftResult.skills.first?.fingerprint, rightResult.skills.first?.fingerprint)
    }
}
