import Testing
import Foundation
import RivetRuntime
@testable import RivetHost

/// Issue #2's delayed-response fixtures, at the store level: a scripted
/// RivetAPI transport answers each RPC from a handler the test controls,
/// and gates hold chosen calls open until the test releases them. That
/// reproduces the engine's real async ordering (slow topic A, fast topic
/// B) without a network, a backend, or UI automation.
final class ScriptedTransport: RivetGeneratedRPCClient, @unchecked Sendable {
    struct UnexpectedCall: Error {}
    struct ScriptedFailure: Error { let label: String }

    typealias Handler = @Sendable ([RivetValue]) async throws -> RivetValue

    private let lock = NSLock()
    private var handlers: [String: Handler] = [:]
    private var openGates: [String: AsyncStream<Void>.Continuation] = [:]
    private var enteredGates: Set<String> = []

    /// NSLock's lock/unlock are unavailable inside async bodies; all
    /// state access goes through this synchronous scope.
    private func withLock<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }

    /// Replaces the handler for an RPC name.
    func answer(_ name: String, with handler: @escaping Handler) {
        withLock { handlers[name] = handler }
    }

    /// Whether a call has reached (and is parked in) `name`'s gate.
    func isGated(_ name: String) -> Bool {
        withLock { enteredGates.contains(name) }
    }

    /// Parks the calling handler until `release(name)` — the delayed
    /// response. The handler is already running inside its RPC, so the
    /// store's await is genuinely in flight when the gate holds it.
    func gate(_ name: String) async throws -> Void {
        let (stream, continuation) = AsyncStream<Void>.makeStream()
        withLock {
            enteredGates.insert(name)
            openGates[name] = continuation
        }
        await stream.first(where: { _ in true })
    }

    func release(_ name: String) {
        let continuation = withLock { openGates.removeValue(forKey: name) }
        continuation?.yield()
        continuation?.finish()
    }

    func call(_ name: String, arguments: [RivetValue]) async throws -> RivetValue {
        let handler = withLock { handlers[name] }
        guard let handler else { throw UnexpectedCall() }
        return try await handler(arguments)
    }

    // ---- row factories (backend.rkt layouts) -------------------------

    /// topic-post row = (author avatar html created number post-id likes
    /// liked total)
    static func postRows(author: String, total: Int) -> RivetValue {
        .list([postRow(author: author, number: 1, postId: 101, total: total)])
    }

    /// One topic-post row with explicit number/id.
    static func postRow(author: String, number: Int, postId: Int,
                        total: Int) -> RivetValue {
        .list([
            .string(author), .string(""), .string("<p>from \(author)</p>"),
            .string("2026-10-25T00:00:00.000Z"), .string(String(number)),
            .string(String(postId)), .string("0"), .string("0"),
            .string(String(total)),
        ])
    }

    /// A list of topic-post rows (a "page").
    static func pageRows(_ rows: [RivetValue]) -> RivetValue { .list(rows) }

    static func authOut() -> RivetValue { .list([.string("out"), .string("")]) }
}

/// Polls until `condition` holds; the store spawns unstructured Tasks
/// for retry/sign-out/reply, so tests wait for their effects instead of
/// guessing scheduling.
@MainActor
private func waitUntil(
    timeout: TimeInterval = 2, _ condition: @MainActor () -> Bool
) async throws {
    let deadline = Date().addingTimeInterval(timeout)
    while !condition() {
        if Date() > deadline {
            Issue.record("condition not met within \(timeout)s")
            return
        }
        try await Task.sleep(nanoseconds: 10_000_000)
    }
}

@MainActor
@Suite("ThreadlyStore topic identity (issue #2)")
struct ThreadlyStoreRaceTests {

    private func makeStore(_ transport: ScriptedTransport) -> ThreadlyStore {
        let store = ThreadlyStore()
        store.bind(api: RivetAPI(client: transport))
        return store
    }

