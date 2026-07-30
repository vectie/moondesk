#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
UI_DIR="$REPO_ROOT/ui/rabbita-desk"

VERSION=
NOTES=
OUTPUT=
WORKSPACE=
TEMP_WORKSPACE=
TEMP_UI=

usage() {
  printf '%s\n' \
    "Usage: $0 --version VERSION --notes FILE --out FRESH_DIR [--workspace DIR]" \
    "          [--credentialed]" >&2
}

CREDENTIALED=false
while [ "$#" -gt 0 ]; do
  case "$1" in
    --version|--notes|--out|--workspace)
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
      esac
      ;;
    --credentialed)
      CREDENTIALED=true
      shift
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

if [ "$CREDENTIALED" = true ]; then
  : "${MOONDESK_DEVELOPER_ID_APPLICATION:?preview release: protected Developer ID input is required}"
  : "${MOONDESK_NOTARY_KEYCHAIN_PROFILE:?preview release: protected notary profile input is required}"
  : "${MOONDESK_UPDATE_PRIVATE_KEY_FILE:?preview release: protected update signing key is required}"
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
  TEMP_WORKSPACE=$(mktemp -d "${TMPDIR:?set TMPDIR beneath repository _build or .moonagent}/moondesk-preview-workspace.XXXXXX")
  WORKSPACE=$TEMP_WORKSPACE
  mkdir -p "$WORKSPACE/books"
elif [ ! -d "$WORKSPACE" ]; then
  printf 'preview release: workspace is not a directory: %s\n' "$WORKSPACE" >&2
  exit 66
fi

TEMP_UI=$(mktemp -d "${TMPDIR:?set TMPDIR beneath repository _build or .moonagent}/moondesk-preview-ui.XXXXXX")
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

set -- "$@" --skip-sign --no-dmg

(
  cd "$REPO_ROOT"
  moon run cmd/main -- "$@"
)

[ -d "$OUTPUT" ] || {
  printf '%s\n' 'preview release: release command did not create output' >&2
  exit 67
}
cp "$NOTES" "$OUTPUT/RELEASE_NOTES.md"

if [ "$CREDENTIALED" = true ]; then
  node "$SCRIPT_DIR/phase9_release.mjs" credentialed \
    --app "$OUTPUT/MoonDesk.app" --archive "$OUTPUT/MoonDesk.app.zip" \
    --dmg "$OUTPUT/moondesk-$VERSION-macos-arm64.dmg"
else
  node "$SCRIPT_DIR/verify_release.mjs" --write-checksums "$OUTPUT"
  node "$SCRIPT_DIR/verify_release.mjs" "$OUTPUT"
  node "$SCRIPT_DIR/verify_release.mjs" "$OUTPUT"
fi

node "$SCRIPT_DIR/phase9_release.mjs" identity \
  --root "$OUTPUT" --source-commit "$(git -C "$REPO_ROOT" rev-parse HEAD)"
node "$SCRIPT_DIR/phase9_release.mjs" channel \
  --release-root "$OUTPUT" --channel preview \
  --targets "$REPO_ROOT/config/phase9-supported-targets.json" \
  --out "$OUTPUT/preview-channel.json"
node "$SCRIPT_DIR/phase9_release.mjs" validate-channel \
  "$OUTPUT/preview-channel.json"

if [ "$CREDENTIALED" = true ]; then
  node "$SCRIPT_DIR/phase9_release.mjs" sign-metadata \
    --input "$OUTPUT/preview-channel.json" \
    --out "$OUTPUT/preview-channel.json.signature.json"
fi

printf 'preview release verified: %s\n' "$OUTPUT"
