#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CORE_FILE="${ROOT}/mooncode/core/native_command_execution.mbt"
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
  "native_command_contract_id"
  "native_command_execution_plan_kind"
  "native_command_tool_contract_kind"
  "native_command_result_contract_kind"
  "native_command_tool_sequence"
  "native_command_allowed_tool_sequence"
  "native_command_expected_events"
  "native_command_required_outputs"
  "native_command_recommended_commands"
  "native_command_default_package_kind"
  "native_command_tool_policies"
  "native_command_tool_policy"
  "native_command_execution_plan"
  "native_command_tool_contract"
  "native_command_tool_contract_for_command"
  "native_command_result_contract"
  "native_command_execution_checklist"
  "native_command_execution_contract_json"
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
  'mooncode\.native_command_(execution_plan|tool_contract|result_contract)\.v1|mooncode\.native_command_execution\.v1|"checkpoint", "apply_patch", "shell", "moon_check", "finish"' \
  "${CONSUMER_FILES[@]}"; then
  echo "MoonCode native command execution ownership must come from mooncode/core, not duplicated adapter literals." >&2
  exit 1
fi

for file in "${BEHAVIOR_FILES[@]}"; do
  [[ -f "${file}" ]] || { echo "missing adapter behavior proof: ${file}" >&2; exit 1; }
done

if ! rg -n '"native_command_execution_contract": native_command_execution_contract_json\(\)' "${ROOT}/mooncode/core/protocol.mbt" >/dev/null; then
  echo "native capability surface must embed native_command_execution_contract_json()." >&2
  exit 1
fi

echo "MoonCode native command execution contract validation passed"
