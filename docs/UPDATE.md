# Updates — Threadly

The family update contract lives in **turlamai/taskly** at
[`shared/spec/UPDATE.md`](https://github.com/turlamai/taskly/blob/main/shared/spec/UPDATE.md);
Threadly inherits its behavior contract. This page records how Threadly
implements that contract and where its own trust facts live. The module
header of `app/update.rkt` is the code-level authority.

## Behavior contract (inherited from taskly)

- **Triggers**: one silent check shortly after launch, throttled to at
  most once per **4 hours**, plus a manual `检查更新… / Check for
  Updates…` menu item (App menu below About on macOS, Help menu on
  Windows/Linux) that bypasses the throttle. Threadly implements the
  throttle host-side: macOS keeps the stamp in UserDefaults, Windows in a
  stamp file under the temp directory (`app/update.rkt`, module header).
  The auto-check on/off user setting from the family contract is **not
  implemented yet** (Wave 2 evaluation).
- **Silent mode**: network failure / rate limit / throttle is silently
  ignored in the auto path — never a nag. The manual path reports every
  outcome.
- **Newer version found**: semver compare, downgrades ignored, consent
  dialog before anything is applied. Up to date → up-to-date status.
- **Verify then download**: the Racket backend verifies the Ed25519-signed
  manifest and the artifact digest (`app/update.rkt`); hosts never
  implement crypto. The backend owns the transfer
  (`<data-dir>/updates/`, progress via the `update-state` RPC); Linux
  AppImage installs swap the sibling release asset in place against its
  `.sha256` sidecar, then re-exec with the user's consent. A failed
  verification aborts and the running version keeps working — there is no
  unsigned fallback path.

## Threadly trust facts

| Fact | Value |
|---|---|
| Key id | `threadly-2026-10` |
| Feed URL | `https://github.com/turlamai/threadly/releases/latest/download/update-manifest.json` |
| Feed payloads | `threadly-<ver>-macos-arm64.zip`, `-macos-x64.zip`, `-windows-x64.zip`, `-linux-x64.tar.gz` (the four artifacts `scripts/make-update-manifest.sh` signs) |
| Embedded public key | base64 raw 32 bytes — `app/update.rkt` `current-update-public-key` and `macos-host/Sources/RivetHost/UpdateService.swift` `publicKeyBase64` (kept identical; `scripts/make-update-manifest.sh` refuses a signing key that does not match both) |
| Key custody | private key only in the keys vault and the `UPDATE_ED25519_PRIVATE_KEY` GitHub secret; minted by `scripts/update-keys.sh` |

## Rotation

Rotation ships a build that trusts the next key before releases stop
being signed with the old one. `scripts/test-release-signing.sh` is the
offline negative test: an unrelated Ed25519 key must never produce a feed
the shipped clients accept. Release CI additionally signs a stub manifest
with the real secret in the `signing-preflight` job before any platform
build runs.
