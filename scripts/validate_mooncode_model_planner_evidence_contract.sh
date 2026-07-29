#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CORE_FILE="${ROOT}/mooncode/core/model_planner_evidence.mbt"
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
  if ! rg -n "fn ${symbol}\\(" "${CORE_FILE}" >/dev/null; then
    echo "mooncode/core must own ${symbol}()." >&2
    exit 1
  fi
  if rg -n "\\b${symbol}\\b" "${CORE_INTERFACE}" >/dev/null; then
    echo "mooncode/core public interface must exclude raw/helper ${symbol}()." >&2
    exit 1
  fi
  if rg -n "@mooncode_core\\.${symbol}\\b" "${CONSUMER_FILES[@]}" >/dev/null; then
    echo "MoonCode adapters must not call private raw/helper ${symbol}()." >&2
    exit 1
  fi
done

if rg -n \
  'runtime\.planner_started|runtime\.planner_selected|model-tool-calls|missing-model-planner-evidence-after-turn-start|planner-evidence-without-model-command|"pending" =>|"running" \| "service-started"|return "contract-failed"|return "planner-failed"|return "satisfied"|return "service-started"|action == "prompt" \|\| action == "steer" \|\| action == "package"' \
  "${CONSUMER_FILES[@]}"; then
  echo "MoonCode model-planner evidence ownership must come from mooncode/core, not duplicated adapter policy." >&2
  exit 1
fi

for file in "${BEHAVIOR_FILES[@]}"; do
  [[ -f "${file}" ]] || { echo "missing adapter behavior proof: ${file}" >&2; exit 1; }
done
