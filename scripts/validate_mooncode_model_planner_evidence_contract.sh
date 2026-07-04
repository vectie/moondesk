#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CORE_FILE="${ROOT}/mooncode/core/model_planner_evidence.mbt"
IMPLEMENTATION_FILES=(
  "${ROOT}/internal/mooncode/model_planner_evidence.mbt"
  "${ROOT}/internal/mooncode/runtime_protocol_contract.mbt"
  "${ROOT}/internal/mooncode/runtime_handoff.mbt"
)

required_core_symbols=(
  "model_planner_evidence_contract_id"
  "model_planner_evidence_contract_kind"
  "model_planner_evidence_report_kind"
  "model_planner_mode_model_tool_calls"
  "model_planner_status_pending"
  "model_planner_status_service_started"
  "model_planner_status_running"
  "model_planner_status_satisfied"
  "model_planner_status_planner_failed"
  "model_planner_status_contract_failed"
  "model_planner_status_no_model_planned_commands"
  "model_planner_missing_evidence_reason"
  "model_planner_stray_evidence_reason"
  "model_planner_command_actions"
  "model_planner_command_action_is_supported"
  "model_planner_command_event_kinds"
  "model_planner_command_event_kind_is_supported"
  "model_planner_planner_event_kinds"
  "model_planner_terminal_event_kinds"
  "model_planner_event_is_planner_evidence"
  "model_planner_status_is_running"
  "model_planner_status_is_contract_failure"
  "model_planner_evidence_contract_json"
)

for symbol in "${required_core_symbols[@]}"; do
  if ! rg -n "pub fn ${symbol}\\(" "${CORE_FILE}" >/dev/null; then
    echo "mooncode/core must own public ${symbol}()." >&2
    exit 1
  fi
done

stale_file="/tmp/moondesk-mooncode-model-planner-evidence-stale.$$"
if rg -n \
  'runtime\.planner_started|runtime\.planner_selected|model-tool-calls|missing-model-planner-evidence-after-turn-start|planner-evidence-without-model-command|"pending" =>|"running" \| "service-started"|return "contract-failed"|return "planner-failed"|return "satisfied"|return "service-started"|action == "prompt" \|\| action == "steer" \|\| action == "package"' \
  "${IMPLEMENTATION_FILES[@]}" \
  >"${stale_file}"; then
  echo "MoonCode model-planner evidence ownership must come from mooncode/core, not duplicated implementation policy." >&2
  cat "${stale_file}" >&2
  rm -f "${stale_file}"
  exit 1
fi
rm -f "${stale_file}"

if ! rg -n '@mooncode_core\.model_planner_evidence_contract_json\(\)' "${ROOT}/internal/mooncode/model_planner_evidence.mbt" >/dev/null; then
  echo "internal model planner contract JSON must delegate to mooncode/core." >&2
  exit 1
fi

if ! rg -n '@mooncode_core\.model_planner_command_event_kind_is_supported\(' "${ROOT}/internal/mooncode/model_planner_evidence.mbt" >/dev/null; then
  echo "model-planned command kind policy must delegate to mooncode/core." >&2
  exit 1
fi

if ! rg -n '@mooncode_core\.model_planner_event_is_planner_evidence\(' "${ROOT}/internal/mooncode/model_planner_evidence.mbt" >/dev/null; then
  echo "planner evidence event policy must delegate to mooncode/core." >&2
  exit 1
fi

if ! rg -n '@mooncode_core\.model_planner_command_action_is_supported\(' "${ROOT}/internal/mooncode/model_planner_evidence.mbt" >/dev/null; then
  echo "model-planned command action policy must delegate to mooncode/core." >&2
  exit 1
fi

if ! rg -n '"model_planner_evidence_contract": model_planner_evidence_contract_json\(\)' "${ROOT}/internal/mooncode/runtime_protocol_contract.mbt" >/dev/null; then
  echo "runtime protocol contract must expose model_planner_evidence_contract_json()." >&2
  exit 1
fi

if ! rg -n '"model_planner_evidence_contract": model_planner_evidence_contract_json\(\)' "${ROOT}/internal/mooncode/runtime_handoff.mbt" >/dev/null; then
  echo "runtime handoff must expose model_planner_evidence_contract_json()." >&2
  exit 1
fi

if ! rg -n '"model_planner_evidence_contract": model_planner_evidence_contract_json\(\)' "${ROOT}/mooncode/core/protocol.mbt" >/dev/null; then
  echo "native capability surface must embed model_planner_evidence_contract_json()." >&2
  exit 1
fi

if ! rg -n 'model_planner_evidence_contract_id\(\)' "${ROOT}/mooncode/core/protocol.mbt" >/dev/null; then
  echo "native capability fingerprint must include model_planner_evidence_contract_id()." >&2
  exit 1
fi

echo "MoonCode model-planner evidence contract validation passed"
