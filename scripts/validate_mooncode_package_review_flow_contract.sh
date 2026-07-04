#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CORE_FILE="${ROOT}/mooncode/core/package_review_flow.mbt"
INTERNAL_FILE="${ROOT}/internal/mooncode/package_review_model_flow.mbt"

required_core_symbols=(
  "package_review_flow_contract_id"
  "package_review_flow_contract_kind"
  "package_review_flow_report_kind"
  "package_review_flow_contract_json"
  "package_review_flow_status_accepted"
  "package_review_flow_status_rejected"
  "package_review_flow_status_failed"
  "package_review_flow_status_running"
  "package_review_flow_status_stale"
  "package_review_flow_status_empty"
  "package_review_flow_status_is_terminal"
  "package_review_flow_reason_missing_command_owner"
  "package_review_flow_reason_evidence_without_package_command"
  "package_review_flow_missing_step_assistant_summary"
  "package_review_flow_missing_step_package_manifest"
  "package_review_flow_missing_step_review_accept_receipt"
  "package_review_flow_missing_step_test_evidence"
  "package_review_flow_missing_step_package_verified"
  "package_review_flow_event_is_package_command"
  "package_review_flow_event_is_package_manifest"
  "package_review_flow_event_is_diff_review"
  "package_review_flow_event_is_accept"
  "package_review_flow_event_is_reject"
  "package_review_flow_event_is_test_result"
  "package_review_flow_event_is_package_readiness"
  "package_review_flow_event_is_package_built"
  "package_review_flow_event_is_package_verified"
  "package_review_flow_event_is_assistant_summary"
  "package_review_flow_event_is_failure"
  "package_review_flow_event_is_failure_eligible"
  "package_review_flow_event_is_evidence"
  "package_review_flow_event_failed"
)

for symbol in "${required_core_symbols[@]}"; do
  if ! rg -n "pub fn ${symbol}\\(" "${CORE_FILE}" >/dev/null; then
    echo "mooncode/core must own public ${symbol}()." >&2
    exit 1
  fi
done

if ! rg -n '@mooncode_core\.package_review_flow_contract_json\(\)' "${INTERNAL_FILE}" >/dev/null; then
  echo "internal package/review flow contract JSON must delegate to mooncode/core." >&2
  exit 1
fi

if ! rg -n '@mooncode_core\.package_review_flow_event_is_evidence\(' "${INTERNAL_FILE}" >/dev/null; then
  echo "package/review evidence classification must delegate to mooncode/core." >&2
  exit 1
fi

if ! rg -n '@mooncode_core\.package_review_flow_status_is_terminal\(' "${INTERNAL_FILE}" >/dev/null; then
  echo "package/review terminal status policy must delegate to mooncode/core." >&2
  exit 1
fi

if ! rg -n '"package_review_model_flow_contract": package_review_model_flow_contract_json\(\)' \
  "${ROOT}/internal/mooncode/runtime_protocol_contract.mbt" >/dev/null; then
  echo "runtime protocol contract must expose package_review_model_flow_contract_json()." >&2
  exit 1
fi

if ! rg -n '"package_review_flow_contract": package_review_flow_contract_json\(\)' \
  "${ROOT}/mooncode/core/protocol.mbt" >/dev/null; then
  echo "native capability surface must embed package_review_flow_contract_json()." >&2
  exit 1
fi

if ! rg -n 'package_review_flow_contract_id\(\)' "${ROOT}/mooncode/core/protocol.mbt" >/dev/null; then
  echo "native capability fingerprint must include package_review_flow_contract_id()." >&2
  exit 1
fi

stale_file="/tmp/moondesk-mooncode-package-review-flow-stale.$$"
if rg -n \
  '"mooncode-package-review-model-flow-contract"|"mooncode-package-review-model-flow-report"|"command.package"|"package.manifest"|"receipt.accept"|"receipt.reject"|"runtime.package_verified"|"assistant_summary"|"package_verified"|"review_accept_receipt"|"test_evidence"|"missing-command-owner"|"evidence-without-package-command"|"waiting-for-manifest"|"waiting-for-review"|"waiting-for-tests"|"waiting-for-readiness"|"waiting-for-assistant"' \
  "${INTERNAL_FILE}" \
  >"${stale_file}"; then
  echo "MoonCode package/review flow vocabulary must be owned by mooncode/core, not duplicated in production internal MoonCode." >&2
  cat "${stale_file}" >&2
  rm -f "${stale_file}"
  exit 1
fi
rm -f "${stale_file}"

echo "MoonCode package/review flow contract ownership validated"
