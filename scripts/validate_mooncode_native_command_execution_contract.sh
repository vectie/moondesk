#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CORE_FILE="${ROOT}/mooncode/core/native_command_execution.mbt"
INTERNAL_FILES=(
  "${ROOT}/internal/mooncode/native_command_action_metadata.mbt"
  "${ROOT}/internal/mooncode/native_command_contracts.mbt"
  "${ROOT}/internal/mooncode/native_command_result_contracts.mbt"
  "${ROOT}/internal/mooncode/native_command_tool_policies.mbt"
  "${ROOT}/internal/mooncode/command_protocol.mbt"
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
  if ! rg -n "pub fn ${symbol}\\(" "${CORE_FILE}" >/dev/null; then
    echo "mooncode/core must own public ${symbol}()." >&2
    exit 1
  fi
done

stale_file="/tmp/moondesk-mooncode-native-command-stale.$$"
if rg -n \
  '"mooncode-native-command-execution-plan"|"mooncode-native-tool-contract"|"mooncode-native-result-contract"|"eval_report\.manifest"|"package\.manifest"|"package\.index"|"Claim the runtime command before execution"|"runtime must reject unknown tools before execution"|"accept argv arrays instead of raw shell strings"|native_command_tool_policy_entry\(|"run tool_harness eval fixtures"|POST /api/mooncode/sessions/<session-id>/runtime-events|POST /api/mooncode/sessions/<session-id>/runtime-claim' \
  "${INTERNAL_FILES[@]}" \
  >"${stale_file}"; then
  echo "MoonCode native command execution/result policy must come from mooncode/core, not duplicated internal tables." >&2
  cat "${stale_file}" >&2
  rm -f "${stale_file}"
  exit 1
fi
rm -f "${stale_file}"

if ! rg -n '@mooncode_core\.native_command_tool_sequence\(' "${ROOT}/internal/mooncode/native_command_action_metadata.mbt" >/dev/null; then
  echo "native command tool sequence must delegate to mooncode/core." >&2
  exit 1
fi

if ! rg -n '@mooncode_core\.native_command_expected_events\(' "${ROOT}/internal/mooncode/native_command_action_metadata.mbt" >/dev/null; then
  echo "native command expected events must delegate to mooncode/core." >&2
  exit 1
fi

if ! rg -n '@mooncode_core\.native_command_required_outputs\(' "${ROOT}/internal/mooncode/native_command_action_metadata.mbt" >/dev/null; then
  echo "native command required outputs must delegate to mooncode/core." >&2
  exit 1
fi

if ! rg -n '@mooncode_core\.native_command_recommended_commands\(' "${ROOT}/internal/mooncode/native_command_action_metadata.mbt" >/dev/null; then
  echo "native command recommended commands must delegate to mooncode/core." >&2
  exit 1
fi

if ! rg -n '@mooncode_core\.native_command_execution_plan\(' "${ROOT}/internal/mooncode/native_command_contracts.mbt" >/dev/null; then
  echo "native command execution plan must delegate to mooncode/core." >&2
  exit 1
fi

if ! rg -n '@mooncode_core\.native_command_tool_contract_for_command\(' "${ROOT}/internal/mooncode/native_command_contracts.mbt" >/dev/null; then
  echo "native command tool contract must delegate to mooncode/core." >&2
  exit 1
fi

if ! rg -n '@mooncode_core\.native_command_result_contract\(' "${ROOT}/internal/mooncode/native_command_result_contracts.mbt" >/dev/null; then
  echo "native command result contract must delegate to mooncode/core." >&2
  exit 1
fi

if ! rg -n '@mooncode_core\.native_command_execution_checklist\(' "${ROOT}/internal/mooncode/native_command_result_contracts.mbt" >/dev/null; then
  echo "native command execution checklist must delegate to mooncode/core." >&2
  exit 1
fi

if ! rg -n '@mooncode_core\.native_command_tool_policies\(' "${ROOT}/internal/mooncode/native_command_tool_policies.mbt" >/dev/null; then
  echo "native command tool policies must delegate to mooncode/core." >&2
  exit 1
fi

if ! rg -n '@mooncode_core\.native_command_tool_policy\(' "${ROOT}/internal/mooncode/native_command_tool_policies.mbt" >/dev/null; then
  echo "native command tool policy rows must delegate to mooncode/core." >&2
  exit 1
fi

if ! rg -n '@mooncode_core\.native_command_allowed_tool_sequence\(' "${ROOT}/internal/mooncode/command_protocol.mbt" >/dev/null; then
  echo "web-search tool expansion must delegate to mooncode/core native command policy." >&2
  exit 1
fi

if ! rg -n '"native_command_execution_contract": native_command_execution_contract_json\(\)' "${ROOT}/mooncode/core/protocol.mbt" >/dev/null; then
  echo "native capability surface must embed native_command_execution_contract_json()." >&2
  exit 1
fi

echo "MoonCode native command execution contract validation passed"
