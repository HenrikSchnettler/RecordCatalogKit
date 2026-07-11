#!/bin/bash

set -euo pipefail

cd "$(dirname "$0")/.."

VERSION="${1#v}"
OUTPUT_DIRECTORY="${2:-.build/releases}"

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z.-]+)?$ ]]; then
    echo "error: '$1' is not a supported semantic version." >&2
    exit 1
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "error: packaging requires a Git worktree." >&2
    exit 1
fi

mkdir -p "$OUTPUT_DIRECTORY"
ARCHIVE="$OUTPUT_DIRECTORY/RecordCatalogKit-$VERSION.zip"

git archive \
    --format=zip \
    --prefix="RecordCatalogKit-$VERSION/" \
    --output="$ARCHIVE" \
    HEAD

echo "$ARCHIVE"
