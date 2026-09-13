// SPDX-License-Identifier: GPL-3.0-or-later
import XCTest
@testable import BtoFolderLoopCore

final class MockFileSystem: FolderFileSystem {
    var entries: [String: FileEntry] = [:]
    var childPaths: [String: Set<String>] = [:]
    var denied: Set<String> = []
    var failTrash = false
    var moved: [String] = []
    var serial: UInt64 = 1
    init() { add("/fixture") }
    func add(_ path: String, kind: EntryKind = .directory) {
        entries[path] = FileEntry(path: path, identity: .init(device: 1, inode: serial), kind: kind); serial += 1
        childPaths[URL(fileURLWithPath: path).deletingLastPathComponent().path, default: []].insert(path)
    }
    func inspect(_ path: String) throws -> FileEntry {
        guard let entry = entries[path] else { throw CleanupError.filesystem("Missing entry") }
        return entry
    }
    func children(_ path: String) throws -> [FileEntry] {
        if denied.contains(path) { throw CleanupError.filesystem("Permission denied") }
        return (childPaths[path] ?? []).compactMap { entries[$0] }
    }
    func trashEmpty(_ candidate: Candidate, ancestors: [DirectoryIdentity]) throws -> TrashOutcome {
        if failTrash { throw CleanupError.filesystem("Native Trash failed") }
        for item in ancestors + [.init(path: candidate.path, identity: candidate.identity)] {
            let now = try inspect(item.path)
            guard now.kind == .directory && now.identity == item.identity else { throw CleanupError.changed(item.path) }
        }
        if try !children(candidate.path).isEmpty { return .skipped("Now occupied") }
        entries.removeValue(forKey: candidate.path); moved.append(candidate.path)
        return .moved(.init(source: candidate.path, destination: "/trash/\(candidate.identity.inode)", identity: candidate.identity))
    }
}

final class MockJournal: OperationJournal {
    var failBegin = false, failPrepared = false, failMoved = false
    var events: [String] = []
    var finished: CleanupReport?
    var seen: Set<UUID> = []
    func begin(_ plan: CleanupPlan) throws {
        if failBegin || seen.contains(plan.id) { throw CleanupError.filesystem("Journal unavailable or plan already used") }
        seen.insert(plan.id)
    }
    func record(run: UUID, path: String, phase: String, destination: String?, detail: String?) throws {
        if failPrepared && phase == "prepared" || failMoved && phase == "moved" { throw CleanupError.filesystem("Journal write failed") }
        events.append(phase)
    }
    func finish(_ report: CleanupReport) throws { finished = report }
}

