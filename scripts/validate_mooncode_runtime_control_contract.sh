#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

fail() {
  echo "$1" >&2
  exit 1
}

require_core_symbol() {
  local symbol="$1"
  if ! rg -n "pub fn ${symbol}\\(" "${ROOT}/mooncode/core" --glob '*.mbt' >/dev/null; then
    fail "mooncode/core must publish ${symbol}"
  fi
}

require_core_symbol "conversation_ownership_contract_id"
require_core_symbol "conversation_ownership_contract_json"
require_core_symbol "runtime_control_contract_id"
require_core_symbol "runtime_control_contract_json"
require_core_symbol "runtime_control_state_kind"
require_core_symbol "runtime_control_effects"
require_core_symbol "runtime_control_effect_allows_turn"
require_core_symbol "runtime_control_settlement_required"
require_core_symbol "runtime_control_settlement_events"
require_core_symbol "runtime_control_action_starts_turn"
require_core_symbol "runtime_control_status_is_active"
require_core_symbol "runtime_control_status_is_blocked"

if ! rg -n '@mooncode_core\.conversation_ownership_contract_json\(\)' \
  "${ROOT}/internal/mooncode/canonical_conversation.mbt" >/dev/null; then
  fail "internal conversation ownership contract must delegate to mooncode/core"
fi

if ! rg -n '@mooncode_core\.runtime_control_contract_json\(\)' \
  "${ROOT}/internal/mooncode/runtime_control.mbt" >/dev/null; then
  fail "internal runtime-control contract must delegate to mooncode/core"
fi

if ! rg -n '@mooncode_core\.runtime_control_effect_allows_turn\(' \
  "${ROOT}/internal/mooncode/runtime_supervisor.mbt" >/dev/null; then
  fail "runtime supervisor must use the core runtime-control effect predicate"
fi

if ! rg -n '"runtime_control_contract": runtime_control_contract_json\(\)' \
  "${ROOT}/mooncode/core/protocol.mbt" >/dev/null; then
  fail "native capability surface must expose the runtime-control contract"
fi

tmp_hits="$(mktemp "${TMPDIR:-/tmp}/mooncode-runtime-control-contract.XXXXXX")"
trap 'rm -f "${tmp_hits}"' EXIT

if rg -n \
  '"mooncode-runtime-control-contract"|"mooncode-runtime-control-state"|"native-runtime-scheduler-boundary"|"start-turn"|"active-turn"|"queue-turn"|"deliver-steer"|"queue-steer"|"defer-steer"|"cancel-active"|"withdraw-pending"|"drop-cancel"|"record-note"|"already-completed"|"wait-for-proof"' \
  "${ROOT}/internal/mooncode/runtime_control.mbt" \
  "${ROOT}/internal/mooncode/runtime_control_decisions.mbt" \
  "${ROOT}/internal/mooncode/runtime_supervisor.mbt" \
  "${ROOT}/internal/mooncode/runtime_supervisor_helpers.mbt" \
  >"${tmp_hits}"; then
  echo "Runtime-control vocabulary must be owned by mooncode/core, not production internal MoonCode files:" >&2
  cat "${tmp_hits}" >&2
  exit 1
fi

if rg -n \
  '"mooncode-conversation-ownership-contract"|"visible_owner_rule"|"unowned_event_rule"|"control_rule"|"abort_rule"' \
  "${ROOT}/internal/mooncode/canonical_conversation.mbt" \
  >"${tmp_hits}"; then
  echo "Conversation ownership vocabulary must be owned by mooncode/core, not internal canonical-consumer files:" >&2
  cat "${tmp_hits}" >&2
  exit 1
fi

echo "MoonCode runtime-control contract ownership validated"
