#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CORE_FILE="${ROOT}/mooncode/core/event_lanes.mbt"
INTERNAL_FILES=(
  "${ROOT}/internal/mooncode/command_metadata.mbt"
  "${ROOT}/internal/mooncode/runtime_event_projection.mbt"
  "${ROOT}/internal/mooncode/native_runtime_contract.mbt"
  "${ROOT}/internal/mooncode/session_readiness.mbt"
  "${ROOT}/internal/mooncode/session_eval_checks.mbt"
  "${ROOT}/internal/mooncode/session_summary.mbt"
  "${ROOT}/internal/mooncode/conversation_projection.mbt"
  "${ROOT}/internal/mooncode/runtime_command_progress.mbt"
  "${ROOT}/internal/mooncode/model_planner_evidence.mbt"
  "${ROOT}/internal/mooncode/package_review_model_flow.mbt"
  "${ROOT}/internal/mooncode/session_tool_approvals.mbt"
)

required_core_symbols=(
  "event_lane_contract_id"
  "event_lane_transcript"
  "event_lane_runtime"
  "event_lane_tool"
  "event_lane_diff"
  "event_lane_test"
  "event_lane_artifact"
  "event_lane_review"
  "event_lane_default"
  "event_lanes"
  "event_progress_lanes"
  "event_lane_is_supported"
  "event_lane_is_progress"
  "event_lane_normalize"
  "event_lane_contract_json"
)

for symbol in "${required_core_symbols[@]}"; do
  if ! rg -n "pub fn ${symbol}\\(" "${CORE_FILE}" >/dev/null; then
    echo "mooncode/core must own public ${symbol}()." >&2
    exit 1
  fi
done

stale_file="/tmp/moondesk-mooncode-event-lanes-stale.$$"
if rg -n \
  '"transcript", "runtime", "tool", "diff", "test", "artifact", "review"|"runtime", "tool", "diff", "test", "artifact", "review"|MoonCode lanes: transcript|normalized into MoonCode lanes: transcript|transcript lanes|count_lane\(events, "(runtime|tool|diff|test|artifact|review)"\)|lane == "(transcript|runtime|tool|diff|test|artifact|review)"' \
  "${INTERNAL_FILES[@]}" \
  >"${stale_file}"; then
  echo "MoonCode event lane ownership must come from mooncode/core, not duplicated implementation strings." >&2
  cat "${stale_file}" >&2
  rm -f "${stale_file}"
  exit 1
fi
rm -f "${stale_file}"

if ! rg -n 'event_lanes\(\)' "${ROOT}/internal/mooncode/command_metadata.mbt" >/dev/null; then
  echo "command metadata must use the mooncode/core event_lanes() contract for prompt/steer coverage." >&2
  exit 1
fi

if ! rg -n 'event_lane_contract_json\(\)' "${ROOT}/internal/mooncode/runtime_protocol_contract.mbt" >/dev/null; then
  echo "runtime protocol contract must expose event_lane_contract_json()." >&2
  exit 1
fi

if ! rg -n '"event_lane_contract": event_lane_contract_json\(\)' "${ROOT}/internal/mooncode/capabilities.mbt" >/dev/null; then
  echo "MoonCode capabilities must expose the event lane contract." >&2
  exit 1
fi

if ! rg -n '@mooncode_core\.event_lane_contract_id\(\)' "${ROOT}/internal/mooncode/protocol.mbt" >/dev/null; then
  echo "internal MoonCode protocol facade must delegate event lane ownership to mooncode/core." >&2
  exit 1
fi

echo "MoonCode event lane contract validation passed"
