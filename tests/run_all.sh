#!/usr/bin/env bash
# Run all GDScript unit tests via headless Godot.
# Usage: ./tests/run_all.sh

set -e
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

GODOT="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"

# Filter out informational log lines from Godot output for a cleaner report.
FILTER='^(Godot Engine|OpenGL|Vulkan|\[|Could not find)'

any_fail=0
for test_script in tests/test_*.gd; do
    name="$(basename "$test_script" .gd)"
    echo "━━━ ${name} ━━━"
    output=$("$GODOT" --headless --path . --script "res://${test_script}" 2>&1 || true)
    echo "$output" | grep -vE "$FILTER" | grep -v "^$" || true
    if echo "$output" | grep -q "Failed: 0"; then
        :
    elif echo "$output" | grep -qE "All tests passed"; then
        :
    else
        echo "TEST FILE FAILED"
        any_fail=1
    fi
    echo ""
done

exit $any_fail
