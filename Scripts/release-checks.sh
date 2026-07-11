#!/bin/bash

set -euo pipefail

cd "$(dirname "$0")/.."

VERSION="${1#v}"

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z.-]+)?$ ]]; then
    echo "error: '$1' is not a supported semantic version." >&2
    exit 1
fi

if ! grep -Eq "^## ${VERSION}([[:space:]-]|$)" CHANGELOG.md; then
    echo "error: CHANGELOG.md has no section for $VERSION." >&2
    exit 1
fi

PACKAGE_NAME="$(swift package dump-package | /usr/bin/python3 -c 'import json, sys; print(json.load(sys.stdin)["name"])')"
if [[ "$PACKAGE_NAME" != "RecordCatalogKit" ]]; then
    echo "error: expected package name RecordCatalogKit, found $PACKAGE_NAME." >&2
    exit 1
fi

./Scripts/lint.sh
swift test
swift build -c release
