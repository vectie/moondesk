#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROTOCOL_ADAPTER="${ROOT}/internal/mooncode/adapter_protocol.mbt"
CAPABILITY_ADAPTER="${ROOT}/internal/mooncode/adapter_capabilities.mbt"
CORE="${ROOT}/mooncode/core/protocol.mbt"
CORE_ENDPOINTS="${ROOT}/mooncode/core/native_endpoints.mbt"

if rg -n '"/v1/code/' "${PROTOCOL_ADAPTER}"; then
  echo "MoonCode native /v1/code endpoints must be owned by mooncode/core, not mirrored in internal/mooncode adapter protocol" >&2
  exit 1
fi

if ! rg -n 'NativeCapabilityEndpoints|native_capability_endpoints' "${CORE}" "${CORE_ENDPOINTS}" >/dev/null; then
  echo "mooncode/core must expose the typed native capability endpoint contract" >&2
  exit 1
fi

if ! rg -n 'NativeCapabilityEndpoints|native_session_commands_endpoint|native_stream_endpoint' "${CORE_ENDPOINTS}" >/dev/null; then
  echo "mooncode/core must own typed native endpoint templates and concrete native endpoint builders" >&2
  exit 1
fi

if ! rg -n 'native_capability_required_endpoints\(\)' "${CORE}" >/dev/null; then
  echo "mooncode/core must derive required native endpoints from the typed capability contract" >&2
  exit 1
fi

if ! rg -n 'adapter_surface_strings\(surface, "required_endpoints"\)' "${CAPABILITY_ADAPTER}" >/dev/null ||
   ! rg -n 'adapter_surface_endpoint\(surface,' "${CAPABILITY_ADAPTER}" >/dev/null; then
  echo "internal/mooncode native projection endpoints must derive from the core capability surface" >&2
  exit 1
fi

echo "MoonCode native endpoint contract validation passed"
