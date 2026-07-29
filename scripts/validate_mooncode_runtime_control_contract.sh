#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CORE_FILE="${ROOT}/mooncode/core/runtime_control.mbt"
CORE_INTERFACE="${ROOT}/mooncode/core/pkg.generated.mbti"
CONSUMER_FILES=(
  "${ROOT}/internal/mooncode/adapter_capabilities.mbt"
  "${ROOT}/internal/mooncode/adapter_commands.mbt"
  "${ROOT}/internal/mooncode/adapter_json.mbt"
  "${ROOT}/internal/mooncode/adapter_protocol.mbt"
  "${ROOT}/internal/mooncode/adapter_sessions.mbt"
)
BEHAVIOR_FILES=(
  "${ROOT}/internal/mooncode/adapter_capabilities_wbtest.mbt"
  "${ROOT}/internal/mooncode/adapter_wbtest.mbt"
)

required_core_symbols=(runtime_control_contract_id runtime_control_contract_json runtime_control_state_kind runtime_control_effects runtime_control_effect_allows_turn runtime_control_settlement_required runtime_control_settlement_events runtime_control_action_starts_turn runtime_control_status_is_active runtime_control_status_is_blocked)

for symbol in "${required_core_symbols[@]}"; do
  if rg -n "\\b${symbol}\\b" "${CORE_INTERFACE}" >/dev/null; then echo "mooncode/core public interface must exclude raw/helper ${symbol}()." >&2; exit 1; fi
  if rg -n "@mooncode_core\\.${symbol}\\b" "${CONSUMER_FILES[@]}" >/dev/null; then echo "MoonCode adapters must not call private raw/helper ${symbol}()." >&2; exit 1; fi
done

if rg -n \
  '"mooncode-runtime-control-contract"|"mooncode-runtime-control-state"|"native-runtime-scheduler-boundary"|"start-turn"|"active-turn"|"queue-turn"|"deliver-steer"|"queue-steer"|"defer-steer"|"cancel-active"|"withdraw-pending"|"drop-cancel"|"record-note"|"already-completed"|"wait-for-proof"|"mooncode-conversation-ownership-contract"|"visible_owner_rule"|"unowned_event_rule"|"control_rule"|"abort_rule"' \
  "${CONSUMER_FILES[@]}"; then
  echo "MoonCode runtime control ownership must come from mooncode/core, not duplicated adapter literals." >&2
  exit 1
fi

for file in "${BEHAVIOR_FILES[@]}"; do [[ -f "${file}" ]] || { echo "missing adapter behavior proof: ${file}" >&2; exit 1; }; done

if ! rg -n '"runtime_control_contract": runtime_control_contract_json\(\)' "${ROOT}/mooncode/core/protocol.mbt" >/dev/null; then
  echo "native capability surface must embed runtime_control_contract_json()." >&2
  exit 1
fi

echo "MoonCode runtime control contract validation passed"
