#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CORE_FILE="${ROOT}/mooncode/core/runtime_consumer.mbt"
INTERNAL_FILES=(
  "${ROOT}/internal/mooncode/runtime_consumer_contracts.mbt"
  "${ROOT}/internal/mooncode/runtime_queue_guards.mbt"
  "${ROOT}/internal/mooncode/runtime_queue_claim_status.mbt"
  "${ROOT}/internal/mooncode/runtime_queue_replay_status.mbt"
  "${ROOT}/internal/mooncode/runtime_replay_ack_requests.mbt"
  "${ROOT}/internal/mooncode/runtime_replay_ack_ordering.mbt"
  "${ROOT}/internal/mooncode/runtime_claim_state.mbt"
  "${ROOT}/internal/mooncode/runtime_replay_state.mbt"
  "${ROOT}/internal/mooncode/runtime_claim.mbt"
  "${ROOT}/internal/mooncode/runtime_replay_ack.mbt"
  "${ROOT}/internal/mooncode/runtime_queue_items.mbt"
  "${ROOT}/internal/mooncode/runtime_queue_helpers.mbt"
)

required_core_symbols=(
  "runtime_consumer_contract_id"
  "runtime_consumer_contract_kind"
  "runtime_claim_state_kind"
  "runtime_claim_response_kind"
  "runtime_replay_state_kind"
  "runtime_claim_mode"
  "runtime_replay_mode"
  "runtime_receipt_status_accepted"
  "runtime_receipt_status_acknowledged"
  "runtime_receipt_status_completed"
  "runtime_receipt_status_claimed"
  "runtime_receipt_status_failed"
  "runtime_receipt_status_proof_missing"
  "runtime_receipt_status_skipped"
  "runtime_receipt_status_missing"
  "runtime_receipt_status_recorded"
  "runtime_receipt_delivered_statuses"
  "runtime_receipt_status_is_delivered"
  "runtime_receipt_status_is_claimed"
  "runtime_replay_ack_allowed_statuses"
  "runtime_replay_ack_status"
  "runtime_replay_ack_detail"
  "runtime_claim_base_status"
  "runtime_claim_status_with_order_blocker"
  "runtime_claim_status_blocks_following"
  "runtime_replay_base_status"
  "runtime_replay_status_with_order_blocker"
  "runtime_replay_status_is_pending"
  "runtime_replay_status_blocks_following"
  "runtime_replay_ack_order_statuses"
  "runtime_claim_endpoint"
  "runtime_replay_endpoint"
  "runtime_claim_ordering_rule"
  "runtime_claim_lease_policy"
  "runtime_claim_authorization_rule"
  "runtime_claim_consumer_ordering_rule"
  "runtime_claim_duplicate_guard"
  "runtime_replay_policy"
  "runtime_replay_ordering_rule"
  "runtime_replay_authorization_rule"
  "runtime_replay_duplicate_guard"
  "runtime_claim_consumer_contract_json"
  "runtime_replay_consumer_contract_json"
  "runtime_consumer_contract_json"
)

for symbol in "${required_core_symbols[@]}"; do
  if ! rg -n "pub fn ${symbol}\\(" "${CORE_FILE}" >/dev/null; then
    echo "mooncode/core must own public ${symbol}()." >&2
    exit 1
  fi
done

if ! rg -n '@mooncode_core\.runtime_claim_consumer_contract_json\(' \
  "${ROOT}/internal/mooncode/runtime_consumer_contracts.mbt" >/dev/null; then
  echo "internal runtime claim consumer contract must delegate to mooncode/core." >&2
  exit 1
fi

if ! rg -n '@mooncode_core\.runtime_replay_consumer_contract_json\(' \
  "${ROOT}/internal/mooncode/runtime_consumer_contracts.mbt" >/dev/null; then
  echo "internal runtime replay consumer contract must delegate to mooncode/core." >&2
  exit 1
fi

if ! rg -n '@mooncode_core\.runtime_claim_base_status\(' \
  "${ROOT}/internal/mooncode/runtime_queue_claim_status.mbt" >/dev/null; then
  echo "runtime claim status policy must delegate to mooncode/core." >&2
  exit 1
fi

if ! rg -n '@mooncode_core\.runtime_replay_base_status\(' \
  "${ROOT}/internal/mooncode/runtime_queue_replay_status.mbt" >/dev/null; then
  echo "runtime replay status policy must delegate to mooncode/core." >&2
  exit 1
fi

if ! rg -n '@mooncode_core\.runtime_replay_ack_status\(' \
  "${ROOT}/internal/mooncode/runtime_replay_ack_requests.mbt" >/dev/null; then
  echo "runtime replay ack status policy must delegate to mooncode/core." >&2
  exit 1
fi

if ! rg -n '"runtime_consumer_contract": runtime_consumer_contract_json\(' \
  "${ROOT}/mooncode/core/protocol.mbt" >/dev/null; then
  echo "native capability surface must embed runtime_consumer_contract_json()." >&2
  exit 1
fi

if ! rg -n 'runtime_consumer_contract_id\(\)' \
  "${ROOT}/mooncode/core/protocol.mbt" >/dev/null; then
  echo "native capability fingerprint must include runtime_consumer_contract_id()." >&2
  exit 1
fi

stale_file="/tmp/moondesk-mooncode-runtime-consumer-stale.$$"
if rg -n \
  '"runtime-accepted"|"runtime-acknowledged"|"runtime-completed"|"runtime-claimed"|"proof-missing"|"skipped"|"missing"|"recorded"|"claimable"|"claimed"|"delivered"|"invalid"|"blocked-tool-authorization"|"blocked-by-prior-command"|"blocked-invalid"|"expired-claim-pending-retry"|"missing-proof-pending-retry"|"failed-pending-retry"|"pending"|"matching-claim"|"consumer-mismatch"|"already-delivered"|"retry-after-failed-receipt"|"unclaimed-ack"|"mooncode-runtime-claim-state"|"mooncode-runtime-replay"|"mooncode-runtime-claim"' \
  "${INTERNAL_FILES[@]}" \
  >"${stale_file}"; then
  echo "MoonCode runtime consumer vocabulary must be owned by mooncode/core, not duplicated in runtime consumer projection files." >&2
  cat "${stale_file}" >&2
  rm -f "${stale_file}"
  exit 1
fi
rm -f "${stale_file}"

echo "MoonCode runtime consumer contract ownership validated"
