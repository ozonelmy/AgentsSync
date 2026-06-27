import Foundation

public enum AppStorageError: Error, Equatable, CustomStringConvertible {
    case decodeFailed(String)

    public var description: String {
        switch self {
        case .decodeFailed(let message):
            return "状态文件读取失败：\(message)"
        }
    }
}

public struct JSONAppStorage {
    private let fileURL: URL
    private let defaults: [ToolDirectory]
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(fileURL: URL, defaults: [ToolDirectory], fileManager: FileManager = .default) {
        self.fileURL = fileURL
        self.defaults = defaults
        self.fileManager = fileManager
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    public static func defaultFileURL(fileManager: FileManager = .default) throws -> URL {
        let applicationSupportURL = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return applicationSupportURL
            .appendingPathComponent("AgentsSync", isDirectory: true)
            .appendingPathComponent("state.json")
    }

    public func load() throws -> AgentsSyncStoredState {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return AgentsSyncStoredState(directories: defaults)
        }
        do {
            let data = try Data(contentsOf: fileURL)
            return try decoder.decode(AgentsSyncStoredState.self, from: data)
        } catch {
            throw AppStorageError.decodeFailed(error.localizedDescription)
        }
    }

    public func save(_ state: AgentsSyncStoredState) throws {
        try fileManager.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try encoder.encode(state)
        try data.write(to: fileURL, options: [.atomic])
    }
}
