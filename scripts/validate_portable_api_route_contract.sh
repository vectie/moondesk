#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if rg -n 'app_tool_portable_api_snapshot_routes' "${ROOT}/internal/moonwiki" --glob '*.mbt' >/tmp/moondesk-portable-api-snapshot-routes.$$; then
  echo "App-tool portable API routes must come from vectie/moondesk/core, not a MoonWiki-local route list" >&2
  cat /tmp/moondesk-portable-api-snapshot-routes.$$ >&2
  rm -f /tmp/moondesk-portable-api-snapshot-routes.$$
  exit 1
fi
rm -f /tmp/moondesk-portable-api-snapshot-routes.$$

if ! rg -n '@desk\.desktop_portable_api_route_supported' "${ROOT}/internal/moonwiki/app_tool_portable_api_scan.mbt" >/dev/null; then
  echo "App-tool portable unsupported-route detection must delegate to the core desktop portable API contract" >&2
  exit 1
fi

if ! rg -n '@desk\.desktop_portable_api_snapshot_routes' "${ROOT}/internal/moonwiki/app_tool_portable_export.mbt" "${ROOT}/internal/moonwiki/app_tool_portable_api_snapshot.mbt" >/dev/null; then
  echo "App-tool portable snapshot route publication must use the core desktop portable API contract" >&2
  exit 1
fi

if ! rg -n 'portable_api_supported_route_patterns: desktop_portable_api_supported_route_patterns\(\)' "${ROOT}/core/desktop_routes.mbt" >/dev/null; then
  echo "Core desktop API capabilities must publish the portable API route contract" >&2
  exit 1
fi

if ! rg -n 'portable_api_supported_route_patterns' "${ROOT}/scripts/desktop_api_http_method_contract_smoke.mjs" >/dev/null; then
  echo "Live desktop API contract smoke must assert portable API route publication" >&2
  exit 1
fi

echo "Portable API route contract validation passed"
