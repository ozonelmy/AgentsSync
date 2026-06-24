import XCTest
@testable import AgentsSyncCore

final class SyncPlannerTests: XCTestCase {
    func test_missingDiffCreatesCopyOperation() {
        let plan = SyncPlanner().makePlan(from: [
            .missing(skillName: "writer", sourceDirectoryID: "codex", targetDirectoryIDs: ["claude"])
        ])

        XCTAssertEqual(plan.operations, [
            .copySkill(skillName: "writer", sourceDirectoryID: "codex", targetDirectoryID: "claude")
        ])
        XCTAssertTrue(plan.conflicts.isEmpty)
    }

    func test_conflictDiffRequiresUserDecision() {
        let plan = SyncPlanner().makePlan(from: [
            .conflict(skillName: "writer", sourceDirectoryIDs: ["codex", "claude"])
        ])

        XCTAssertTrue(plan.operations.isEmpty)
        XCTAssertEqual(plan.conflicts, [
            SkillConflict(skillName: "writer", sourceDirectoryIDs: ["codex", "claude"])
        ])
    }

    func test_userToProjectWriteRequiresExplicitConfirmation() {
        let plan = SyncPlanner().makePlan(from: [
            .confirmationRequired(
                skillName: "writer",
                sourceDirectoryID: "user",
                targetDirectoryID: "project",
                reason: .userToProject
            )
        ])

        XCTAssertTrue(plan.operations.isEmpty)
        XCTAssertEqual(plan.confirmations, [
            ConfirmationRequiredOperation(
                skillName: "writer",
                sourceDirectoryID: "user",
                targetDirectoryID: "project",
                reason: .userToProject
            )
        ])
    }

    func test_scopeOverrideDoesNotCreateWriteOperationOrConflict() {
        let plan = SyncPlanner().makePlan(from: [
            .scopeOverride(skillName: "writer", effectiveDirectoryID: "project", overriddenDirectoryIDs: ["user"])
        ])

        XCTAssertTrue(plan.operations.isEmpty)
        XCTAssertTrue(plan.conflicts.isEmpty)
        XCTAssertTrue(plan.confirmations.isEmpty)
    }
}
