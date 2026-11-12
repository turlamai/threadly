import Foundation

/// One topic's locally-tracked reading position. Host-side only: the
/// forum's own read state needs an account, and the read loop has to
/// work signed out.
struct ReadPosition: Codable, Equatable {
    /// Deepest post the reader has reached (the unread math).
    var lastReadPostNumber: Int
    /// The post sitting at the viewport top when the reader last closed
    /// (what a reopen restores).
    var scrollAnchorPostNumber: Int
    var updatedAt: Date
}

/// Local read/unread state + scroll memory, persisted as one JSON
/// dictionary in UserDefaults. Reads move forward-only; the scroll
/// anchor moves freely. The dictionary prunes to the most recent topics
/// so years of use cannot bloat the defaults plist.
@MainActor
final class ReadStateStore {
    private let defaults: UserDefaults
    private let key: String
    private var positions: [Int: ReadPosition]
    private let capacity = 500

    /// Injectable defaults so tests run in an isolated suite.
    init(defaults: UserDefaults = .standard, key: String = "read-state-v1") {
        self.defaults = defaults
        self.key = key
        positions = Self.load(key: key, from: defaults)
    }

    func position(topic id: Int) -> ReadPosition? {
        positions[id]
    }

    /// Posts the topic has beyond the locally-read mark. Zero for
    /// never-opened topics — an all-new forum would badge every row into
    /// noise — and whenever nothing is new.
    func newPostCount(topic id: Int, postsCount: Int) -> Int {
        guard let p = positions[id], p.lastReadPostNumber > 0 else { return 0 }
        return max(0, postsCount - p.lastReadPostNumber)
    }

    /// Forward-only: a revisit that scrolls less never unreads a topic.
    func markRead(topic id: Int, upTo postNumber: Int) {
        guard postNumber > 0 else { return }
        if let p = positions[id], postNumber <= p.lastReadPostNumber {
            return
        }
        var p = positions[id] ?? ReadPosition(lastReadPostNumber: 0,
                                              scrollAnchorPostNumber: 0,
                                              updatedAt: Date())
        p.lastReadPostNumber = postNumber
        p.updatedAt = Date()
        positions[id] = p
        save()
    }

    func setScrollAnchor(topic id: Int, postNumber: Int) {
        guard postNumber > 0 else { return }
        var p = positions[id] ?? ReadPosition(lastReadPostNumber: 0,
                                              scrollAnchorPostNumber: 0,
                                              updatedAt: Date())
        p.scrollAnchorPostNumber = postNumber
        p.updatedAt = Date()
        positions[id] = p
        save()
    }

    // MARK: - persistence

    private func save() {
        prune()
        guard let data = try? JSONEncoder().encode(positions) else { return }
        defaults.set(data, forKey: key)
    }

    private func prune() {
        guard positions.count > capacity else { return }
        let stale = positions
            .sorted { $0.value.updatedAt < $1.value.updatedAt }
            .prefix(positions.count - capacity)
        for id in stale.map(\.key) {
            positions.removeValue(forKey: id)
        }
    }

    private nonisolated static func load(key: String, from defaults: UserDefaults) -> [Int: ReadPosition] {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([Int: ReadPosition].self, from: data)
        else { return [:] }
        return decoded
    }
}
