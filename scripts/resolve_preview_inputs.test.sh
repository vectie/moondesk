#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
TEMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/moondesk-preview-inputs.XXXXXX")
RESOLVER="$SCRIPT_DIR/resolve_preview_inputs.sh"
PREVIEW_NUMBER=0
while [ -e "$REPO_ROOT/docs/releases/0.0.0-preview.$PREVIEW_NUMBER.md" ]; do
  PREVIEW_NUMBER=$((PREVIEW_NUMBER + 1))
done
VERSION="0.0.0-preview.$PREVIEW_NUMBER"
NOTES="docs/releases/$VERSION.md"
TEST_NOTES="$REPO_ROOT/$NOTES"
trap 'rm -rf "$TEMP_ROOT"; rm -f "$TEST_NOTES"' EXIT HUP INT TERM
mkdir -p "$REPO_ROOT/docs/releases"
printf '# Test-only preview notes\n' > "$TEST_NOTES"

assert_eq() {
  [ "$1" = "$2" ] || {
    printf 'expected:\n%s\nactual:\n%s\n' "$1" "$2" >&2
    exit 1
  }
}

expect_exit() {
  expected=$1
  shift
  set +e
  "$@" >"$TEMP_ROOT/stdout" 2>"$TEMP_ROOT/stderr"
  actual=$?
  set -e
  [ "$actual" -eq "$expected" ] || {
    cat "$TEMP_ROOT/stderr" >&2
    printf 'expected exit %s, got %s\n' "$expected" "$actual" >&2
    exit 1
  }
}

cd "$REPO_ROOT"
expected=$(printf 'version=%s\nnotes=%s\noutput=%s/moondesk-%s' \
  "$VERSION" "$NOTES" "$TEMP_ROOT" "$VERSION")

push_output=$(
  "$RESOLVER" --event push --tag-or-version "v$VERSION" --notes "" \
    --output-root "$TEMP_ROOT"
)
assert_eq "$expected" "$push_output"

dispatch_output=$(
  "$RESOLVER" --event workflow_dispatch --tag-or-version "$VERSION" \
    --notes "$NOTES" --output-root "$TEMP_ROOT/"
)
assert_eq "$expected" "$dispatch_output"

expect_exit 65 "$RESOLVER" --event push --tag-or-version "$VERSION" \
  --notes "" --output-root "$TEMP_ROOT"
expect_exit 65 "$RESOLVER" --event push \
  --tag-or-version v1.2.3-preview.latest --notes "" \
  --output-root "$TEMP_ROOT"
expect_exit 65 "$RESOLVER" --event schedule --tag-or-version "v$VERSION" \
  --notes "" --output-root "$TEMP_ROOT"
expect_exit 66 "$RESOLVER" --event workflow_dispatch \
  --tag-or-version "$VERSION" --notes ../notes.md --output-root "$TEMP_ROOT"
expect_exit 67 "$RESOLVER" --event workflow_dispatch \
  --tag-or-version 9.9.9-preview.9 --notes "" --output-root "$TEMP_ROOT"
expect_exit 66 "$RESOLVER" --event workflow_dispatch \
  --tag-or-version "$VERSION" --notes "$NOTES" --output-root relative

printf '%s\n' 'preview input resolver tests passed'
