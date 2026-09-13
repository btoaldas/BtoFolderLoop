// SPDX-License-Identifier: GPL-3.0-or-later
import XCTest
@testable import BtoFolderLoopCore

final class SelectionTests: XCTestCase {
    private func tree() -> MockFileSystem {
        let fs = MockFileSystem()
        for p in ["/fixture/A", "/fixture/A/B", "/fixture/A/B/C", "/fixture/Other"] { fs.add(p) }
        return fs
    }
    private func scan(_ fs: MockFileSystem, mode: CleanupMode = .cascade) throws -> CleanupPlan {
        try CleanupPlanner(fileSystem: fs).analyze(root: "/fixture", mode: mode)
    }

    func testEveryNewScanStartsEmptyAndCannotApproveNothing() throws {
        let fs = tree(), first = try scan(fs)
        var selection = CandidateSelection(plan: first)
        XCTAssertTrue(selection.selectedIDs.isEmpty)
        XCTAssertThrowsError(try selection.approvedPlan(from: first))
        selection.selectAll()
        let next = try scan(fs)
        XCTAssertThrowsError(try selection.approvedPlan(from: next))
        XCTAssertTrue(CandidateSelection(plan: next).selectedIDs.isEmpty)
    }

    func testSelectAllNoneAndIndividualDoNotExpandDependencies() throws {
        let plan = try scan(tree())
        var selection = CandidateSelection(plan: plan)
        selection.setSelected("/fixture/A", true)
        XCTAssertEqual(selection.selectedIDs, ["/fixture/A"])
        selection.selectAll()
        XCTAssertEqual(selection.selectedIDs.count, 4)
        selection.setSelected("/fixture/A/B", false)
        XCTAssertFalse(selection.selectedIDs.contains("/fixture/A/B"))
        XCTAssertTrue(selection.selectedIDs.contains("/fixture/A"))
        selection.selectNone()
        XCTAssertTrue(selection.selectedIDs.isEmpty)
    }

    func testUnknownRootAndNewFolderCannotEnterSelection() throws {
        let fs = tree(), plan = try scan(fs)
        var selection = CandidateSelection(plan: plan)
        for id in ["/fixture", "/elsewhere", "/fixture/New"] { selection.setSelected(id, true) }
        fs.add("/fixture/New")
        selection.selectAll()
        let approved = try selection.approvedPlan(from: plan)
        XCTAssertFalse(approved.candidates.contains { $0.path == "/fixture/New" })
        XCTAssertEqual(approved.id, plan.id)
        XCTAssertEqual(approved.candidates.map(\.path), plan.candidates.map(\.path))
    }

    func testSelectedLeafMovesWithoutUnselectedParentsOrSibling() throws {
        let fs = tree(), plan = try scan(fs)
        var selection = CandidateSelection(plan: plan)
        selection.setSelected("/fixture/A/B/C", true)
        let result = try CleanupExecutor(fileSystem: fs, journal: MockJournal()).execute(selection.approvedPlan(from: plan))
        XCTAssertEqual(result.moved.map(\.source), ["/fixture/A/B/C"])
        XCTAssertNotNil(fs.entries["/fixture/A"])
        XCTAssertNotNil(fs.entries["/fixture/A/B"])
        XCTAssertNotNil(fs.entries["/fixture/Other"])
    }

    func testSelectedParentCannotMoveUnselectedChild() throws {
        let fs = tree(), plan = try scan(fs)
        var selection = CandidateSelection(plan: plan)
        selection.setSelected("/fixture/A", true)
        selection.setSelected("/fixture/A/B/C", true)
        let approved = try selection.approvedPlan(from: plan)
        XCTAssertEqual(approved.candidates.map(\.path), ["/fixture/A/B/C", "/fixture/A"])
        let result = try CleanupExecutor(fileSystem: fs, journal: MockJournal()).execute(approved)
        XCTAssertEqual(result.moved.count, 1)
        XCTAssertEqual(result.skipped.map(\.path), ["/fixture/A"])
        XCTAssertNotNil(fs.entries["/fixture/A/B"])
    }

    func testWholeSelectedChainMovesInOrderAndSiblingRemains() throws {
        let fs = tree(), plan = try scan(fs)
        var selection = CandidateSelection(plan: plan)
        selection.selectAll(); selection.setSelected("/fixture/Other", false)
        let approved = try selection.approvedPlan(from: plan)
        let result = try CleanupExecutor(fileSystem: fs, journal: MockJournal()).execute(approved)
        XCTAssertEqual(result.moved.map(\.source), ["/fixture/A/B/C", "/fixture/A/B", "/fixture/A"])
        XCTAssertNotNil(fs.entries["/fixture/Other"])
        XCTAssertEqual(approved.directories.count, plan.directories.count)
    }

    func testApprovalSnapshotDoesNotChangeWithLaterSelection() throws {
        let plan = try scan(tree())
        var selection = CandidateSelection(plan: plan)
        selection.setSelected("/fixture/Other", true)
        let snapshot = try selection.approvedPlan(from: plan)
        selection.selectAll()
        XCTAssertEqual(snapshot.candidates.map(\.path), ["/fixture/Other"])
    }

    func testSinglePassSelectionNeverAddsNewlyEmptyParents() throws {
        let fs = tree(), plan = try scan(fs, mode: .singlePass)
        var selection = CandidateSelection(plan: plan)
        selection.selectAll(); selection.setSelected("/fixture/Other", false)
        let report = try CleanupExecutor(fileSystem: fs, journal: MockJournal()).execute(selection.approvedPlan(from: plan))
        XCTAssertEqual(report.moved.map(\.source), ["/fixture/A/B/C"])
        XCTAssertNotNil(fs.entries["/fixture/A/B"])
    }

    func testNewFileStillBlocksAnIndividuallyApprovedFolder() throws {
        let fs = tree(), plan = try scan(fs)
        var selection = CandidateSelection(plan: plan)
        selection.setSelected("/fixture/Other", true)
        let approved = try selection.approvedPlan(from: plan)
        fs.add("/fixture/Other/new.txt", kind: .file)
        let report = try CleanupExecutor(fileSystem: fs, journal: MockJournal()).execute(approved)
        XCTAssertTrue(report.moved.isEmpty)
        XCTAssertEqual(report.skipped.count, 1)
        XCTAssertNotNil(fs.entries["/fixture/Other/new.txt"])
    }
}
