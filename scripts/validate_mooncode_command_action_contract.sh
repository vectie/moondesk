#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CORE_FILE="${ROOT}/mooncode/core/command_actions.mbt"
IMPLEMENTATION_FILES=(
  "${ROOT}/internal/mooncode/command_metadata.mbt"
  "${ROOT}/internal/mooncode/protocol_commands.mbt"
  "${ROOT}/internal/mooncode/native_command_action_metadata.mbt"
  "${ROOT}/internal/mooncode/action_plan_state.mbt"
  "${ROOT}/internal/mooncode/runtime_replay_ack_proof_gate.mbt"
  "${ROOT}/internal/mooncode/review_artifact_paths.mbt"
  "${ROOT}/internal/mooncode/preflight.mbt"
  "${ROOT}/internal/mooncode/runtime_protocol_contract.mbt"
  "${ROOT}/internal/mooncode/capabilities_runtime_contract.mbt"
  "${ROOT}/internal/mooncode/capabilities.mbt"
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
  "command_advertised_actions"
  "command_supported_actions"
  "command_action_is_supported"
  "command_action_is_turn"
  "command_action_requires_tool_harness"
  "command_action_requires_runtime_completion_proof"
  "command_action_writes_review_receipt"
  "command_action_contract_json"
)

for symbol in "${required_core_symbols[@]}"; do
  if ! rg -n "pub fn ${symbol}\\(" "${CORE_FILE}" >/dev/null; then
    echo "mooncode/core must own public ${symbol}()." >&2
    exit 1
  fi
done

stale_file="/tmp/moondesk-mooncode-command-actions-stale.$$"
if rg -n \
  '"prompt", "steer", "cancel"|"prompt", "steer", "run_tests"|"run_tests", "run_build", "run_eval"|actions\.push\("note"\)|"accept" \| "package" \| "commit"|"apply_patch" \| "revert_patch"|"approve_tool" \| "reject_tool"' \
  "${IMPLEMENTATION_FILES[@]}" \
  >"${stale_file}"; then
  echo "MoonCode command action ownership must come from mooncode/core, not duplicated implementation lists." >&2
  cat "${stale_file}" >&2
  rm -f "${stale_file}"
  exit 1
fi
rm -f "${stale_file}"

if ! rg -n '@mooncode_core\.command_advertised_actions\(\)' "${ROOT}/internal/mooncode/command_metadata.mbt" >/dev/null; then
  echo "command metadata must delegate advertised actions to mooncode/core." >&2
  exit 1
fi

if ! rg -n '@mooncode_core\.command_supported_actions\(\)' "${ROOT}/internal/mooncode/command_metadata.mbt" >/dev/null; then
  echo "command metadata must delegate supported actions to mooncode/core." >&2
  exit 1
fi

if ! rg -n '@mooncode_core\.command_turn_actions\(\)' "${ROOT}/internal/mooncode/protocol_commands.mbt" >/dev/null; then
  echo "code_command_names() must use mooncode/core command_turn_actions()." >&2
  exit 1
fi

if ! rg -n '"command_action_contract": command_action_contract_json\(\)' "${ROOT}/internal/mooncode/runtime_protocol_contract.mbt" >/dev/null; then
  echo "runtime protocol contract must expose command_action_contract_json()." >&2
  exit 1
fi

if ! rg -n '"command_action_contract": command_action_contract_json\(\)' "${ROOT}/internal/mooncode/capabilities_runtime_contract.mbt" >/dev/null; then
  echo "runtime capability contract must expose command_action_contract_json()." >&2
  exit 1
fi

if ! rg -n '"command_action_contract": command_action_contract_json\(\)' "${ROOT}/internal/mooncode/capabilities.mbt" >/dev/null; then
  echo "MoonCode capabilities must expose command_action_contract_json()." >&2
  exit 1
fi

if ! rg -n '"command_action_contract": command_action_contract_json\(\)' "${ROOT}/mooncode/core/protocol.mbt" >/dev/null; then
  echo "native capability surface must embed command_action_contract_json()." >&2
  exit 1
fi

if ! rg -n '@mooncode_core\.command_action_requires_tool_harness\(' "${ROOT}/internal/mooncode/action_plan_state.mbt" >/dev/null; then
  echo "action plan tool-harness proof policy must delegate to mooncode/core." >&2
  exit 1
fi

if ! rg -n '@mooncode_core\.runtime_completion_proof_gate\(' "${ROOT}/internal/mooncode/runtime_replay_ack_proof_gate.mbt" >/dev/null; then
  echo "runtime completion proof policy must delegate to the core-owned runtime evidence contract." >&2
  exit 1
fi

if ! rg -n '@mooncode_core\.command_action_writes_review_receipt\(' "${ROOT}/internal/mooncode/review_artifact_paths.mbt" >/dev/null; then
  echo "review receipt action policy must delegate to mooncode/core." >&2
  exit 1
fi

if ! rg -n '@mooncode_core\.command_action_is_patch\(' "${ROOT}/internal/mooncode/preflight.mbt" >/dev/null; then
  echo "preflight patch action policy must consume mooncode/core action predicates." >&2
  exit 1
fi

if ! rg -n '@mooncode_core\.native_command_expected_events\(' "${ROOT}/internal/mooncode/native_command_action_metadata.mbt" >/dev/null; then
  echo "native action metadata must delegate native command action policy to mooncode/core." >&2
  exit 1
fi

if ! rg -n '@mooncode_core\.command_action_contract_id\(\)' "${ROOT}/internal/mooncode/protocol.mbt" >/dev/null; then
  echo "internal MoonCode protocol facade must delegate command action ownership to mooncode/core." >&2
  exit 1
fi

echo "MoonCode command action contract validation passed"
