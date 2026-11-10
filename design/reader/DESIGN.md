# Threadly Reader — Design Contract (0.15.0 reading polish)

Single visual source for the topic reader document rendered by all three
hosts (WKWebView / WebView2 / WebKitGTK) and for the reading-related list
row treatments. Prototype: `design/reader/index.html` (true HTML/CSS, open
it in any browser; follows system light/dark).

## Tokens (unchanged from 0.14.0 where possible)

| Token | Value | Notes |
|---|---|---|
| Accent | `#C15F3C` | terracotta; authors, links, buttons, quote rails |
| Danger/liked | `#E0413E` | liked heart only |
| Secondary text | `color-mix(in srgb, currentColor 62%, transparent)` | 0.15.0 change: dim the inherited text color instead of fixed grey — fixed `rgba(128,128,128,…)` fails contrast on grey fills in dark mode (~2.5:1); `currentColor` mix keeps ≥4.5:1 in both schemes and tracks any host backdrop |
| Hairline | `rgba(128,128,128,.2)` | post separators, table rules |
| Fill | `rgba(128,128,128,.08–.14)` | code bg, quote bg, button hover |
| Column | `max-width: 680px`, padding `22px 28px 48px` | readability constant |
| Body type | system font 15px / 1.6 | platform `-apple-system` / Segoe UI / Adwaita |
| Mono | 13px platform mono (`ui-monospace` / Cascadia / Adwaita Mono) | code only |
| Radius | 6px inline elements, 8px code blocks | |
| Color scheme | `color-scheme: light dark`, body background transparent | hosts supply the backdrop |

## Element coverage contract (the 0.15.0 additions)

The forum's cooked HTML reaches the reader verbatim; the stylesheet must
render every element class the Racket forum actually emits. Minimum set:

1. **Tables** — wrapped in `.table-scroll` (horizontal overflow contained,
   never breaks the 680px column); hairline row rules; header row bold on
   fill; compact padding.
2. **`aside.quote`** — existing terracotta rail, plus the `.title` line
   (quote author) rendered as small caps secondary text.
3. **Oneboxes** (`aside.onebox`, `aside.onebox.wikipedia` etc.) — bordered
   rounded card; source domain in small caps secondary; description text
   normal body; thumbnail `max-width: 100%`.
4. **`details`/`summary`** — summary styled as an accent-tinted disclosure
   row, default browser marker suppressed in favor of `▸` rotation.
5. **Code blocks** — unchanged 8px-radius fill; horizontal scroll (Racket
   lines stay unbroken); `overflow-wrap: anywhere` for inline `code` only.
6. **`hr`** — faded hairline, generous vertical rhythm.

## Reading continuity (behavior contract)

1. **Relative timestamps** — meta line shows short relative time (`2h`,
   `3d`); older than 7 days falls back to a short absolute date. Full
   date+time always in `title=`. List rows use the same formatter,
   right-aligned, fed by `last-posted-at` (already in the RPC row).
2. **Load-more bar** (replaces one-shot "Load all"): sits after the last
   loaded post, `Showing 20 of 312 posts · [Load more]`; button shows a
   loading state while a batch is in flight; appends in place so scroll
   survives; empty batch removes the bar. Hosts call the engine in a loop
   (`topic-posts-page`).
3. **Jump to bottom** — floating pill button, bottom trailing corner of
   the reader pane (host-native, not in-document): jumps to the last post;
   hidden when already at the bottom.
4. **Read/unread** — host-local state per topic id. List rows show a
   terracotta dot + "N new" pill when `posts_count` exceeds the stored
   last-read count; opening a topic marks it read at the deepest post
   reached. Reopening restores scroll to the stored position.
5. **Link routing** (behavioral, no visual distinction): same-forum topic
   URLs (`/t/<slug>/<id>(/<post-number>)`) open in-app; anchors jump to
   the post when loaded; everything else opens the external browser.

## Signed-out demotion

- Like button (interactive) renders only when signed in; anonymous reads
  show the count as a plain secondary-text span (existing behavior, keep).
- Reply toolbar item hidden when signed out. Sign-in entry stays in the
  sidebar account section. No other signed-in UI is shown.

## Host parity rules

- The three hosts embed this stylesheet near-verbatim; platform
  differences are font stacks and the JS bridge name only. Any deviation
  beyond those is a bug.
- Windows/Linux parity for 0.15.0 features is tracked in issues (#15
  follow-ups); their shipped CSS must match this file before those
  issues close.

## HIG self-review (Apple design baseline, platform-agnostic)

- Clarity first: one column, one accent, hairline separators — content is
  the interface; no chrome competes with post text.
- Content over decoration: avatars and counts are the only imagery added
  by the app; everything else is the forum's own content.
- Feedback: load-more shows in-flight state; like settles both directions;
  jump-to-bottom appears only when it can act.
- Consistency: relative time, badges, and pills reuse one accent and one
  secondary text color; no new palette entries introduced in 0.15.0.
- Forgiveness: batch loading is cancellable by navigating away (host
  generation guard); a failed batch leaves the bar enabled for retry.
