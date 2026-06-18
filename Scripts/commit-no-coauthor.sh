#!/usr/bin/env bash
# Create a commit without using `git commit` (Cursor injects Co-authored-by trailers).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

MSG_FILE="$(mktemp)"
trap 'rm -f "$MSG_FILE"' EXIT

cat > "$MSG_FILE" <<'EOF'
Implement Gen 7–9 specialty balls and GitHub Release IPA workflow.

Love, Moon, Fast, Dream, and Beast balls use species-aware bonuses with header toggles where needed; Friend Ball joins standard-ball skins; base Speed syncs from PokeAPI; v0.3 adds tag-triggered unsigned IPA builds on GitHub Releases.
EOF

if git diff --cached --quiet; then
  echo "Nothing staged. Stage files before running this script." >&2
  exit 1
fi

PARENT="$(git rev-parse HEAD)"
TREE="$(git write-tree)"
COMMIT="$(git commit-tree "$TREE" -p "$PARENT" -F "$MSG_FILE")"
git update-ref HEAD "$COMMIT"

echo "Created commit $COMMIT"
git log -1 --format=full
