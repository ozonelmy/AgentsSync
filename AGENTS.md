# Repository Guidelines

## Project Structure & Module Organization

AgentsSync is a Swift Package Manager project for synchronizing skills across coding-agent tool directories. Core implementation lives in `Sources/AgentsSyncCore/`, with small, focused files such as `SkillScanner.swift`, `DiffEngine.swift`, `SyncPlanner.swift`, and `SyncExecutor.swift`. Unit tests mirror the core modules under `Tests/AgentsSyncCoreTests/`. App-facing or integration-level tests live in `Tests/AgentsSyncTests/`. Project notes and product behavior belong in `docs/`, currently `docs/spec.md`.

## Build, Test, and Development Commands

- `swift build`: compile the `AgentsSyncCore` library.
- `swift test`: run all XCTest targets.
- `swift test --filter SyncPlannerTests`: run one test class while iterating.
- `swift package describe`: inspect products, targets, and platform settings.

Run commands from the repository root. The package currently targets macOS 14 and Swift tools version 6.0.

## Coding Style & Naming Conventions

Use standard Swift API Design Guidelines: `UpperCamelCase` for types, `lowerCamelCase` for methods and properties, and descriptive enum cases. Keep domain logic in `AgentsSyncCore`; avoid mixing UI or CLI behavior into core types unless the package structure changes. Use four-space indentation and keep functions short enough that the tested behavior remains obvious. Existing comments may be bilingual; add comments only when they clarify non-obvious sync behavior or safety constraints.

## Testing Guidelines

Tests use XCTest. Name test files after the type or behavior under test, for example `SkillScannerTests.swift` or `SyncExecutorTests.swift`. Name test methods with the `test_condition_expectedBehavior` pattern already used in the suite, such as `test_missingDiffCreatesCopyOperation`. Add focused tests for any new sync rule, filesystem operation, conflict case, or backup behavior before changing implementation details.

## Commit & Pull Request Guidelines

Git history currently uses concise Conventional Commit-style messages, for example `feat: 新增 skill 目录规范与测试用例`. Continue using prefixes such as `feat:`, `fix:`, `test:`, or `docs:` with a short imperative summary.

Pull requests should include a brief description of the behavior change, the tests run (`swift test` output summary is enough), and links to related issues or specs. Include screenshots only for future UI changes; core-only changes should focus on test coverage and edge cases.

## Security & Configuration Tips

Sync code may read and write user and project tool directories. Prefer explicit paths in tests, use temporary directories for filesystem coverage, and preserve backup behavior when modifying write operations.
