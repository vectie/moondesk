#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ROUTES="${ROOT}/internal/mooncode/route_contracts.mbt"
ENDPOINTS="${ROOT}/internal/mooncode/moonclaw_endpoints.mbt"
MOONCLAW_CAPABILITIES="${ROOT}/internal/mooncode/moonclaw_capabilities.mbt"
CORE="${ROOT}/mooncode/core/protocol.mbt"
CORE_ENDPOINTS="${ROOT}/mooncode/core/native_endpoints.mbt"

if rg -n '"/v1/code/' "${ROUTES}" >/tmp/moondesk-mooncode-native-endpoints.$$; then
  echo "MoonCode native /v1/code endpoints must be owned by mooncode/core, not mirrored in internal/mooncode route contracts" >&2
  cat /tmp/moondesk-mooncode-native-endpoints.$$ >&2
  rm -f /tmp/moondesk-mooncode-native-endpoints.$$
  exit 1
fi
rm -f /tmp/moondesk-mooncode-native-endpoints.$$

if rg -n 'native_code_.*endpoint\(' "${ROUTES}" >/tmp/moondesk-mooncode-native-helper.$$; then
  echo "MoonCode native endpoints must not be rewrapped by internal native_code_* helper functions" >&2
  cat /tmp/moondesk-mooncode-native-helper.$$ >&2
  rm -f /tmp/moondesk-mooncode-native-helper.$$
  exit 1
fi
rm -f /tmp/moondesk-mooncode-native-helper.$$

if ! rg -n 'NativeCapabilityEndpoints|native_capability_endpoints' "${CORE}" >/dev/null; then
  echo "mooncode/core must expose the typed native capability endpoint contract" >&2
  exit 1
fi

if ! rg -n 'NativeCapabilityEndpoints|native_session_commands_endpoint|native_stream_endpoint' "${CORE_ENDPOINTS}" >/dev/null; then
  echo "mooncode/core must own typed native endpoint templates and concrete native endpoint builders" >&2
  exit 1
fi

if ! rg -n 'native_projection_required_endpoints\(\) -> Array\[String\]' "${ROUTES}" >/dev/null ||
   ! rg -n 'native_capability_required_endpoints\(\)' "${ROUTES}" >/dev/null; then
  echo "internal/mooncode native projection endpoints must derive from the core native capability contract" >&2
  exit 1
fi

if rg -n '"/v1/code/(capabilities|sessions)' "${ENDPOINTS}" "${MOONCLAW_CAPABILITIES}" >/tmp/moondesk-mooncode-native-builder.$$; then
  echo "Concrete MoonClaw /v1/code endpoint builders and native target descriptions must derive from mooncode/core" >&2
  cat /tmp/moondesk-mooncode-native-builder.$$ >&2
  rm -f /tmp/moondesk-mooncode-native-builder.$$
  exit 1
fi
rm -f /tmp/moondesk-mooncode-native-builder.$$

if ! rg -n '@mooncode_core\.native_session_commands_endpoint|@mooncode_core\.native_stream_endpoint' "${ENDPOINTS}" >/dev/null; then
  echo "internal/mooncode MoonClaw endpoint wrappers must delegate to mooncode/core builders" >&2
  exit 1
fi

if ! rg -n 'native_capability_target_description\(\)' "${MOONCLAW_CAPABILITIES}" >/dev/null; then
  echo "MoonClaw runtime contract native target description must come from mooncode/core" >&2
  exit 1
fi

echo "MoonCode native endpoint contract validation passed"
