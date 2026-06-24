import XCTest
@testable import AgentsSyncCore

final class GitRepositoryTests: XCTestCase {
    func test_statusReturnsGitOutput() throws {
        let root = try TemporaryDirectory()
        try GitRepository.runRawGit(["init"], in: root.url)
        try "content".write(to: root.url.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)

        let repository = GitRepository(repositoryURL: root.url)
        let status = try repository.status()

        XCTAssertTrue(status.contains("README.md"))
    }

    func test_gitFailureThrowsAndBlocksDependentFlow() throws {
        let root = try TemporaryDirectory()
        let repository = GitRepository(repositoryURL: root.url)

        XCTAssertThrowsError(try repository.status())
    }
}
