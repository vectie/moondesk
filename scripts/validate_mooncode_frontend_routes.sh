#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
UI_MAIN="${ROOT}/ui/rabbita-desk/main"
LEGACY_HELPER="${UI_MAIN}/mooncode_route_helpers.mbt"

if [[ -e "${LEGACY_HELPER}" ]]; then
  echo "MoonCode frontend route helpers moved to vectie/moondesk/core; do not reintroduce ${LEGACY_HELPER}" >&2
  exit 1
fi

hits="$(
  rg -n '"/api/mooncode|/api/mooncode' "${UI_MAIN}" \
    --glob '*.mbt' \
    --glob '!*_wbtest.mbt' || true
)"

if [[ -n "${hits}" ]]; then
  echo "MoonCode frontend route strings must live in vectie/moondesk/core route helpers" >&2
  echo "${hits}" >&2
  exit 1
fi

echo "MoonCode frontend route ownership validation passed"
