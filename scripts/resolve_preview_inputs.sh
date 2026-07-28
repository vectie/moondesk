#!/bin/sh
set -eu

EVENT=
TAG_OR_VERSION=
NOTES=
OUTPUT_ROOT=

usage() {
  printf '%s\n' \
    "Usage: $0 --event push|workflow_dispatch --tag-or-version VALUE" \
    "          --notes FILE_OR_EMPTY --output-root DIR" >&2
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --event|--tag-or-version|--notes|--output-root)
      [ "$#" -ge 2 ] || { usage; exit 64; }
      option=$1
      value=$2
      shift 2
      case "$option" in
        --event) EVENT=$value ;;
        --tag-or-version) TAG_OR_VERSION=$value ;;
        --notes) NOTES=$value ;;
        --output-root) OUTPUT_ROOT=$value ;;
      esac
      ;;
    *) usage; exit 64 ;;
  esac
done

[ -n "$EVENT" ] && [ -n "$TAG_OR_VERSION" ] && [ -n "$OUTPUT_ROOT" ] || {
  usage
  exit 64
}

case "$EVENT" in
  push)
    case "$TAG_OR_VERSION" in
      v*) VERSION=${TAG_OR_VERSION#v} ;;
      *)
        printf 'preview inputs: push ref must start with v: %s\n' \
          "$TAG_OR_VERSION" >&2
        exit 65
        ;;
    esac
    ;;
  workflow_dispatch) VERSION=$TAG_OR_VERSION ;;
  *)
    printf 'preview inputs: unsupported event: %s\n' "$EVENT" >&2
    exit 65
    ;;
esac

printf '%s\n' "$VERSION" |
  grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+-preview\.[0-9]+$' || {
    printf 'preview inputs: invalid preview version: %s\n' "$VERSION" >&2
    exit 65
  }

if [ -z "$NOTES" ]; then
  NOTES="docs/releases/$VERSION.md"
fi
case "$NOTES" in
  /*|*".."*)
    printf 'preview inputs: unsafe release-note path: %s\n' "$NOTES" >&2
    exit 66
    ;;
esac
[ -s "$NOTES" ] || {
  printf 'preview inputs: release notes are missing or empty: %s\n' \
    "$NOTES" >&2
  exit 67
}

case "$OUTPUT_ROOT" in
  /*) ;;
  *)
    printf 'preview inputs: output root must be absolute: %s\n' \
      "$OUTPUT_ROOT" >&2
    exit 66
    ;;
esac

printf 'version=%s\n' "$VERSION"
printf 'notes=%s\n' "$NOTES"
printf 'output=%s/moondesk-%s\n' "${OUTPUT_ROOT%/}" "$VERSION"
