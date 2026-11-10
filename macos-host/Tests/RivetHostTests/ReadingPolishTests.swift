import Testing
import Foundation
@testable import RivetHost

/// The 0.15.0 reading-polish pure logic: link routing, local read state,
/// and relative timestamps. No store, no webview, no backend.
@MainActor
@Suite("Reading polish: routing, read state, relative time")
struct ReadingPolishTests {

    // MARK: - LinkRouter

    @Test func forumTopicLinksRouteInApp() {
        func route(_ path: String) -> LinkRoute {
            LinkRouter.route(URL(string: "https://racket.discourse.group\(path)")!)
        }
        // canonical /t/<slug>/<id>
        #expect(route("/t/some-slug/4416") == .topic(id: 4416, postNumber: nil))
        // with a post anchor
        #expect(route("/t/some-slug/4416/7") == .topic(id: 4416, postNumber: 7))
        // short form without the slug
        #expect(route("/t/4416") == .topic(id: 4416, postNumber: nil))
        // query and fragment ride along
        #expect(route("/t/s/4416/3?u=x#post-3") == .topic(id: 4416, postNumber: 3))
        // case-insensitive host
        #expect(LinkRouter.route(
            URL(string: "https://RACKET.Discourse.GROUP/t/x/4416")!)
            == .topic(id: 4416, postNumber: nil))
    }

    @Test func everythingElseRoutesToTheBrowser() {
        func route(_ url: String) -> LinkRoute {
            LinkRouter.route(URL(string: url)!)
        }
        // another site
        #expect(route("https://racket-lang.org/") == .external)
        // a forged host that merely contains the forum's name
        #expect(route("https://racket.discourse.group.evil.example/t/x/1") == .external)
        // same host, but not topic pages: forum UI paths stay external
        #expect(route("https://racket.discourse.group/latest") == .external)
        #expect(route("https://racket.discourse.group/u/someone") == .external)
        #expect(route("https://racket.discourse.group/t/some-slug") == .external)
        #expect(route("https://racket.discourse.group/t/not-a-number/also-not") == .external)
    }

    // MARK: - ReadStateStore

    private func freshStore() -> ReadStateStore {
        let name = "read-state-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return ReadStateStore(defaults: defaults, key: "read-state-v1")
    }

    @Test func unreadMathSkipsNeverOpenedTopics() {
        let store = freshStore()
        #expect(store.newPostCount(topic: 1, postsCount: 300) == 0)
    }

    @Test func readsMoveForwardOnly() {
        let store = freshStore()
        store.markRead(topic: 5, upTo: 20)
        store.markRead(topic: 5, upTo: 10)  // a shorter revisit never unreads
        #expect(store.newPostCount(topic: 5, postsCount: 25) == 5)
        store.markRead(topic: 5, upTo: 25)
        #expect(store.newPostCount(topic: 5, postsCount: 25) == 0)
    }

    @Test func stateSurvivesAcrossStoreInstances() {
        let name = "read-state-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        let first = ReadStateStore(defaults: defaults, key: "read-state-v1")
        first.markRead(topic: 9, upTo: 42)
        first.setScrollAnchor(topic: 9, postNumber: 40)

        let second = ReadStateStore(defaults: defaults, key: "read-state-v1")
        #expect(second.position(topic: 9)?.lastReadPostNumber == 42)
        #expect(second.position(topic: 9)?.scrollAnchorPostNumber == 40)
        #expect(second.newPostCount(topic: 9, postsCount: 50) == 8)
    }

    @Test func scrollAnchorMovesFreely() {
        let store = freshStore()
        store.setScrollAnchor(topic: 2, postNumber: 30)
        store.setScrollAnchor(topic: 2, postNumber: 7)  // scrolling up is legal
        #expect(store.position(topic: 2)?.scrollAnchorPostNumber == 7)
        #expect(store.position(topic: 2)?.lastReadPostNumber == 0,
                "anchoring alone must not mark anything read")
    }

    // MARK: - RelativeTime

    @Test func relativeBuckets() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        func at(_ seconds: Double) -> Date { now.addingTimeInterval(-seconds) }
        #expect(RelativeTime.format(at(10), now: now) == "now")
        #expect(RelativeTime.format(at(5 * 60), now: now) == "5m")
        #expect(RelativeTime.format(at(2 * 3600), now: now) == "2h")
        #expect(RelativeTime.format(at(3 * 86400), now: now) == "3d")
        // a week out falls back to the short absolute date
        let old = at(10 * 86400)
        #expect(RelativeTime.format(old, now: now)
                == ThreadWebView.displayFormatter.string(from: old))
    }

    @Test func unparseableDatesPassThrough() {
        #expect(RelativeTime.format("not a date") == "not a date")
        #expect(RelativeTime.format("") == "")
    }
}
