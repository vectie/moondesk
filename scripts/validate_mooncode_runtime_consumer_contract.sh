#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CORE_FILE="${ROOT}/mooncode/core/runtime_consumer.mbt"
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
  if ! rg -n "fn ${symbol}\\(" "${CORE_FILE}" >/dev/null; then echo "mooncode/core must own ${symbol}()." >&2; exit 1; fi
  if rg -n "\\b${symbol}\\b" "${CORE_INTERFACE}" >/dev/null; then echo "mooncode/core public interface must exclude raw/helper ${symbol}()." >&2; exit 1; fi
  if rg -n "@mooncode_core\\.${symbol}\\b" "${CONSUMER_FILES[@]}" >/dev/null; then echo "MoonCode adapters must not call private raw/helper ${symbol}()." >&2; exit 1; fi
done

if rg -n \
  '"runtime-accepted"|"runtime-acknowledged"|"runtime-completed"|"runtime-claimed"|"proof-missing"|"skipped"|"recorded"|"claimable"|"blocked-by-prior-command"|"expired-claim-pending-retry"|"missing-proof-pending-retry"|"failed-pending-retry"|"matching-claim"|"consumer-mismatch"|"already-delivered"|"retry-after-failed-receipt"|"unclaimed-ack"|"mooncode-runtime-claim-state"|"mooncode-runtime-replay"|"mooncode-runtime-claim"' \
  "${CONSUMER_FILES[@]}"; then
  echo "MoonCode runtime consumer ownership must come from mooncode/core, not duplicated adapter literals." >&2
  exit 1
fi

for file in "${BEHAVIOR_FILES[@]}"; do [[ -f "${file}" ]] || { echo "missing adapter behavior proof: ${file}" >&2; exit 1; }; done

if ! rg -n '"runtime_consumer_contract": runtime_consumer_contract_json\(' "${ROOT}/mooncode/core/protocol.mbt" >/dev/null; then
  echo "native capability surface must embed runtime_consumer_contract_json()." >&2
  exit 1
fi

echo "MoonCode runtime consumer contract validation passed"
