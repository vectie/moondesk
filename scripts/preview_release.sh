#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
UI_DIR="$REPO_ROOT/ui/rabbita-desk"

VERSION=
NOTES=
OUTPUT=
WORKSPACE=
NOTARY_PROFILE=
SIGN_IDENTITY=
TEMP_WORKSPACE=
TEMP_UI=

usage() {
  printf '%s\n' \
    "Usage: $0 --version VERSION --notes FILE --out FRESH_DIR [--workspace DIR]" \
    "          [--notary-profile PROFILE --sign-identity IDENTITY]" >&2
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --version|--notes|--out|--workspace|--notary-profile|--sign-identity)
      [ "$#" -ge 2 ] || {
        usage
        exit 64
      }
      option=$1
      value=$2
      shift 2
      case "$option" in
        --version) VERSION=$value ;;
        --notes) NOTES=$value ;;
        --out) OUTPUT=$value ;;
        --workspace) WORKSPACE=$value ;;
        --notary-profile) NOTARY_PROFILE=$value ;;
        --sign-identity) SIGN_IDENTITY=$value ;;
      esac
      ;;
    *)
      usage
      exit 64
      ;;
  esac
done

[ -n "$VERSION" ] && [ -n "$NOTES" ] && [ -n "$OUTPUT" ] || {
  usage
  exit 64
}

printf '%s\n' "$VERSION" |
  grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z][0-9A-Za-z.-]*)?$' || {
    printf 'preview release: invalid version: %s\n' "$VERSION" >&2
    exit 65
  }

[ -f "$NOTES" ] && [ -s "$NOTES" ] || {
  printf 'preview release: release notes are missing or empty: %s\n' "$NOTES" >&2
  exit 66
}

case "$OUTPUT" in
  /*) ;;
  *)
    printf '%s\n' 'preview release: --out must be an absolute path' >&2
    exit 66
    ;;
esac

if [ -e "$OUTPUT" ]; then
  printf 'preview release: output already exists; refusing overwrite: %s\n' \
    "$OUTPUT" >&2
  exit 69
fi

if [ -n "$NOTARY_PROFILE" ] || [ -n "$SIGN_IDENTITY" ]; then
  [ -n "$NOTARY_PROFILE" ] && [ -n "$SIGN_IDENTITY" ] || {
    printf '%s\n' \
      'preview release: notarization requires both profile and signing identity' >&2
    exit 66
  }
fi

[ "$(uname -s)" = Darwin ] || {
  printf '%s\n' 'preview release: native preview packaging requires macOS' >&2
  exit 66
}

cleanup() {
  if [ -n "$TEMP_WORKSPACE" ] && [ -d "$TEMP_WORKSPACE" ]; then
    rm -rf -- "$TEMP_WORKSPACE"
  fi
  if [ -n "$TEMP_UI" ] && [ -d "$TEMP_UI" ]; then
    rm -rf -- "$TEMP_UI"
  fi
}
trap cleanup EXIT HUP INT TERM

if [ -z "$WORKSPACE" ]; then
  TEMP_WORKSPACE=$(mktemp -d "${TMPDIR:-/tmp}/moondesk-preview-workspace.XXXXXX")
  WORKSPACE=$TEMP_WORKSPACE
  mkdir -p "$WORKSPACE/books"
elif [ ! -d "$WORKSPACE" ]; then
  printf 'preview release: workspace is not a directory: %s\n' "$WORKSPACE" >&2
  exit 66
fi

TEMP_UI=$(mktemp -d "${TMPDIR:-/tmp}/moondesk-preview-ui.XXXXXX")
mkdir -p "$(dirname -- "$OUTPUT")"

npm --prefix "$UI_DIR" run build -- \
  --outDir "$TEMP_UI" \
  --emptyOutDir

set -- \
  release "$WORKSPACE" \
  --ui "$TEMP_UI" \
  --out "$OUTPUT" \
  --version "$VERSION" \
  --channel preview

if [ -n "$NOTARY_PROFILE" ]; then
  set -- "$@" \
    --sign-identity "$SIGN_IDENTITY" \
    --notary-profile "$NOTARY_PROFILE"
else
  set -- "$@" --skip-sign
fi

(
  cd "$REPO_ROOT"
  moon run cmd/main -- "$@"
)

[ -d "$OUTPUT" ] || {
  printf '%s\n' 'preview release: release command did not create output' >&2
  exit 67
}
cp "$NOTES" "$OUTPUT/RELEASE_NOTES.md"
node "$SCRIPT_DIR/verify_release.mjs" --write-checksums "$OUTPUT"
node "$SCRIPT_DIR/verify_release.mjs" "$OUTPUT"
node "$SCRIPT_DIR/verify_release.mjs" "$OUTPUT"

printf 'preview release verified: %s\n' "$OUTPUT"
