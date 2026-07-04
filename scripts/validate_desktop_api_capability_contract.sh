#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CAPABILITY_HANDLER="${ROOT}/internal/moonwiki/desktop_api_capabilities.mbt"

if ! rg -n '@desk\.desktop_api_capability_contract\(\)\.to_json\(\)' "${CAPABILITY_HANDLER}" >/dev/null; then
  echo "Desktop API capabilities must be served from the core capability contract object" >&2
  exit 1
fi

schema_hits="$(
  rg -n '"component"|"kind"|"version"|"route_contract_endpoint"|"required_endpoints"|"desktop_route_contracts"|"portable_api_[a-z_]*"' "${CAPABILITY_HANDLER}" || true
)"

if [[ -n "${schema_hits}" ]]; then
  echo "Desktop API capability schema fields must live in vectie/moondesk/core, not MoonWiki" >&2
  echo "${schema_hits}" >&2
  exit 1
fi

if ! rg -n 'DesktopApiCapabilities|desktop_api_capability_contract' "${ROOT}/core/desktop_routes.mbt" >/dev/null; then
  echo "Core must own the desktop API capability schema and builder" >&2
  exit 1
fi

echo "Desktop API capability contract validation passed"
