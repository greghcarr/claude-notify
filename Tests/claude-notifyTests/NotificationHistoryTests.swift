import XCTest
@testable import claude_notify

final class NotificationHistoryTests: XCTestCase {
    func testEmptyHistoryIsEmpty() {
        let history = NotificationHistory()
        XCTAssertTrue(history.isEmpty)
        XCTAssertEqual(history.count, 0)
    }

    func testAddInsertsAtFront() {
        let history = NotificationHistory()
        history.add(makeStored(id: "1"))
        history.add(makeStored(id: "2"))

        XCTAssertEqual(history.count, 2)
        XCTAssertEqual(history.entries[0].id, "2")
        XCTAssertEqual(history.entries[1].id, "1")
    }

    func testFindReturnsMatchingEntry() {
        let history = NotificationHistory()
        history.add(makeStored(id: "x", message: "hello"))

        XCTAssertEqual(history.find(id: "x")?.message, "hello")
        XCTAssertNil(history.find(id: "missing"))
    }

    func testRemoveOnlyAffectsMatchingId() {
        let history = NotificationHistory()
        history.add(makeStored(id: "a"))
        history.add(makeStored(id: "b"))
        history.add(makeStored(id: "c"))

        history.remove(id: "b")

        XCTAssertEqual(history.count, 2)
        XCTAssertNil(history.find(id: "b"))
        XCTAssertNotNil(history.find(id: "a"))
        XCTAssertNotNil(history.find(id: "c"))
    }

    func testRemoveMissingIdIsNoop() {
        let history = NotificationHistory()
        history.add(makeStored(id: "a"))

        history.remove(id: "nonexistent")

        XCTAssertEqual(history.count, 1)
    }

    func testClearEmptiesHistory() {
        let history = NotificationHistory()
        history.add(makeStored(id: "a"))
        history.add(makeStored(id: "b"))

        history.clear()

        XCTAssertTrue(history.isEmpty)
        XCTAssertEqual(history.count, 0)
    }

    func testPrefixReturnsTopN() {
        let history = NotificationHistory()
        for i in 1...10 {
            history.add(makeStored(id: "\(i)"))
        }

        let top3 = Array(history.prefix(3))
        XCTAssertEqual(top3.count, 3)
        XCTAssertEqual(top3.map(\.id), ["10", "9", "8"])
    }

    func testPrefixWhenFewerEntriesThanRequested() {
        let history = NotificationHistory()
        history.add(makeStored(id: "only"))

        let top5 = Array(history.prefix(5))
        XCTAssertEqual(top5.count, 1)
    }

    func testOnChangeFiresOnAdd() {
        let history = NotificationHistory()
        var callCount = 0
        history.onChange = { callCount += 1 }

        history.add(makeStored(id: "1"))
        XCTAssertEqual(callCount, 1)

        history.add(makeStored(id: "2"))
        XCTAssertEqual(callCount, 2)
    }

    func testOnChangeFiresOnRemove() {
        let history = NotificationHistory()
        history.add(makeStored(id: "1"))

        var callCount = 0
        history.onChange = { callCount += 1 }

        history.remove(id: "1")
        XCTAssertEqual(callCount, 1)
    }

    func testOnChangeFiresOnClear() {
        let history = NotificationHistory()
        history.add(makeStored(id: "1"))

        var callCount = 0
        history.onChange = { callCount += 1 }

        history.clear()
        XCTAssertEqual(callCount, 1)
    }

    private func makeStored(id: String = UUID().uuidString,
                            title: String = "Test",
                            message: String = "msg",
                            bundleId: String? = nil,
                            url: String? = nil) -> StoredNotification {
        StoredNotification(id: id, title: title, message: message, bundleId: bundleId, url: url)
    }
}
