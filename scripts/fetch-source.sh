#!/bin/sh
# Usage: fetch-source.sh <version|latest> [dest]
#
#   version: an exact upstream tag (e.g. v2.8.5) or "latest" (resolved via resolve-tag.sh)
#   dest:    unpack directory (default: build/src)
#
# Downloads the upstream git-tag tarball (NOT npm: packages/standalone is not
# shipped in the npm package files or in GitHub Release artifacts) and
# unpacks it into dest.
set -eu

VERSION="${1:-latest}"
DEST="${2:-build/src}"

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

if [ -z "$VERSION" ] || [ "$VERSION" = "latest" ]; then
    VERSION="$("$SCRIPT_DIR/resolve-tag.sh")"
fi

# Hard gate: only a plain vN.N.N tag is acceptable (blocks -macos-unofficial etc.)
if ! printf '%s\n' "$VERSION" | grep -Eq '^v[0-9]+\.[0-9]+\.[0-9]+$'; then
    echo "error: '$VERSION' does not match vN.N.N; refusing to fetch" >&2
    exit 1
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

URL="https://github.com/Ebony-Vinyl/dsh-our-free-model/archive/refs/tags/${VERSION}.tar.gz"
echo "downloading $URL"
curl -fsSL -o "$TMP/source.tar.gz" "$URL"

rm -rf "$DEST"
mkdir -p "$DEST"
# Excluded from the image: docs, CI config, share packages, the 72MB magpie
# Windows binary and the 25MB engine parts (magpie is an optional local engine
# that cannot run on Linux anyway). Everything else (e.g. vendor/magpie/engine.json)
# is kept.
tar -xzf "$TMP/source.tar.gz" -C "$DEST" --strip-components=1 \
    --exclude='*/docs' \
    --exclude='*/.github' \
    --exclude='*/.trae-html-share-packages' \
    --exclude='*/vendor/magpie/bin' \
    --exclude='*/src/engine-parts'

# Belt and braces: guarantee the excluded paths are gone even if the tar
# exclude semantics differ on some platform.
(
    cd "$DEST"
    rm -rf docs .github .trae-html-share-packages vendor/magpie/bin src/engine-parts
)

printf '%s\n' "$VERSION" > "$(dirname "$DEST")/SOURCE_VERSION"
echo "fetched upstream $VERSION into $DEST"
