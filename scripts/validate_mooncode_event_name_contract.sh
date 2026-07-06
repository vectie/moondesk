#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CORE_FILE="${ROOT}/mooncode/core/event_names.mbt"
IMPLEMENTATION_FILES=(
  "${ROOT}/internal/mooncode/runtime_protocol_contract.mbt"
  "${ROOT}/internal/mooncode/capabilities_runtime_contract.mbt"
  "${ROOT}/internal/mooncode/capabilities.mbt"
  "${ROOT}/internal/mooncode/native_command_action_metadata.mbt"
  "${ROOT}/internal/mooncode/native_runtime_contract.mbt"
  "${ROOT}/internal/mooncode/conversation_projection.mbt"
  "${ROOT}/internal/mooncode/runtime_event_projection.mbt"
  "${ROOT}/internal/mooncode/event_log.mbt"
)

required_core_symbols=(
  "runtime_event_name_contract_id"
  "runtime_event_names"
  "runtime_command_output_event_names"
  "runtime_failure_event_names"
  "runtime_diagnostic_event_names"
  "runtime_event_name_is_supported"
  "runtime_failure_event_name_is_supported"
  "runtime_diagnostic_event_name_is_supported"
  "runtime_event_name_contract_json"
)

for symbol in "${required_core_symbols[@]}"; do
  if ! rg -n "pub fn ${symbol}\\(" "${CORE_FILE}" >/dev/null; then
    echo "mooncode/core must own public ${symbol}()." >&2
    exit 1
  fi
done

for symbol in assistant_delta reasoning_delta assistant_message runtime_update tool_call tool_result test_result package_verified runtime_finished runtime_aborted command_error turn_failed max_steps_exhausted; do
  if ! rg -n "pub fn runtime_event_${symbol}\\(" "${CORE_FILE}" >/dev/null; then
    echo "mooncode/core must own runtime_event_${symbol}()." >&2
    exit 1
  fi
done

stale_file="/tmp/moondesk-mooncode-event-names-stale.$$"
if rg -n \
  '"runtime_step", "assistant_delta"|"assistant_delta", "reasoning_delta"|"tool_call", "tool_result", "test_result", "runtime_finished"|"runtime_update", "runtime_finished"|"accepted_events": \[|"output_events": \[' \
  "${IMPLEMENTATION_FILES[@]}" \
  >"${stale_file}"; then
  echo "MoonCode runtime event-name ownership must come from mooncode/core, not duplicated implementation lists." >&2
  cat "${stale_file}" >&2
  rm -f "${stale_file}"
  exit 1
fi
rm -f "${stale_file}"

if ! rg -n '"accepted_events": runtime_event_names\(\)' "${ROOT}/internal/mooncode/runtime_protocol_contract.mbt" >/dev/null; then
  echo "runtime protocol contract must publish accepted_events from runtime_event_names()." >&2
  exit 1
fi

if ! rg -n '"event_name_contract": runtime_event_name_contract_json\(\)' "${ROOT}/internal/mooncode/runtime_protocol_contract.mbt" >/dev/null; then
  echo "runtime protocol contract must expose runtime_event_name_contract_json()." >&2
  exit 1
fi

if ! rg -n '"output_events": runtime_command_output_event_names\(\)' "${ROOT}/internal/mooncode/capabilities_runtime_contract.mbt" >/dev/null; then
  echo "runtime contract command output events must come from runtime_command_output_event_names()." >&2
  exit 1
fi

if ! rg -n '"runtime_event_name_contract": runtime_event_name_contract_json\(\)' "${ROOT}/internal/mooncode/capabilities.mbt" >/dev/null; then
  echo "MoonCode capabilities must expose runtime_event_name_contract_json()." >&2
  exit 1
fi

if ! rg -n '@mooncode_core\.native_command_expected_events\(' "${ROOT}/internal/mooncode/native_command_action_metadata.mbt" >/dev/null; then
  echo "native command expected events must delegate to the core-owned native command contract." >&2
  exit 1
fi

echo "MoonCode runtime event-name contract validation passed"
