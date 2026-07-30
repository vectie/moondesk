#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ADAPTER="${ROOT}/internal/mooncode/adapter_capabilities.mbt"
ADAPTER_TESTS=(
  "${ROOT}/internal/mooncode/adapter_capabilities_wbtest.mbt"
  "${ROOT}/internal/mooncode/adapter_wbtest.mbt"
)
CORE_CODEC="${ROOT}/mooncode/core/capability_codec.mbt"
ADAPTER_FILES=("${ADAPTER}" "${ADAPTER_TESTS[@]}")

if rg -n 'chat_transcript|count_lane\(events, "transcript"\)' "${ADAPTER_FILES[@]}"; then
  echo "MoonCode adapters must not restore stale transcript readiness or raw transcript-lane counting." >&2
  exit 1
fi

if rg -n '(^|[^@[:alnum:]_])conversation_projection[[:space:]]*\(' "${ADAPTER_FILES[@]}"; then
  echo "MoonCode adapters must not maintain a local conversation_projection mirror." >&2
  exit 1
fi

if ! rg -n -F '@mooncode_core.mooncode_capability()' "${ADAPTER}" >/dev/null; then
  echo "MoonCode adapter must build its capability response from the core capability surface." >&2
  exit 1
fi

if ! rg -n -F '@mooncode_core.decode_mooncode_capability(payload)' "${ADAPTER}" >/dev/null; then
  echo "MoonCode adapter must consume negotiated readiness through the core capability decoder." >&2
  exit 1
fi

for field in canonical_conversation native_runtime_ready runtime_owner session_owner; do
  if ! rg -n "${field}" "${ADAPTER}" "${CORE_CODEC}" >/dev/null; then
    echo "MoonCode capability readiness contract must retain ${field}." >&2
    exit 1
  fi
done

for test_name in \
  "adapter negotiates only the canonical v1 wire protocol" \
  "session defaults never expose a second transcript" \
  "adapter exposes only the canonical desktop route surface"
do
  if ! rg -n -F "test \"${test_name}\"" "${ADAPTER_TESTS[@]}" >/dev/null; then
    echo "MoonCode adapter contract test is missing: ${test_name}" >&2
    exit 1
  fi
done

echo "MoonCode readiness contract validation passed"
