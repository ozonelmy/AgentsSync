// swift-tools-version: 6.0

import PackageDescription

// 中文注释：当前包先承载 v1 Core 与测试，后续 SwiftUI App 可继续引用 AgentsSyncCore。
let package = Package(
    name: "AgentsSync",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "AgentsSyncCore", targets: ["AgentsSyncCore"])
    ],
    targets: [
        .target(name: "AgentsSyncCore"),
        .testTarget(name: "AgentsSyncCoreTests", dependencies: ["AgentsSyncCore"]),
        .testTarget(name: "AgentsSyncTests", dependencies: ["AgentsSyncCore"])
    ]
)
