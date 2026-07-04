#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CORE_FILE="${ROOT}/mooncode/core/native_event_projection.mbt"
IMPLEMENTATION_FILES=(
  "${ROOT}/internal/mooncode/moonclaw_mappings.mbt"
  "${ROOT}/internal/mooncode/moonclaw_capabilities.mbt"
  "${ROOT}/internal/mooncode/native_runtime_contract.mbt"
)

required_core_symbols=(
  "native_event_projection_contract_id"
  "native_event_projection_contract_kind"
  "native_event_projection_report_kind"
  "moonclaw_event_mapping_json"
  "native_event_projection_command_scope_keys"
  "native_event_projection_diagnostic_sources"
  "native_event_projection_diagnostic_titles"
  "native_event_has_command_scope"
  "native_event_is_diagnostic_only"
  "native_event_requires_command_scope"
  "native_event_is_transcript"
  "native_event_is_progress"
  "native_event_projection_problem"
  "native_event_projection_report"
  "native_events_for_canonical_projection"
  "native_event_projection_contract_json"
)

for symbol in "${required_core_symbols[@]}"; do
  if ! rg -n "pub fn ${symbol}\\(" "${CORE_FILE}" >/dev/null; then
    echo "mooncode/core must own public ${symbol}()." >&2
    exit 1
  fi
done

stale_file="/tmp/moondesk-mooncode-native-event-projection-stale.$$"
if rg -n \
  '"AssistantMessageDelta":|"PreToolCall":|"PostToolCall":|"Cancelled":|"Failed":|native_runtime_event_has_command_scope|native_runtime_event_is_diagnostic_only|native_runtime_event_requires_command_scope|native_runtime_event_is_transcript|native_runtime_event_is_progress|user-facing-native-event-without-command-scope' \
  "${IMPLEMENTATION_FILES[@]}" \
  >"${stale_file}"; then
  echo "MoonCode native event projection ownership must come from mooncode/core, not duplicated implementation policy." >&2
  cat "${stale_file}" >&2
  rm -f "${stale_file}"
  exit 1
fi
rm -f "${stale_file}"

if ! rg -n '@mooncode_core\.moonclaw_event_mapping_json\(\)' "${ROOT}/internal/mooncode/moonclaw_mappings.mbt" >/dev/null; then
  echo "MoonClaw event mapping facade must delegate to mooncode/core." >&2
  exit 1
fi

if ! rg -n '@mooncode_core\.moonclaw_event_mapping_json\(\)' "${ROOT}/internal/mooncode/moonclaw_capabilities.mbt" >/dev/null; then
  echo "MoonClaw runtime contract must publish event mapping from mooncode/core." >&2
  exit 1
fi

if ! rg -n '@mooncode_core\.native_event_projection_report\(' "${ROOT}/internal/mooncode/native_runtime_contract.mbt" >/dev/null; then
  echo "native runtime event contract report must delegate to mooncode/core." >&2
  exit 1
fi

if ! rg -n '@mooncode_core\.native_events_for_canonical_projection\(' "${ROOT}/internal/mooncode/native_runtime_contract.mbt" >/dev/null; then
  echo "native runtime projection filter must delegate to mooncode/core." >&2
  exit 1
fi

if ! rg -n '"native_event_projection_contract": native_event_projection_contract_json\(\)' "${ROOT}/mooncode/core/protocol.mbt" >/dev/null; then
  echo "native capability surface must embed native_event_projection_contract_json()." >&2
  exit 1
fi

if ! rg -n 'native_event_projection_contract_id\(\)' "${ROOT}/mooncode/core/protocol.mbt" >/dev/null; then
  echo "native capability fingerprint must include native_event_projection_contract_id()." >&2
  exit 1
fi

echo "MoonCode native event projection contract validation passed"
