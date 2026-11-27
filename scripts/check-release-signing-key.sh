#!/usr/bin/env bash
set -euo pipefail
key="$(realpath "$1")"
cd "$(dirname "$0")/.."
actual="$(openssl pkey -in "$key" -pubout -outform DER | tail -c 32 | openssl base64 -A)"
racket_key="$(sed -n 's/^(define current-update-public-key "\([^"]*\)".*/\1/p' racket/update.rkt)"
swift_key="$(sed -n 's/^[[:space:]]*static let publicKeyBase64 = "\([^"]*\)".*/\1/p' macos-host/Sources/RivetHost/UpdateService.swift)"
[[ -n "$racket_key" && "$actual" == "$racket_key" && "$actual" == "$swift_key" ]] || { echo "Update key mismatch" >&2; exit 1; }
echo "Update key matches both embedded trust roots"
