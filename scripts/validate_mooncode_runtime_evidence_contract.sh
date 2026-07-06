#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CORE_FILE="${ROOT}/mooncode/core/runtime_evidence.mbt"
INTERNAL_FILES=(
  "${ROOT}/internal/mooncode/runtime_evidence.mbt"
  "${ROOT}/internal/mooncode/runtime_evidence_events.mbt"
  "${ROOT}/internal/mooncode/tool_harness_evidence.mbt"
  "${ROOT}/internal/mooncode/runtime_replay_ack_proof_gate.mbt"
  "${ROOT}/internal/mooncode/action_plan_state.mbt"
  "${ROOT}/internal/mooncode/action_plan_response.mbt"
  "${ROOT}/internal/mooncode/runtime_session_evidence.mbt"
)

required_core_symbols=(
  "runtime_evidence_contract_id"
  "command_runtime_evidence_kind"
  "session_runtime_evidence_kind"
  "tool_harness_evidence_kind"
  "runtime_completion_proof_gate_kind"
  "runtime_evidence_status_for_required_events"
  "runtime_evidence_is_proven"
  "tool_harness_status_for_counts"
  "tool_harness_is_proven"
  "tool_harness_expected_tools"
  "tool_harness_case_status"
  "session_runtime_evidence_status_for_counts"
  "runtime_evidence_event_satisfies"
  "runtime_evidence_event_fails_required"
  "runtime_completion_proof_gate"
  "runtime_replay_ack_effective_status"
  "action_plan_status_for_counts"
  "action_plan_state_with_tool_harness"
  "runtime_evidence_contract_json"
)

for symbol in "${required_core_symbols[@]}"; do
  if ! rg -n "pub fn ${symbol}\\(" "${CORE_FILE}" >/dev/null; then
    echo "mooncode/core must own public ${symbol}()." >&2
    exit 1
  fi
done

stale_file="/tmp/moondesk-mooncode-runtime-evidence-stale.$$"
if rg -n \
  '"mooncode-command-runtime-evidence"|"mooncode-tool-harness-evidence"|"mooncode-runtime-completion-proof-gate"|"mooncode-session-runtime-evidence"|"no-required-events"|"no-tools"|"waiting-for-proof"|"Proof-sensitive actions may not be marked runtime-completed"|fn evidence_event_satisfies|fn evidence_required_event_result' \
  "${INTERNAL_FILES[@]}" \
  >"${stale_file}"; then
  echo "MoonCode runtime evidence/proof policy must come from mooncode/core, not duplicated internal policy tables." >&2
  cat "${stale_file}" >&2
  rm -f "${stale_file}"
  exit 1
fi
rm -f "${stale_file}"

if ! rg -n '@mooncode_core\.runtime_evidence_status_for_required_events\(' "${ROOT}/internal/mooncode/runtime_evidence.mbt" >/dev/null; then
  echo "command runtime evidence status must delegate to mooncode/core." >&2
  exit 1
fi

if ! rg -n '@mooncode_core\.runtime_evidence_event_satisfies\(' "${ROOT}/internal/mooncode/runtime_evidence_events.mbt" >/dev/null; then
  echo "required event satisfaction policy must delegate to mooncode/core." >&2
  exit 1
fi

if ! rg -n '@mooncode_core\.tool_harness_status_for_counts\(' "${ROOT}/internal/mooncode/tool_harness_evidence.mbt" >/dev/null; then
  echo "tool harness status policy must delegate to mooncode/core." >&2
  exit 1
fi

if ! rg -n '@mooncode_core\.runtime_completion_proof_gate\(' "${ROOT}/internal/mooncode/runtime_replay_ack_proof_gate.mbt" >/dev/null; then
  echo "runtime replay proof gate must delegate to mooncode/core." >&2
  exit 1
fi

if ! rg -n '@mooncode_core\.action_plan_state_with_tool_harness\(' "${ROOT}/internal/mooncode/action_plan_state.mbt" >/dev/null; then
  echo "action-plan tool-harness proof state must delegate to mooncode/core." >&2
  exit 1
fi

if ! rg -n '@mooncode_core\.action_plan_status_for_counts\(' "${ROOT}/internal/mooncode/action_plan_response.mbt" >/dev/null; then
  echo "action-plan aggregate proof status must delegate to mooncode/core." >&2
  exit 1
fi

if ! rg -n '@mooncode_core\.session_runtime_evidence_status_for_counts\(' "${ROOT}/internal/mooncode/runtime_session_evidence.mbt" >/dev/null; then
  echo "session runtime evidence status must delegate to mooncode/core." >&2
  exit 1
fi

if ! rg -n '"runtime_evidence_contract": runtime_evidence_contract_json\(\)' "${ROOT}/mooncode/core/protocol.mbt" >/dev/null; then
  echo "native capability surface must embed runtime_evidence_contract_json()." >&2
  exit 1
fi

echo "MoonCode runtime evidence contract validation passed"
