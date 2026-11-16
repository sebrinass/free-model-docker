#!/bin/sh
# Usage: build.sh [version] [image-tag]
#
#   version:   upstream tag or "latest" (default: latest)
#   image-tag: docker tag (default: ghcr.io/sebrinass/free-model-docker:local)
#
# Resolves + fetches the upstream source, then docker build.
# When docker is not available locally, do NOT try to install it — the image
# is built and pushed by GitHub Actions instead.
set -eu

VERSION="${1:-latest}"
IMAGE_TAG="${2:-ghcr.io/sebrinass/free-model-docker:local}"

if ! command -v docker >/dev/null 2>&1; then
    echo "docker not found on this machine; skipping local build."
    echo "The image is built and pushed by GitHub Actions (.github/workflows/update.yml)."
    exit 0
fi

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

if [ -z "$VERSION" ] || [ "$VERSION" = "latest" ]; then
    VERSION="$("$SCRIPT_DIR/resolve-tag.sh")"
fi

echo "fetching upstream source $VERSION into build/src"
"$SCRIPT_DIR/fetch-source.sh" "$VERSION" build/src

echo "building $IMAGE_TAG"
docker build -t "$IMAGE_TAG" .

echo "done: $IMAGE_TAG (upstream $VERSION)"