    /// Delay topic A, select B, resolve B, then release A with a full
    /// answer: header, posts, counts and total must stay B's, and the
    /// dropped A completion must leave no error or spinner behind.
    @Test func lateTopicAResolvedCannotOverwriteB() async throws {
        let transport = ScriptedTransport()
        transport.answer("auth-status") { _ in ScriptedTransport.authOut() }
        transport.answer("topic-open") { args in
            guard case .string(let id) = args[0] else {
                throw ScriptedTransport.UnexpectedCall()
            }
            if id == "11" {
                try await transport.gate("topic-11")
                return ScriptedTransport.postRows(author: "A", total: 9)
            }
            return ScriptedTransport.postRows(author: "B", total: 3)
        }

        let store = makeStore(transport)
        async let a = store.openTopicId(11, title: "Topic A")
        try await waitUntil { store.selectedTopic?.id == 11 }
        async let b = store.openTopicId(22, title: "Topic B")
        try await waitUntil { store.posts.first?.author == "B" }

        transport.release("topic-11")
        _ = await (a, b)

        #expect(store.selectedTopic?.id == 22)
        #expect(store.selectedTopic?.title == "Topic B")
        #expect(store.posts.count == 1)
        #expect(store.posts.first?.author == "B")
        #expect(store.postsTotal == 3)
        #expect(store.topicLoadError == nil)
        #expect(store.loadingPosts == false)
    }

    /// Same interleaving with A failing late: the late error must not
    /// clear B's posts or surface a stale error.
    @Test func lateTopicAErrorCannotClearB() async throws {
        let transport = ScriptedTransport()
        transport.answer("auth-status") { _ in ScriptedTransport.authOut() }
        transport.answer("topic-open") { args in
            guard case .string(let id) = args[0] else {
                throw ScriptedTransport.UnexpectedCall()
            }
            if id == "11" {
                try await transport.gate("topic-11")
                throw ScriptedTransport.ScriptedFailure(label: "offline-late-A")
            }
            return ScriptedTransport.postRows(author: "B", total: 3)
        }

        let store = makeStore(transport)
        async let a = store.openTopicId(11, title: "Topic A")
        try await waitUntil { store.selectedTopic?.id == 11 }
        async let b = store.openTopicId(22, title: "Topic B")
        try await waitUntil { store.posts.first?.author == "B" }

        transport.release("topic-11")
        _ = await (a, b)

        #expect(store.selectedTopic?.id == 22)
        #expect(store.posts.first?.author == "B")
        #expect(store.topicLoadError == nil)
        #expect(store.statusLine == "")
    }

    /// Offline open: the reader shows an error state bound to the failed
    /// topic; Retry in place succeeds without a restart, the sidebar
    /// list untouched.
    @Test func offlineOpenThenRetrySucceeds() async throws {
        let transport = ScriptedTransport()
        transport.answer("auth-status") { _ in ScriptedTransport.authOut() }
        transport.answer("topic-open") { _ in
            throw ScriptedTransport.ScriptedFailure(label: "offline")
        }

        let store = makeStore(transport)
        await store.openTopicId(33, title: "Offline topic")
        #expect(store.selectedTopic?.id == 33)
        #expect(store.topicLoadError != nil)
        #expect(store.posts.isEmpty)
        #expect(store.loadingPosts == false)

        // network returns for the retry
        transport.answer("topic-open") { _ in
            ScriptedTransport.postRows(author: "R", total: 2)
        }
        store.retryOpenTopic()
        try await waitUntil { store.posts.first?.author == "R" }
        #expect(store.topicLoadError == nil)
        #expect(store.selectedTopic?.id == 33)
    }

    /// Going back to the list invalidates an in-flight open: the late
    /// completion must not repopulate the closed reader.
    @Test func closeTopicDropsInFlightOpen() async throws {
        let transport = ScriptedTransport()
        transport.answer("auth-status") { _ in ScriptedTransport.authOut() }
        transport.answer("topic-open") { _ in
            try await transport.gate("topic-44")
            return ScriptedTransport.postRows(author: "L", total: 5)
        }

        let store = makeStore(transport)
        async let a = store.openTopicId(44, title: "Late topic")
        try await waitUntil { transport.isGated("topic-44") }
        store.closeTopic()
        transport.release("topic-44")
        _ = await a

        #expect(store.selectedTopic == nil)
        #expect(store.posts.isEmpty)
        #expect(store.topicLoadError == nil)
        #expect(store.loadingPosts == false)
    }

