#!/usr/bin/env bash
#
# Compiles and runs the game-rule checks with the open-source Swift toolchain,
# so the rules can be verified without Xcode or a Mac.
#
#   ./run.sh              # uses `swiftc` from PATH
#   SWIFTC=/path swiftc ./run.sh
#
set -euo pipefail
cd "$(dirname "$0")"

SWIFTC="${SWIFTC:-swiftc}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# GameState imports Combine for its @Published properties, which does not exist
# outside Apple platforms. Stubs.swift provides those two types instead, and
# the import line is stripped only in this throwaway copy — Sources/Models
# stays the single source of truth.
mkdir -p "$TMP/Models"
for file in ../../Sources/Models/*.swift; do
  sed '/^import Combine$/d' "$file" > "$TMP/Models/$(basename "$file")"
done

"$SWIFTC" -swift-version 5 \
  Stubs.swift "$TMP"/Models/*.swift main.swift \
  -o "$TMP/rules-check"

"$TMP/rules-check"
