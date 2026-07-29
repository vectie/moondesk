#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CORE_FILE="${ROOT}/mooncode/core/package_review_flow.mbt"
CORE_INTERFACE="${ROOT}/mooncode/core/pkg.generated.mbti"
CONSUMER_FILES=("${ROOT}/internal/mooncode/adapter_capabilities.mbt" "${ROOT}/internal/mooncode/adapter_commands.mbt" "${ROOT}/internal/mooncode/adapter_json.mbt" "${ROOT}/internal/mooncode/adapter_protocol.mbt" "${ROOT}/internal/mooncode/adapter_sessions.mbt")
BEHAVIOR_FILES=("${ROOT}/internal/mooncode/adapter_capabilities_wbtest.mbt" "${ROOT}/internal/mooncode/adapter_wbtest.mbt")
required_core_symbols=(package_review_flow_contract_id package_review_flow_contract_kind package_review_flow_report_kind package_review_flow_contract_json package_review_flow_status_accepted package_review_flow_status_rejected package_review_flow_status_failed package_review_flow_status_running package_review_flow_status_stale package_review_flow_status_empty package_review_flow_status_is_terminal package_review_flow_reason_missing_command_owner package_review_flow_reason_evidence_without_package_command package_review_flow_missing_step_assistant_summary package_review_flow_missing_step_package_manifest package_review_flow_missing_step_review_accept_receipt package_review_flow_missing_step_test_evidence package_review_flow_missing_step_package_verified package_review_flow_event_is_package_command package_review_flow_event_is_package_manifest package_review_flow_event_is_diff_review package_review_flow_event_is_accept package_review_flow_event_is_reject package_review_flow_event_is_test_result package_review_flow_event_is_package_readiness package_review_flow_event_is_package_built package_review_flow_event_is_package_verified package_review_flow_event_is_assistant_summary package_review_flow_event_is_failure package_review_flow_event_is_failure_eligible package_review_flow_event_is_evidence package_review_flow_event_failed)
for symbol in "${required_core_symbols[@]}"; do
  rg -n "fn ${symbol}\\(" "${CORE_FILE}" >/dev/null || { echo "mooncode/core must own ${symbol}()." >&2; exit 1; }
  ! rg -n "\\b${symbol}\\b" "${CORE_INTERFACE}" >/dev/null || { echo "mooncode/core public interface must exclude raw/helper ${symbol}()." >&2; exit 1; }
  ! rg -n "@mooncode_core\\.${symbol}\\b" "${CONSUMER_FILES[@]}" >/dev/null || { echo "MoonCode adapters must not call private raw/helper ${symbol}()." >&2; exit 1; }
done
if rg -n '"mooncode-package-review-model-flow-contract"|"mooncode-package-review-model-flow-report"|missing-command-owner|evidence-without-package-command|package-manifest|review-accept-receipt|package-verified' "${CONSUMER_FILES[@]}"; then echo "MoonCode package/review ownership must come from mooncode/core, not duplicated adapter policy." >&2; exit 1; fi
for file in "${BEHAVIOR_FILES[@]}"; do [[ -f "${file}" ]] || { echo "missing adapter behavior proof: ${file}" >&2; exit 1; }; done
rg -n '"package_review_flow_contract": package_review_flow_contract_json\(\)' "${ROOT}/mooncode/core/protocol.mbt" >/dev/null || { echo "native capability surface must embed package_review_flow_contract_json()." >&2; exit 1; }
echo "MoonCode package/review flow contract validation passed"
