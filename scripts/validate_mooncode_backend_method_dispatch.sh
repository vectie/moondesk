#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ROUTER="${ROOT}/internal/moonwiki/api_mooncode_router.mbt"

if rg -n 'is_read_method\(method_\)|method_ is Post|send_method_not_allowed\(conn, method_\)' "${ROUTER}"; then
  echo "MoonCode router must use contract-backed method dispatch helpers" >&2
  exit 1
fi

if ! rg -q 'mooncode_route_accepts_read' "${ROUTER}"; then
  echo "MoonCode router is missing contract-backed read dispatch" >&2
  exit 1
fi

if ! rg -q 'mooncode_route_accepts_post' "${ROUTER}"; then
  echo "MoonCode router is missing contract-backed post dispatch" >&2
  exit 1
fi

if ! rg -q 'send_mooncode_method_not_allowed' "${ROUTER}"; then
  echo "MoonCode router is missing contract-backed 405 responses" >&2
  exit 1
fi

echo "MoonCode backend method dispatch ownership validation passed"