    /// Signing out invalidates an in-flight signed read the same way.
    @Test func signOutDropsInFlightOpen() async throws {
        let transport = ScriptedTransport()
        transport.answer("auth-status") { _ in ScriptedTransport.authOut() }
        transport.answer("auth-sign-out") { _ in .null }
        transport.answer("topic-open") { _ in
            try await transport.gate("topic-55")
            return ScriptedTransport.postRows(author: "S", total: 5)
        }

        let store = makeStore(transport)
        async let a = store.openTopicId(55, title: "Signed topic")
        try await waitUntil { transport.isGated("topic-55") }
        store.signOut()
        transport.release("topic-55")
        _ = await a

        #expect(store.posts.isEmpty)
        #expect(store.signedInUser == nil)
        #expect(store.loadingPosts == false)
    }

    /// A draft reply survives failed loads and composer dismissals and
    /// is only forgotten once the reply actually posts.
    @Test func replyDraftSurvivesUntilPosted() async throws {
        let transport = ScriptedTransport()
        transport.answer("auth-status") { _ in
            .list([.string("in"), .string("tester")])
        }
        transport.answer("topic-open") { _ in
            throw ScriptedTransport.ScriptedFailure(label: "offline")
        }
        transport.answer("post-create") { _ in
            .list([.list([.string("9001"), .string("2")])])
        }

        let store = makeStore(transport)
        await store.openTopicId(66, title: "Draft topic")
        let topic = try #require(store.selectedTopic)

        store.saveDraftReply("my unfinished reply", for: topic)
        #expect(store.draftReply(for: topic) == "my unfinished reply")

        // a failed reload of the same thread keeps the draft
        await store.openTopicId(66, title: "Draft topic")
        #expect(store.draftReply(for: topic) == "my unfinished reply")

        // posting succeeds: the draft becomes a forum post and is dropped
        store.submitReply(to: topic, raw: "my unfinished reply")
        try await waitUntil { store.draftReply(for: topic).isEmpty }
        #expect(store.replySheetTopic == nil)
    }

    /// The load-more page is bound to the same identity as every other
    /// read: a page answering after the reader moved on is dropped whole.
    @Test func loadMoreDropsSupersededPage() async throws {
        let transport = ScriptedTransport()
        transport.answer("auth-status") { _ in ScriptedTransport.authOut() }
        transport.answer("topic-open") { _ in
            ScriptedTransport.postRows(author: "B", total: 1)
        }
        transport.answer("topic-posts-page") { _ in
            try await transport.gate("page-77")
            return ScriptedTransport.pageRows([
                ScriptedTransport.postRow(author: "B", number: 2, postId: 202, total: 40)
            ])
        }

        let store = makeStore(transport)
        await store.openTopicId(77, title: "Paged topic")

        async let page = store.fetchMorePosts(topicId: 77, loadedCount: 1,
                                              highestLoadedPostNumber: 1)
        try await waitUntil { transport.isGated("page-77") }
        // the user moves to another topic while the page is in flight
        await store.openTopicId(88, title: "Next topic")
        transport.release("page-77")
        let dropped = await page

        #expect(dropped == nil)  // stale: belongs to the abandoned thread
        #expect(store.selectedTopic?.id == 88)
    }

    /// A page is deduped against the rendered frontier: rows at or below
    /// the highest loaded post number are dropped, so a raced or
    /// re-delivered batch can never double-render a post.
    @Test func loadMoreDedupesAgainstRenderedFrontier() async throws {
        let transport = ScriptedTransport()
        transport.answer("auth-status") { _ in ScriptedTransport.authOut() }
        transport.answer("topic-open") { _ in
            ScriptedTransport.pageRows([
                ScriptedTransport.postRow(author: "B", number: 1, postId: 101, total: 4),
                ScriptedTransport.postRow(author: "B", number: 2, postId: 102, total: 4),
            ])
        }
        transport.answer("topic-posts-page") { _ in
            ScriptedTransport.pageRows([
                ScriptedTransport.postRow(author: "B", number: 3, postId: 103, total: 4),
                // a stale row below the frontier (stream shifted under us)
                ScriptedTransport.postRow(author: "B", number: 2, postId: 102, total: 4),
            ])
        }

        let store = makeStore(transport)
        await store.openTopicId(77, title: "Paged topic")
        #expect(store.posts.map(\.number) == [1, 2])

        let page = await store.fetchMorePosts(topicId: 77, loadedCount: 2,
                                              highestLoadedPostNumber: 2)
        #expect(page?.tail.map(\.number) == [3])
        #expect(page?.total == 4)
    }
}
