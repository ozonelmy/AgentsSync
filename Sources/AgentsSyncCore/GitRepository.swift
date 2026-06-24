import Foundation

// 中文注释：GitRepository 只封装本机 git 命令，不处理平台账号登录。
public struct GitRepository {
    private let repositoryURL: URL

    public init(repositoryURL: URL) {
        self.repositoryURL = repositoryURL
    }

    public func status() throws -> String {
        try Self.runRawGit(["status", "--short"], in: repositoryURL)
    }

    public func pull() throws -> String {
        try Self.runRawGit(["pull"], in: repositoryURL)
    }

    public func commit(message: String) throws -> String {
        try Self.runRawGit(["commit", "-m", message], in: repositoryURL)
    }

    public func push() throws -> String {
        try Self.runRawGit(["push"], in: repositoryURL)
    }

    @discardableResult
    public static func runRawGit(_ arguments: [String], in directory: URL) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["git"] + arguments
        process.currentDirectoryURL = directory

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let error = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        guard process.terminationStatus == 0 else {
            throw SyncError.gitFailed(error.isEmpty ? output : error)
        }
        return output
    }
}
