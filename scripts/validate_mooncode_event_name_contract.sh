#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CORE_FILE="${ROOT}/mooncode/core/event_names.mbt"
CORE_INTERFACE="${ROOT}/mooncode/core/pkg.generated.mbti"
CONSUMER_FILES=(
  "${ROOT}/internal/mooncode/adapter_capabilities.mbt"
  "${ROOT}/internal/mooncode/adapter_commands.mbt"
  "${ROOT}/internal/mooncode/adapter_json.mbt"
  "${ROOT}/internal/mooncode/adapter_protocol.mbt"
  "${ROOT}/internal/mooncode/adapter_sessions.mbt"
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

for symbol in assistant_delta reasoning_delta assistant_message runtime_update tool_call tool_result test_result package_verified runtime_finished runtime_aborted command_error turn_failed max_steps_exhausted; do
  helper="runtime_event_${symbol}"
  if ! rg -n "fn ${helper}\\(" "${CORE_FILE}" >/dev/null; then
    echo "mooncode/core must own ${helper}()." >&2
    exit 1
  fi
  if rg -n "\\b${helper}\\b" "${CORE_INTERFACE}" >/dev/null; then
    echo "mooncode/core public interface must exclude raw/helper ${helper}()." >&2
    exit 1
  fi
  if rg -n "@mooncode_core\\.${helper}\\b" "${CONSUMER_FILES[@]}" >/dev/null; then
    echo "MoonCode adapters must not call private raw/helper ${helper}()." >&2
    exit 1
  fi
done

if rg -n \
  '"runtime_step", "assistant_delta"|"assistant_delta", "reasoning_delta"|"tool_call", "tool_result", "test_result", "runtime_finished"|"runtime_update", "runtime_finished"|"accepted_events": \[|"output_events": \[' \
  "${CONSUMER_FILES[@]}"; then
  echo "MoonCode runtime event-name ownership must come from mooncode/core, not duplicated adapter lists." >&2
  exit 1
fi

echo "MoonCode runtime event-name contract validation passed"
