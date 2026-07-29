#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CORE_FILE="${ROOT}/mooncode/core/command_actions.mbt"
CORE_INTERFACE="${ROOT}/mooncode/core/pkg.generated.mbti"
CONSUMER_FILES=(
  "${ROOT}/internal/mooncode/adapter_capabilities.mbt"
  "${ROOT}/internal/mooncode/adapter_commands.mbt"
  "${ROOT}/internal/mooncode/adapter_json.mbt"
  "${ROOT}/internal/mooncode/adapter_protocol.mbt"
  "${ROOT}/internal/mooncode/adapter_sessions.mbt"
)

required_core_symbols=(
  "command_action_contract_id"
  "command_prompt"
  "command_steer"
  "command_run_tests"
  "command_run_build"
  "command_run_eval"
  "command_package"
  "command_commit"
  "command_accept"
  "command_reject"
  "command_approve_tool"
  "command_reject_tool"
  "command_apply_patch"
  "command_revert_patch"
  "command_cancel"
  "command_note"
  "command_turn_actions"
  "command_supported_actions"
  "command_action_is_advertised"
  "command_action_is_turn"
  "command_action_requires_tool_harness"
  "command_action_requires_runtime_completion_proof"
  "command_action_writes_review_receipt"
  "command_action_contract_json"
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
  '"prompt", "steer", "cancel"|"prompt", "steer", "run_tests"|"run_tests", "run_build", "run_eval"|actions\.push\("note"\)|"accept" \| "package" \| "commit"|"apply_patch" \| "revert_patch"|"approve_tool" \| "reject_tool"' \
  "${CONSUMER_FILES[@]}"; then
  echo "MoonCode command action ownership must come from mooncode/core, not duplicated adapter lists." >&2
  exit 1
fi
