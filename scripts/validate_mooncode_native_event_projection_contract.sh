#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CORE_FILE="${ROOT}/mooncode/core/native_event_projection.mbt"
CORE_INTERFACE="${ROOT}/mooncode/core/pkg.generated.mbti"
CONSUMER_FILES=("${ROOT}/internal/mooncode/adapter_capabilities.mbt" "${ROOT}/internal/mooncode/adapter_commands.mbt" "${ROOT}/internal/mooncode/adapter_json.mbt" "${ROOT}/internal/mooncode/adapter_protocol.mbt" "${ROOT}/internal/mooncode/adapter_sessions.mbt")
BEHAVIOR_FILES=("${ROOT}/internal/mooncode/adapter_capabilities_wbtest.mbt" "${ROOT}/internal/mooncode/adapter_wbtest.mbt")
required_core_symbols=(native_event_projection_contract_id native_event_projection_contract_kind native_event_projection_report_kind moonclaw_event_mapping_json native_event_projection_command_scope_keys native_event_projection_diagnostic_sources native_event_projection_diagnostic_titles native_event_has_command_scope native_event_is_diagnostic_only native_event_requires_command_scope native_event_is_transcript native_event_is_progress native_event_projection_problem native_event_projection_report native_events_for_canonical_projection native_event_projection_contract_json)
for symbol in "${required_core_symbols[@]}"; do
  rg -n "fn ${symbol}\\(" "${CORE_FILE}" >/dev/null || { echo "mooncode/core must own ${symbol}()." >&2; exit 1; }
  ! rg -n "\\b${symbol}\\b" "${CORE_INTERFACE}" >/dev/null || { echo "mooncode/core public interface must exclude raw/helper ${symbol}()." >&2; exit 1; }
  ! rg -n "@mooncode_core\\.${symbol}\\b" "${CONSUMER_FILES[@]}" >/dev/null || { echo "MoonCode adapters must not call private raw/helper ${symbol}()." >&2; exit 1; }
done
if rg -n '"AssistantMessageDelta":|"PreToolCall":|"PostToolCall":|"Cancelled":|"Failed":|native_runtime_event_has_command_scope|native_runtime_event_is_diagnostic_only|native_runtime_event_requires_command_scope|native_runtime_event_is_transcript|native_runtime_event_is_progress|user-facing-native-event-without-command-scope' "${CONSUMER_FILES[@]}"; then
  echo "MoonCode native event projection ownership must come from mooncode/core, not duplicated adapter policy." >&2; exit 1
fi
for file in "${BEHAVIOR_FILES[@]}"; do [[ -f "${file}" ]] || { echo "missing adapter behavior proof: ${file}" >&2; exit 1; }; done
rg -n '"native_event_projection_contract": native_event_projection_contract_json\(\)' "${ROOT}/mooncode/core/protocol.mbt" >/dev/null || { echo "native capability surface must embed native_event_projection_contract_json()." >&2; exit 1; }
echo "MoonCode native event projection contract validation passed"
