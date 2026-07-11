#!/bin/bash

set -euo pipefail

cd "$(dirname "$0")/.."

if ! command -v swiftformat >/dev/null 2>&1; then
    echo "error: SwiftFormat is not installed. Run: brew install swiftformat" >&2
    exit 1
fi

swiftformat Sources Tests Package.swift --cache ignore
