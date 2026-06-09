#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GRDB_DIR="$ROOT/SourcePackages/checkouts/GRDB.swift"
GRDB_VERSION="7.11.0"

if [[ -d "$GRDB_DIR/.git" ]]; then
  echo "GRDB already present at $GRDB_DIR"
  exit 0
fi

mkdir -p "$ROOT/SourcePackages/checkouts"

echo "Cloning GRDB.swift $GRDB_VERSION with submodules..."
git clone --recurse-submodules --depth 1 --branch "$GRDB_VERSION" \
  https://github.com/groue/GRDB.swift "$GRDB_DIR"

echo "Done. Open Pocket Catch Rater.xcodeproj and build."
