#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
UI_MAIN="${ROOT}/ui/rabbita-desk/main"

hits="$(
  rg -n '"/api/mooncode|/api/mooncode' "${UI_MAIN}" \
    --glob '*.mbt' \
    --glob '!mooncode_route_helpers.mbt' \
    --glob '!*_wbtest.mbt' || true
)"

if [[ -n "${hits}" ]]; then
  echo "MoonCode frontend route strings must live in mooncode_route_helpers.mbt" >&2
  echo "${hits}" >&2
  exit 1
fi

echo "MoonCode frontend route ownership validation passed"
