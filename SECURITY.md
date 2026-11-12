# Security Policy

Threadly keeps your reading on your machine: forum content arrives from
the Discourse forum you configure, is cached on disk as plain JSON, and
your forum sign-in and AI credentials never leave the machine except to
the endpoints you configured them for. There is no telemetry and no
listening port. Reports are taken seriously and handled quickly.

## Reporting a vulnerability

Email **security@jrtx.site** (or open a GitHub security advisory on this
repository). Include reproduction steps, affected versions, and your
assessment of impact. You will get an acknowledgment within 72 hours.

Please do not open public issues for security problems.

## Scope

In scope:

- Update trust: verification of the Ed25519-signed `update-manifest.json`
  and its artifacts, key handling and rotation
  (`racket/update.rkt` — embedded public key and key id `threadly-2026-10`,
  `macos-host/Sources/RivetHost/UpdateService.swift`,
  `scripts/make-update-manifest.sh`, `scripts/update-keys.sh`,
  `scripts/test-release-signing.sh`)
- The forum API client: request signing and the Discourse user-API-key
  flow (`racket/core/discourse.rkt`, `racket/auth.rkt` — the app-generated RSA
  keypair, the `/user-api-key/new` handshake, nonce verification, the
  0600 user API key store). A forum response must never be able to
  escalate beyond reading what the user can read
- Local cache handling: the on-disk response cache
  (`racket/core/cache.rkt` — sha1-named JSON entries under a TTL, stale
  entries served when the forum is unreachable) and the updater state
  (`<data-dir>/updater-state.json` behind its one-key write whitelist)
- AI features: the OpenAI-compatible chat-completions client
  (`racket/ai.rkt`) — prompts and thread content go only to the
  user-configured base URL, and the API key stored via `ai-config` stays
  local
- The host/backend boundary: hosts render and install; the Racket backend
  (`racket/backend.rkt`) decides. Crypto or policy sneaking into a native
  host is a bug.

Out of scope: the security of the Discourse forum the user connects to
and of the AI provider the user configures (their APIs and handling of
request content belong to those services), social engineering, physical
access attacks, and defects in the OS-provided keychain and network
stacks.

## Design notes reviewers should know

- The backend owns no listening network port. Host ↔ backend RVT1 traffic
  runs over inherited file descriptors, and outbound network is limited
  to the configured forum, the configured AI endpoint, and update checks
  and downloads against GitHub Releases.
- **Hosts never implement crypto.** Manifest verification, digest checks
  and trust decisions live in the Racket backend (Rivet's distribution
  layer); the native hosts carry out installation steps the backend has
  already verified. The macOS updater host module holds only the embedded
  public key, which `scripts/make-update-manifest.sh` cross-checks
  against the backend's copy at signing time.
- **Updates and installer trust are different layers.** The update feed
  is Ed25519-signed and the payload digest is verified before anything is
  applied, but the macOS DMG is ad-hoc signed (not notarized), the
  Windows MSI and zip are unsigned, and the Linux packages carry no
  publisher signature. Releases publish a checked `SHA256SUMS`; do not
  represent the feed signature as an independently trusted publisher
  identity.
- Cached forum data and credentials are plain files protected by file
  modes (0600) and OS user permissions; nothing is encrypted at rest by
  the application itself, and nothing is uploaded anywhere.

## Supported versions

Security fixes land on `main` first and ship with the next tagged release.
During the 0.x preview there is no LTS branch.
