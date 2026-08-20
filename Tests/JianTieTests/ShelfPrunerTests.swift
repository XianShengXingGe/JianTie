#if canImport(XCTest)
import XCTest
#endif
import Foundation
@testable import JianTieCore

private final class MockFileReachableChecker: FileReachableChecking, @unchecked Sendable {
    var reachableFilePaths: Set<String> = []

    func isReachable(file: ShelfFileReference) -> Bool {
        return reachableFilePaths.contains(file.url.path)
    }
}

final class ShelfPrunerTests: XCTestCase {
    private var checker: MockFileReachableChecker!
    private var pruner: ShelfPruner!

    override func setUpWithError() throws {
        try super.setUpWithError()
        checker = MockFileReachableChecker()
        pruner = ShelfPruner(checker: checker, interval: 1.0)
    }

    func test_prune_allFilesReachable_returnsAllStacks() {
        let url1 = URL(fileURLWithPath: "/path/to/a.txt")
        let url2 = URL(fileURLWithPath: "/path/to/b.txt")
        checker.reachableFilePaths = [url1.path, url2.path]

        let stack1 = ShelfStack(files: [ShelfFileReference(url: url1)])
        let stack2 = ShelfStack(files: [ShelfFileReference(url: url2)])

        let (valid, removed) = pruner.prune(stacks: [stack1, stack2])

        XCTAssertEqual(valid.count, 2)
        XCTAssertEqual(removed, 0)
    }

    func test_prune_oneStackUnreachable_removesOnlyUnreachableStack() {
        let url1 = URL(fileURLWithPath: "/path/to/live.txt")
        let url2 = URL(fileURLWithPath: "/path/to/deleted.txt")
        checker.reachableFilePaths = [url1.path]

        let stack1 = ShelfStack(files: [ShelfFileReference(url: url1)])
        let stack2 = ShelfStack(files: [ShelfFileReference(url: url2)])

        let (valid, removed) = pruner.prune(stacks: [stack1, stack2])

        XCTAssertEqual(valid.count, 1)
        XCTAssertEqual(valid.first?.id, stack1.id)
        XCTAssertEqual(removed, 1)
    }

    func test_prune_multiFileStack_withOneFileUnreachable_removesEntireStack() {
        let url1 = URL(fileURLWithPath: "/path/to/part1.txt")
        let url2 = URL(fileURLWithPath: "/path/to/part2_missing.txt")
        // Only part1 is reachable
        checker.reachableFilePaths = [url1.path]

        let multiFileStack = ShelfStack(files: [
            ShelfFileReference(url: url1),
            ShelfFileReference(url: url2)
        ])

        let (valid, removed) = pruner.prune(stacks: [multiFileStack])

        XCTAssertEqual(valid.count, 0)
        XCTAssertEqual(removed, 1)
    }
}
