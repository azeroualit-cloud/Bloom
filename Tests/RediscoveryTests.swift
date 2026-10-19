import XCTest
@testable import Bloom

final class RediscoveryTests: XCTestCase {
    private func candidate(_ number: Int, kind: ContentKind = .link, archived: Bool = false,
                           collection: UUID? = nil, host: String? = nil) -> RediscoveryCandidate {
        RediscoveryCandidate(id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", number))!,
                             kind: kind, collectionID: collection, host: host, isArchived: archived)
    }

    func testStableDailySelectionIgnoresInputOrder() {
        let items = (1...50).map { candidate($0) }
        let first = RediscoveryPlanner.select(items, day: 100)
        XCTAssertEqual(first, RediscoveryPlanner.select(Array(items.reversed()), day: 100))
        XCTAssertEqual(first.count, 30)
        XCTAssertEqual(Set(first).count, 30)
        XCTAssertNotEqual(first, RediscoveryPlanner.select(items, day: 101))
        XCTAssertNotEqual(first, RediscoveryPlanner.select(items, day: 100, round: 1))
    }

    func testRoundsExhaustLibraryWithoutRepeatsAndResetIsPossible() {
        let items = (1...65).map { candidate($0) }
        var history = Set<UUID>()
        for expected in [30, 30, 5] {
            let round = RediscoveryPlanner.select(items, day: 100, excluding: history)
            XCTAssertEqual(round.count, expected)
            XCTAssertTrue(history.isDisjoint(with: round))
            history.formUnion(round)
        }
        XCTAssertTrue(RediscoveryPlanner.select(items, day: 100, excluding: history).isEmpty)
        XCTAssertEqual(RediscoveryPlanner.select(items, day: 100).count, 30)
    }

    func testEmptyArchivedAndDuplicateInputs() {
        XCTAssertTrue(RediscoveryPlanner.select([], day: 100).isEmpty)
        XCTAssertTrue(RediscoveryPlanner.select([candidate(1, archived: true)], day: 100).isEmpty)
        let active = candidate(1)
        let selection = RediscoveryPlanner.select([active, candidate(2, archived: true), active], day: 100)
        XCTAssertEqual(selection, [active.id])
    }

    func testPrefersDifferentFormatsWhenAvailable() {
        let kinds: [ContentKind] = [.link, .text, .image, .file]
        let items = (1...40).map { candidate($0, kind: kinds[($0 - 1) % kinds.count]) }
        let lookup = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0.kind) })
        let selection = RediscoveryPlanner.select(items, day: 100)
        for index in 2..<12 {
            let kind = lookup[selection[index]]
            XCTAssertNotEqual(kind, lookup[selection[index - 1]])
            XCTAssertNotEqual(kind, lookup[selection[index - 2]])
        }
    }

    func testPrefersDifferentCollectionsAndSitesWithinOneFormat() {
        let groups = (1...3).map { candidate($0).id }
        let items = (1...30).map {
            candidate($0, collection: groups[($0 - 1) % 3], host: "site\(($0 - 1) % 3).example")
        }
        let lookup = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        let selection = RediscoveryPlanner.select(items, day: 100)
        for index in 1..<12 {
            XCTAssertNotEqual(lookup[selection[index]]?.collectionID, lookup[selection[index - 1]]?.collectionID)
            XCTAssertNotEqual(lookup[selection[index]]?.host, lookup[selection[index - 1]]?.host)
        }
    }

    func testSingleAndHomogeneousLibrariesRemainUsable() {
        let items = (1...4).map { candidate($0, kind: .file) }
        XCTAssertEqual(Set(RediscoveryPlanner.select(items, day: 100)), Set(items.map(\.id)))
        XCTAssertEqual(RediscoveryPlanner.select([items[0]], day: 100), [items[0].id])
    }
}
