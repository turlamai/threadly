import Foundation

/// The forum this build reads. One constant instead of the three string
/// copies the host used to carry (sign-in label, forum link, webview base
/// URL). Multi-forum support is explicitly out of scope; this only stops
/// the copies from drifting.
enum ForumIdentity {
    static let baseURL = "https://racket.discourse.group"
    static let host = "racket.discourse.group"
}

/// What a clicked link inside the reader should do. Same-forum topic
/// links stay in the app (the core reading loop — following a reference
/// to another thread); everything else opens in the user's browser.
enum LinkRoute: Equatable {
    case topic(id: Int, postNumber: Int?)
    case external
}

enum LinkRouter {
    /// Pure and total: any URL yields exactly one route. Discourse topic
    /// URLs are /t/<slug>/<id>[/post-number] (the slug may be absent:
    /// /t/<id>), optional #fragment, optional query. Case-insensitive on
    /// the host; path is taken literally otherwise.
    static func route(_ url: URL, forumHost: String = ForumIdentity.host) -> LinkRoute {
        guard let host = url.host, host.lowercased() == forumHost.lowercased() else {
            return .external
        }
        let parts = url.pathComponents.filter { $0 != "/" }
        // /t/<id>  |  /t/<slug>/<id>  |  /t/<slug>/<id>/<post-number>
        guard parts.first == "t", parts.count >= 2 else { return .external }
        // the slug is optional but a bare /t/<slug> is a forum UI page,
        // not a topic — the id must be a number wherever it sits
        if parts.count == 2 {
            guard let id = Int(parts[1]) else { return .external }
            return .topic(id: id, postNumber: nil)
        }
        guard let id = Int(parts[2]) else { return .external }
        let postNumber = parts.count >= 4 ? Int(parts[3]) : nil
        return .topic(id: id, postNumber: postNumber)
    }
}

/// Compact relative timestamps ("2h", "3d") with an absolute fallback
/// past a week. Deterministic (no Locale string tables), so the reader
/// and the list rows always agree; the full date travels separately in
/// tooltips and titles.
enum RelativeTime {
    private static let minute = 60.0
    private static let hour = 60 * minute
    private static let day = 24 * hour
    private static let week = 7 * day

    /// ISO-8601 → "now" / "5m" / "2h" / "3d" / "Nov 1" (past the week).
    /// Unparseable input passes through untouched.
    static func format(_ iso: String, now: Date = Date()) -> String {
        guard let date = ThreadWebView.isoFormatter.date(from: iso)
                ?? ThreadWebView.fallbackFormatter.date(from: iso) else {
            return iso
        }
        return format(date, now: now)
    }

    static func format(_ date: Date, now: Date) -> String {
        let dt = now.timeIntervalSince(date)
        if dt < 0 { return "now" }
        if dt < minute { return "now" }
        if dt < hour { return "\(Int(dt / minute))m" }
        if dt < day { return "\(Int(dt / hour))h" }
        if dt < week { return "\(Int(dt / day))d" }
        return ThreadWebView.displayFormatter.string(from: date)
    }
}
