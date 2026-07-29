#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CORE_FILE="${ROOT}/mooncode/core/runtime_evidence.mbt"
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
  "runtime_evidence_contract_id"
  "command_runtime_evidence_kind"
  "session_runtime_evidence_kind"
  "tool_harness_evidence_kind"
  "runtime_completion_proof_gate_kind"
  "runtime_evidence_status_for_required_events"
  "runtime_evidence_is_proven"
  "session_runtime_evidence_status_for_counts"
  "runtime_evidence_required_event_result"
  "runtime_evidence_event_satisfies"
  "runtime_evidence_event_fails_required"
  "runtime_completion_proof_gate_status"
  "runtime_completion_proof_gate"
  "runtime_evidence_contract_json"
)

for symbol in "${required_core_symbols[@]}"; do
  if ! rg -n "fn ${symbol}\\(" "${CORE_FILE}" >/dev/null; then echo "mooncode/core must own ${symbol}()." >&2; exit 1; fi
  if rg -n "\\b${symbol}\\b" "${CORE_INTERFACE}" >/dev/null; then echo "mooncode/core public interface must exclude raw/helper ${symbol}()." >&2; exit 1; fi
  if rg -n "@mooncode_core\\.${symbol}\\b" "${CONSUMER_FILES[@]}" >/dev/null; then echo "MoonCode adapters must not call private raw/helper ${symbol}()." >&2; exit 1; fi
done

if rg -n \
  '"mooncode-command-runtime-evidence"|"mooncode-tool-harness-evidence"|"mooncode-runtime-completion-proof-gate"|"mooncode-session-runtime-evidence"|"no-required-events"|"no-tools"|"waiting-for-proof"|"Proof-sensitive actions may not be marked runtime-completed"|fn evidence_event_satisfies|fn evidence_required_event_result' \
  "${CONSUMER_FILES[@]}"; then
  echo "MoonCode runtime evidence ownership must come from mooncode/core, not duplicated adapter policy." >&2
  exit 1
fi

for file in "${BEHAVIOR_FILES[@]}"; do [[ -f "${file}" ]] || { echo "missing adapter behavior proof: ${file}" >&2; exit 1; }; done

if ! rg -n '"runtime_evidence_contract": runtime_evidence_contract_json\(\)' "${ROOT}/mooncode/core/protocol.mbt" >/dev/null; then
  echo "native capability surface must embed runtime_evidence_contract_json()." >&2
  exit 1
fi

echo "MoonCode runtime evidence contract validation passed"
