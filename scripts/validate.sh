#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
UI_DIR="$REPO_ROOT/ui/rabbita-desk"
MODE=${1:-fast}

usage() {
  printf 'Usage: %s [fast|full]\n' "$0" >&2
}

case "$MODE" in
  fast|full) ;;
  *) usage; exit 2 ;;
esac

stage() {
  printf '\n==> %s\n' "$1"
  shift
  "$@"
}

verify_generated_interfaces() {
  before=$(mktemp "${TMPDIR:-/tmp}/moondesk-mbti-before.XXXXXX")
  after=$(mktemp "${TMPDIR:-/tmp}/moondesk-mbti-after.XXXXXX")
  trap 'rm -f "$before" "$after"' EXIT HUP INT TERM
  (
    cd "$REPO_ROOT"
    git ls-files -z -- '*.mbti' | sort -z |
      xargs -0 shasum >"$before"
    moon info --target native
    moon info --target js
    (cd "$UI_DIR" && moon info --target js)
    git ls-files -z -- '*.mbti' | sort -z |
      xargs -0 shasum >"$after"
  )
  if ! cmp -s "$before" "$after"; then
    printf '%s\n' 'Generated MoonBit interfaces changed; regenerate and review them explicitly.' >&2
    diff -u "$before" "$after" || true
    return 1
  fi
  rm -f "$before" "$after"
  trap - EXIT HUP INT TERM
}

verify_clean_tree() {
  status=$(git -C "$REPO_ROOT" status --porcelain --untracked-files=all)
  if [ -n "$status" ]; then
    printf '%s\n' 'Validation changed tracked or untracked repository files:' >&2
    printf '%s\n' "$status" >&2
    return 1
  fi
}

run_boundary_validators() {
  # The boundary validator owns this three-checkout contract.
  set_count=0
  [ -n "${MOONCLAW_ROOT:-}" ] && set_count=$((set_count + 1))
  [ -n "${MOONBOOK_ROOT:-}" ] && set_count=$((set_count + 1))
  [ -n "${MOONTOWN_ROOT:-}" ] && set_count=$((set_count + 1))

  case "$set_count" in
    0)
      printf '%s\n' 'Skipping core boundary validation: MOONCLAW_ROOT, MOONBOOK_ROOT, and MOONTOWN_ROOT are not set.'
      ;;
    3)
      stage 'Core boundary validation' "$SCRIPT_DIR/validate-core-boundaries.sh"
      ;;
    *)
      printf '%s\n' 'Core boundary validation requires MOONCLAW_ROOT, MOONBOOK_ROOT, and MOONTOWN_ROOT to be set together.' >&2
      return 1
      ;;
  esac
}

stage 'MoonBit format check' sh -c 'cd "$1" && moon fmt --check' sh "$REPO_ROOT"
stage 'MoonBit check' sh -c 'cd "$1" && moon check --target all --warn-list +unnecessary_annotation --diagnostic-limit 1000' sh "$REPO_ROOT"
stage 'MoonBit native tests' sh -c 'cd "$1" && moon test --target native --warn-list +unnecessary_annotation --diagnostic-limit 1000' sh "$REPO_ROOT"
stage 'UI check' sh -c 'cd "$1" && moon check --target js --warn-list +unnecessary_annotation --diagnostic-limit 1000' sh "$UI_DIR"
stage 'UI tests' sh -c 'cd "$1" && moon test --target js --warn-list +unnecessary_annotation --diagnostic-limit 1000' sh "$UI_DIR"

if [ "$MODE" = full ]; then
  stage 'UI localization tests' npm --prefix "$UI_DIR" run test:i18n
  stage 'Release artifact verifier tests' node --test "$SCRIPT_DIR/verify_release.test.mjs"
  build_output=$(mktemp -d "${TMPDIR:-/tmp}/moondesk-ui-build.XXXXXX")
  trap 'rm -rf "$build_output"' EXIT HUP INT TERM
  stage 'UI production build' npm --prefix "$UI_DIR" run build -- --outDir "$build_output"
  rm -rf "$build_output"
  trap - EXIT HUP INT TERM
  stage 'Generated-interface verification' verify_generated_interfaces
  run_boundary_validators
  stage 'Whitespace errors' git -C "$REPO_ROOT" diff --check
  stage 'Clean generated tree' verify_clean_tree
fi
