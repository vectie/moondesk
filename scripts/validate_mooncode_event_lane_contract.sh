#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CORE_FILE="${ROOT}/mooncode/core/event_lanes.mbt"
CORE_INTERFACE="${ROOT}/mooncode/core/pkg.generated.mbti"
CONSUMER_FILES=(
  "${ROOT}/internal/mooncode/adapter_capabilities.mbt"
  "${ROOT}/internal/mooncode/adapter_commands.mbt"
  "${ROOT}/internal/mooncode/adapter_json.mbt"
  "${ROOT}/internal/mooncode/adapter_protocol.mbt"
  "${ROOT}/internal/mooncode/adapter_sessions.mbt"
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
  '"transcript", "runtime", "tool", "diff", "test", "artifact", "review"|"runtime", "tool", "diff", "test", "artifact", "review"|MoonCode lanes: transcript|normalized into MoonCode lanes: transcript|transcript lanes|count_lane\(events, "(runtime|tool|diff|test|artifact|review)"\)|lane == "(transcript|runtime|tool|diff|test|artifact|review)"' \
  "${CONSUMER_FILES[@]}"; then
  echo "MoonCode event lane ownership must come from mooncode/core, not duplicated adapter strings." >&2
  exit 1
fi

echo "MoonCode event lane contract validation passed"
