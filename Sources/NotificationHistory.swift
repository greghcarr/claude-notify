import Foundation

final class NotificationHistory {
    private(set) var entries: [StoredNotification] = []
    var onChange: (() -> Void)?

    var isEmpty: Bool { entries.isEmpty }
    var count: Int { entries.count }

    func prefix(_ count: Int) -> ArraySlice<StoredNotification> {
        entries.prefix(count)
    }

    func find(id: String) -> StoredNotification? {
        entries.first(where: { $0.id == id })
    }

    func add(_ notification: StoredNotification) {
        entries.insert(notification, at: 0)
        onChange?()
    }

    func remove(id: String) {
        entries.removeAll { $0.id == id }
        onChange?()
    }

    func clear() {
        entries.removeAll()
        onChange?()
    }
}