final class CoreTests: XCTestCase {
    func chain() -> MockFileSystem {
        let fs = MockFileSystem()
        for p in ["/fixture/A", "/fixture/A/B", "/fixture/A/B/C"] { fs.add(p) }
        return fs
    }
    func plan(_ fs: MockFileSystem, _ mode: CleanupMode = .cascade) throws -> CleanupPlan {
        try CleanupPlanner(fileSystem: fs).analyze(root: "/fixture", mode: mode)
    }
    func testSinglePassOnlyInitialLeaves() throws {
        let fs = chain(), p = try plan(fs, .singlePass)
        XCTAssertEqual(p.candidates.map(\.relativePath), ["A/B/C"])
        let r = try CleanupExecutor(fileSystem: fs, journal: MockJournal()).execute(p)
        XCTAssertEqual(r.moved.count, 1)
        XCTAssertNotNil(fs.entries["/fixture/A/B"])
        XCTAssertNotNil(fs.entries["/fixture/A"])
    }
    func testCascadePredictsParentsAndExecutesBottomUp() throws {
        let fs = chain(), p = try plan(fs)
        XCTAssertEqual(p.candidates.map(\.relativePath), ["A/B/C", "A/B", "A"])
        XCTAssertEqual(p.candidates.map(\.pass), [1, 2, 3])
        let r = try CleanupExecutor(fileSystem: fs, journal: MockJournal()).execute(p)
        XCTAssertEqual(r.moved.count, 3)
        XCTAssertEqual(fs.moved, p.candidates.map(\.path))
        XCTAssertNotNil(fs.entries["/fixture"])
        XCTAssertTrue(try plan(fs).candidates.isEmpty)
    }
    func testFilesHiddenLinksPackagesAndErrorsBlockParents() throws {
        let fs = MockFileSystem()
        for d in ["files", "hidden", "links", "packages", "denied"] { fs.add("/fixture/" + d) }
        fs.add("/fixture/files/photo.jpg", kind: .file)
        fs.add("/fixture/hidden/.DS_Store", kind: .file)
        fs.add("/fixture/links/link", kind: .symbolicLink)
        fs.add("/fixture/packages/Example.app", kind: .protected)
        fs.denied.insert("/fixture/denied")
        let p = try plan(fs)
        XCTAssertTrue(p.candidates.isEmpty)
        XCTAssertEqual(p.issues.count, 1)
    }
    func testEmptyRootIsNeverCandidate() throws {
        XCTAssertTrue(try plan(MockFileSystem()).candidates.isEmpty)
    }
    func testSymbolicRootRejected() {
        let fs = MockFileSystem(); fs.add("/fixture", kind: .symbolicLink)
        XCTAssertThrowsError(try plan(fs))
    }
    func testNewFileAfterPreviewProtectsWholeChain() throws {
        let fs = chain(), p = try plan(fs)
        fs.add("/fixture/A/B/C/new.txt", kind: .file)
        let r = try CleanupExecutor(fileSystem: fs, journal: MockJournal()).execute(p)
        XCTAssertTrue(r.moved.isEmpty); XCTAssertEqual(r.skipped.count, 3)
        XCTAssertNotNil(fs.entries["/fixture/A/B/C/new.txt"])
    }
    func testNewlyCreatedEmptyFolderIsOutsideApproval() throws {
        let fs = chain(), p = try plan(fs)
        fs.add("/fixture/new")
        _ = try CleanupExecutor(fileSystem: fs, journal: MockJournal()).execute(p)
        XCTAssertNotNil(fs.entries["/fixture/new"])
    }
    func testChangedInodeStopsBeforeAnyMove() throws {
        let fs = chain(), p = try plan(fs)
        fs.add("/fixture/A/B/C")
        let r = try CleanupExecutor(fileSystem: fs, journal: MockJournal()).execute(p)
        XCTAssertTrue(r.moved.isEmpty); XCTAssertEqual(r.errors.count, 1)
    }
    func testChangedAncestorStopsBeforeAnyMove() throws {
        let fs = chain(), p = try plan(fs)
        fs.add("/fixture/A", kind: .symbolicLink)
        let r = try CleanupExecutor(fileSystem: fs, journal: MockJournal()).execute(p)
        XCTAssertTrue(r.moved.isEmpty); XCTAssertEqual(r.errors.count, 1)
    }
    func testRootIdentityChangeRejected() throws {
        let fs = chain(), p = try plan(fs); fs.add("/fixture")
        XCTAssertThrowsError(try CleanupExecutor(fileSystem: fs, journal: MockJournal()).execute(p))
        XCTAssertTrue(fs.moved.isEmpty)
    }
    func testJournalMustBeginBeforeAnyMove() throws {
        let fs = chain(), p = try plan(fs), journal = MockJournal(); journal.failBegin = true
        XCTAssertThrowsError(try CleanupExecutor(fileSystem: fs, journal: journal).execute(p))
        XCTAssertTrue(fs.moved.isEmpty)
    }
    func testPreparedJournalFailureStopsMovement() throws {
        let fs = chain(), p = try plan(fs), journal = MockJournal(); journal.failPrepared = true
        let r = try CleanupExecutor(fileSystem: fs, journal: journal).execute(p)
        XCTAssertTrue(fs.moved.isEmpty); XCTAssertEqual(r.errors.count, 1)
    }
    func testPostMoveJournalFailureKeepsReceiptAndStops() throws {
        let fs = chain(), p = try plan(fs), journal = MockJournal(); journal.failMoved = true
        let r = try CleanupExecutor(fileSystem: fs, journal: journal).execute(p)
        XCTAssertEqual(r.moved.count, 1); XCTAssertEqual(r.errors.count, 1)
        XCTAssertFalse(r.moved[0].destination.isEmpty)
    }
    func testTrashFailureHasNoDeleteFallback() throws {
        let fs = chain(), p = try plan(fs); fs.failTrash = true
        let r = try CleanupExecutor(fileSystem: fs, journal: MockJournal()).execute(p)
        XCTAssertEqual(r.errors.count, 1); XCTAssertEqual(fs.entries.count, 4)
    }
    func testCancellationStopsBetweenMoves() throws {
        let fs = chain(), p = try plan(fs), token = CancellationToken()
        let r = try CleanupExecutor(fileSystem: fs, journal: MockJournal()).execute(p, cancellation: token) { _,_ in token.cancel() }
        XCTAssertEqual(r.moved.count, 1); XCTAssertTrue(r.cancelled)
        XCTAssertNotNil(fs.entries["/fixture/A/B"])
    }
    func testCancelledScanReturnsNoPlan() throws {
        let token = CancellationToken(); token.cancel()
        XCTAssertThrowsError(try CleanupPlanner(fileSystem: chain()).analyze(root: "/fixture", mode: .cascade, cancellation: token))
    }
    func testPlanCannotBeReusedWithSameJournal() throws {
        let fs = chain(), p = try plan(fs), journal = MockJournal()
        _ = try CleanupExecutor(fileSystem: fs, journal: journal).execute(p)
        XCTAssertThrowsError(try CleanupExecutor(fileSystem: fs, journal: journal).execute(p))
    }
    func testWideTreeTenThousandLeaves() throws {
        // Measure planning without generating or deleting user filesystem entries.
        let fs = MockFileSystem()
        for i in 0..<10_000 { fs.add("/fixture/empty-\(i)") }
        let start = Date(), p = try plan(fs)
        XCTAssertEqual(p.candidates.count, 10_000)
        print("BENCHMARK_10000_DIRECTORIES_SECONDS=\(Date().timeIntervalSince(start))")
    }
}
