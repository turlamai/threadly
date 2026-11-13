#!/usr/bin/env bash
# Build update-manifest.json for a release and sign it — the family
# signed-wrapper format every rivet/distribution client verifies (see
# racket/update.rkt for the format contract).
#
#   scripts/make-update-manifest.sh <tag> <dist-dir> [key-path]
#
#   <tag>       release tag, e.g. v1.4.0 (must match the VERSION file)
#   <dist-dir>  directory containing the release artifacts, i.e. the names
#               the release pipeline produces:
#                 threadly-<ver>-macos-arm64.zip   threadly-<ver>-macos-x64.zip
#                 threadly-<ver>-windows-x64.zip
#                 threadly-<ver>-linux-x64.tar.gz
#               (the DMG / MSI / deb / rpm / AppImage are human installers,
#               not feed entries)
#   <key-path>  Ed25519 private key PEM (default: $UPDATE_KEY_PATH, then
#               ~/.threadly/update-signing-key.pem)
#
# The signing, artifact hashing, schema validation, and feed format live in
# `raco rivet sign-manifest`; this wrapper keeps Threadly's four artifacts,
# identity, and the trust-root guard that refuses a key installed clients
# do not trust.
set -euo pipefail

TAG="${1:?usage: make-update-manifest.sh <tag> <dist-dir> [key-path]}"
DIST="${2:?usage: make-update-manifest.sh <tag> <dist-dir> [key-path]}"
KEY="${3:-${UPDATE_KEY_PATH:-$HOME/.threadly/update-signing-key.pem}}"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST="$(cd "$DIST" && pwd)"
cd "$ROOT"

VERSION="${TAG#v}"
raco rivet check-release-version "$TAG"
[[ -f "$KEY" ]] || {
  echo "error: missing signing key $KEY (see scripts/update-keys.sh)" >&2
  exit 1
}

APP_ID="$(sed -nE 's/.*\(identifier \. "([^"]+)"\).*/\1/p' "$ROOT/rivet.rktd" | head -n1)"
BUILD="$(sed -nE 's/.*\(build \. ([0-9]+)\).*/\1/p' "$ROOT/rivet.rktd" | head -n1)"
[[ -n "$APP_ID" && -n "$BUILD" ]] || {
  echo "error: could not read application id/build from rivet.rktd" >&2
  exit 1
}

BASE_URL="${RELEASE_ASSET_BASE_URL:-https://github.com/turlamai/threadly/releases/download/$TAG}"

# Ed25519 needs OpenSSL 3+ (macOS ships LibreSSL, which cannot do it).
OPENSSL_BIN="${OPENSSL_BIN:-}"
if [[ -z "$OPENSSL_BIN" ]]; then
  for candidate in /opt/homebrew/opt/openssl@3/bin/openssl \
                   /usr/local/opt/openssl@3/bin/openssl openssl; do
    if command -v "$candidate" >/dev/null 2>&1 \
       && "$candidate" version 2>/dev/null | grep -q "OpenSSL 3"; then
      OPENSSL_BIN="$candidate"
      break
    fi
  done
fi
[[ -n "$OPENSSL_BIN" ]] || {
  echo "error: OpenSSL 3.x required for Ed25519 (brew install openssl@3," >&2
  echo "       or set OPENSSL_BIN=/path/to/openssl)" >&2
  exit 1
}

KEY_DER="$(mktemp "${TMPDIR:-/tmp}/threadly-key-XXXXXX.der")"
PUB_DER="$(mktemp "${TMPDIR:-/tmp}/threadly-public-XXXXXX.der")"
trap 'rm -f "$KEY_DER" "$PUB_DER"' EXIT

# Refuse a syntactically valid signature from a key that installed clients
# do not trust. Ed25519 SPKI is 12-byte prefix + 32-byte raw public key.
"$OPENSSL_BIN" pkey -in "$KEY" -pubout -outform DER -out "$PUB_DER"
[[ "$(wc -c < "$PUB_DER")" -eq 44 ]] || {
  echo "error: signing key is not an Ed25519 key" >&2
  exit 1
}
PUBLIC_B64="$(tail -c 32 "$PUB_DER" | base64 | tr -d '\r\n')"
EXPECTED_RACKET="$(sed -n 's/^(define current-update-public-key "\([^"]*\)".*/\1/p' "$ROOT/racket/update.rkt")"
EXPECTED_SWIFT="$(sed -n 's/^[[:space:]]*static let publicKeyBase64 = "\([^"]*\)".*/\1/p' "$ROOT/macos-host/Sources/RivetHost/UpdateService.swift")"
if [[ -z "$EXPECTED_RACKET" || -z "$EXPECTED_SWIFT" ||
      "$PUBLIC_B64" != "$EXPECTED_RACKET" || "$PUBLIC_B64" != "$EXPECTED_SWIFT" ]]; then
  echo "error: signing key does not match embedded Racket and macOS Ed25519 public keys" >&2
  exit 1
fi

# rivet's signer reads DER (OneAsymmetricKey); convert the PEM once here.
"$OPENSSL_BIN" pkey -in "$KEY" -outform DER -out "$KEY_DER"

raco rivet sign-manifest \
  --application-id "$APP_ID" \
  --version "$VERSION" \
  --build "$BUILD" \
  --channel stable \
  --base-url "$BASE_URL" \
  --key-id threadly-2026-10 \
  --private-key "$KEY_DER" \
  --output "$DIST/update-manifest.json" \
  --artifact "macos:arm64:zip:$DIST/threadly-$VERSION-macos-arm64.zip" \
  --artifact "macos:x64:zip:$DIST/threadly-$VERSION-macos-x64.zip" \
  --artifact "windows:x64:zip:$DIST/threadly-$VERSION-windows-x64.zip" \
  --artifact "linux:x64:targz:$DIST/threadly-$VERSION-linux-x64.tar.gz" \
  --rollback-allowed

echo "manifest: $DIST/update-manifest.json (4 artifacts, key-id threadly-2026-10)"
