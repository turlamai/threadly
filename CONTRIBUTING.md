# Contributing to Threadly

Thank you for looking under the hood. Threadly is free software under
[AGPL-3.0](LICENSE): by submitting a pull request you agree your
contribution is licensed under AGPL-3.0, and you confirm you have the
right to submit it.

## Ground rules

1. **The wire contract is cross-platform.** `app/backend.rkt` declares
   the typed RPC/Event/State surface. Changing any of it is a
   three-platform release: regenerate the checked-in clients with
   `raco rivet build` (`linux/GeneratedBackend.hpp`,
   `windows/GeneratedBackend.hpp`,
   `macos-host/Sources/RivetHost/GeneratedBackend.swift`) in the same
   commit — they are build inputs, never hand-edit them.
2. **The pin discipline holds.** `RIVET_PIN` (top of `.github/workflows/ci.yml`
   and `release.yml`) is the single source of truth for the rivet
   revision; the literal `setup-embed-racket` action ref in release.yml
   must stay in lockstep with it. Rivet is consumed as a package — never
   compile or hand-copy rivet sources into this repository.
3. **The update contract is fail-closed.** `docs/UPDATE.md` records the
   inherited family contract (4-hour silent throttle, silent auto path,
   backend-verified Ed25519 feed, key id `threadly-2026-10`). A failed
   verification aborts and the running version keeps working; there is
   no unsigned fallback path. `scripts/test-release-signing.sh` proves
   an untrusted key can never produce an accepted feed — keep it green.
4. **Version has one source.** `VERSION` must agree with `rivet.rktd`
   and `app/version.rkt`; `scripts/check-release-version.sh` enforces it
   and release CI additionally pins the tag to it.
5. **Privacy is a feature.** The configured forum, the configured AI
   endpoint and the signed update feed are the application's only
   network use. No telemetry, no accounts. The politeness layer
   (`app/core/cache.rkt`) exists so re-opening a view never re-hits the
   forum — do not bypass it.
6. **Fail honestly.** An unreachable forum serves the stale cache entry;
   a failed update verification aborts with the running version intact;
   sign-in failures surface the forum's own message. No silent
   fallbacks beyond the documented stale-cache behavior.
7. **Tests pin contracts.** If you change behavior a test covers, change
   the test in the same commit and say why (`raco test tests/` — the
   suite needs no network).

## Before you push

```bash
bash scripts/check-release-version.sh      # VERSION == rivet.rktd == app/version.rkt
bash scripts/test-release-signing.sh       # untrusted signing key must be rejected
raco test tests/                           # backend contract tests
```

These mirror the CI backend job (it links a rivet sibling checkout and
installs `crypto` first). Platform hosts compile in their own CI jobs
via `raco rivet build`; if you touch `macos-host/`, `windows/` or
`linux/`, say whether you were able to build locally. The signing test
needs OpenSSL 3 for Ed25519 — macOS's system LibreSSL cannot do it, so
put a real OpenSSL 3 first on `PATH` (e.g.
`/opt/homebrew/opt/openssl@3/bin`).

## Reporting issues

Include: OS + version, Threadly version (the About dialog or
`racket app/cli.rkt doctor`), installation shape (DMG / portable zip /
MSI / AppImage / deb / rpm / tar.gz), the forum URL when the issue is
forum-specific, and steps to reproduce. For update failures, include the
error text from the dialog. Security issues go through
[SECURITY.md](SECURITY.md), not public issues.
