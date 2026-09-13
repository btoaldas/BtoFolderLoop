// SPDX-License-Identifier: GPL-3.0-or-later
import XCTest
@testable import BtoFolderLoopCore

final class BatchTests: XCTestCase {
    func roots(_ fs: MockFileSystem, _ paths: [String]) throws -> [DirectoryIdentity] {
        try paths.map { DirectoryIdentity(path: $0, identity: try fs.inspect($0).identity) }
    }
    func twoTrees() -> MockFileSystem {
        let fs = MockFileSystem()
        for path in ["/fixture/A", "/fixture/A/empty", "/fixture/B", "/fixture/B/empty"] { fs.add(path) }
        fs.add("/fixture/A/photo.jpg", kind: .file); fs.add("/fixture/B/movie.mp4", kind: .file)
        return fs
    }
    func testSeveralRootsKeepFilesAndAllChosenRootsWithSeparateJournals() throws {
        let fs = twoTrees(), journal = MockJournal()
        let batch = try BatchPlanner(fileSystem: fs).analyze(roots: roots(fs, ["/fixture/A", "/fixture/B"]), mode: .cascade)
        XCTAssertEqual(batch.plans.count, 2); XCTAssertEqual(batch.candidates.count, 2)
        XCTAssertEqual(Set(batch.candidates.map(\.relativePath)), ["empty"])
        XCTAssertEqual(Set(batch.candidates.map(\.rootPath)).count, 2)
        var selection = BatchSelection(batch: batch); XCTAssertTrue(selection.selectedIDs.isEmpty)
        selection.selectAll()
        let report = try BatchExecutor(fileSystem: fs, journal: journal).execute(selection.approvedBatch(from: batch))
        XCTAssertEqual(report.moved.count, 2); XCTAssertEqual(journal.seen.count, 2)
        for path in ["/fixture/A", "/fixture/B", "/fixture/A/photo.jpg", "/fixture/B/movie.mp4"] { XCTAssertNotNil(fs.entries[path]) }
    }
    func testDuplicateAndNestedRootsAreScannedOnceAndNestedRootAndAncestorsPreserved() throws {
        let fs = MockFileSystem()
        for p in ["/fixture/A", "/fixture/A/B", "/fixture/A/B/C", "/fixture/A/B/C/empty"] { fs.add(p) }
        let batch = try BatchPlanner(fileSystem: fs).analyze(roots: roots(fs, ["/fixture/A/B/C", "/fixture/A", "/fixture/A"]), mode: .cascade)
        XCTAssertEqual(batch.plans.count, 1); XCTAssertEqual(batch.scannedDirectories, 4)
        XCTAssertEqual(batch.candidates.map(\.path), ["/fixture/A/B/C/empty"])
        let result = try BatchExecutor(fileSystem: fs, journal: MockJournal()).execute(batch)
        XCTAssertEqual(result.moved.count, 1)
        for p in ["/fixture/A", "/fixture/A/B", "/fixture/A/B/C"] { XCTAssertNotNil(fs.entries[p]) }
    }
    func testPartialSelectionDoesNotSelectOtherRootsAndOldSelectionCannotAuthorizeNewScan() throws {
        let fs = twoTrees(), planner = BatchPlanner(fileSystem: fs)
        let input = try roots(fs, ["/fixture/A", "/fixture/B"])
        let batch = try planner.analyze(roots: input, mode: .cascade)
        var selection = BatchSelection(batch: batch)
        selection.setSelected("/fixture/B/empty", true); selection.setSelected("/fixture/outside", true)
        let approved = try selection.approvedBatch(from: batch)
        XCTAssertEqual(approved.plans.count, 1)
        XCTAssertThrowsError(try selection.approvedBatch(from: planner.analyze(roots: input, mode: .cascade)))
        _ = try BatchExecutor(fileSystem: fs, journal: MockJournal()).execute(approved)
        XCTAssertNotNil(fs.entries["/fixture/A/empty"])
        XCTAssertNil(fs.entries["/fixture/B/empty"])
    }
    func testErrorStopsWholeBatchBeforeFollowingRoot() throws {
        let fs = twoTrees(), journal = MockJournal(); journal.failMoved = true
        let batch = try BatchPlanner(fileSystem: fs).analyze(roots: roots(fs, ["/fixture/A", "/fixture/B"]), mode: .cascade)
        let report = try BatchExecutor(fileSystem: fs, journal: journal).execute(batch)
        XCTAssertEqual(report.moved.count, 1); XCTAssertEqual(report.errors.count, 1)
        XCTAssertEqual(journal.seen.count, 1); XCTAssertNotNil(fs.entries["/fixture/B/empty"])
    }
    func testCancelBetweenRootsLeavesNextRootUntouched() throws {
        let fs = twoTrees(), journal = MockJournal(), cancellation = CancellationToken()
        let batch = try BatchPlanner(fileSystem: fs).analyze(roots: roots(fs, ["/fixture/A", "/fixture/B"]), mode: .singlePass)
        let report = try BatchExecutor(fileSystem: fs, journal: journal).execute(batch, cancellation: cancellation) { done, _, _ in
            if done == 1 { cancellation.cancel() }
        }
        XCTAssertTrue(report.cancelled); XCTAssertEqual(report.moved.count, 1)
        XCTAssertEqual(journal.seen.count, 1); XCTAssertNotNil(fs.entries["/fixture/B/empty"])
    }
    func testChangedNestedRootBlocksItsWholeTreeAndOtherRootRemainsReviewable() throws {
        let fs = twoTrees()
        let input = try roots(fs, ["/fixture/A", "/fixture/A/empty", "/fixture/B"])
        fs.add("/fixture/A/empty")
        let batch = try BatchPlanner(fileSystem: fs).analyze(roots: input, mode: .cascade)
        XCTAssertEqual(batch.issues.count, 1); XCTAssertEqual(batch.plans.map { $0.root.path }, ["/fixture/B"])
        XCTAssertNotNil(fs.entries["/fixture/A/empty"])
    }
    func testCancelledBatchScanReturnsNoPartialPlan() throws {
        let fs = twoTrees(), token = CancellationToken(); token.cancel()
        XCTAssertThrowsError(try BatchPlanner(fileSystem: fs).analyze(roots: roots(fs, ["/fixture/A", "/fixture/B"]), mode: .cascade, cancellation: token))
        XCTAssertTrue(fs.moved.isEmpty)
    }
}
