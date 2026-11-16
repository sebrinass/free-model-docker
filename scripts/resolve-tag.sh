#!/bin/sh
# Resolve the newest plain semver upstream tag (vN.N.N).
# Variant tags such as vN.N.N-macos-unofficial are rejected.
# Prints the tag to stdout. Exits 1 when no plain tag exists.
# No jq dependency: grep/sed only.
set -eu

RESPONSE="$(curl -fsSL "https://api.github.com/repos/Ebony-Vinyl/dsh-our-free-model/tags?per_page=100")"

TAG="$(printf '%s\n' "$RESPONSE" \
    | grep -oE '"name"[[:space:]]*:[[:space:]]*"[^"]*"' \
    | sed -E 's/^"name"[[:space:]]*:[[:space:]]*"([^"]*)".*$/\1/' \
    | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' \
    | head -n 1)"

if [ -z "$TAG" ]; then
    echo "error: no tag matching vN.N.N found in Ebony-Vinyl/dsh-our-free-model" >&2
    exit 1
fi

printf '%s\n' "$TAG"
