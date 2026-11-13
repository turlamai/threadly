#!/usr/bin/env bash
# Generate the Ed25519 update-signing key pair for Threadly.
# The private key NEVER leaves this machine (and never enters the repo);
# `raco rivet update-keys` prints every embedding form, including the
# raw 32-byte base64 used by the native hosts and the DER base64 for CI.
#
# Usage: scripts/update-keys.sh [private-key-path]
#   default private key path: ~/.threadly/update-signing-key.pem
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KEY_PATH="${1:-$HOME/.threadly/update-signing-key.pem}"
KEY_ID="$(sed -n 's/^(define current-update-key-id "\([^"]*\)".*/\1/p' "$ROOT/racket/update.rkt")"
[[ "$KEY_ID" =~ ^[A-Za-z0-9._-]+$ ]] || {
  echo "error: could not read a valid current-update-key-id from racket/update.rkt" >&2
  exit 1
}

exec raco rivet update-keys --key "$KEY_PATH" --key-id "$KEY_ID"
