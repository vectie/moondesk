#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
READINESS_FILES=(
  "${ROOT}/internal/mooncode/session_readiness.mbt"
  "${ROOT}/internal/mooncode/session_readiness_contract.mbt"
  "${ROOT}/internal/mooncode/session_readiness_policy.mbt"
  "${ROOT}/internal/mooncode/session_executable_lifecycle.mbt"
)

if rg -n 'chat_transcript|Chat transcript|assistant/transcript lane has durable chat evidence' "${READINESS_FILES[@]}" >/tmp/moondesk-mooncode-readiness-stale.$$; then
  echo "MoonCode readiness must be proven by canonical conversation turns, not the stale chat_transcript check." >&2
  cat /tmp/moondesk-mooncode-readiness-stale.$$ >&2
  rm -f /tmp/moondesk-mooncode-readiness-stale.$$
  exit 1
fi
rm -f /tmp/moondesk-mooncode-readiness-stale.$$

if rg -n 'count_lane\(events, "transcript"\)' "${ROOT}/internal/mooncode/session_readiness.mbt" >/tmp/moondesk-mooncode-readiness-transcript.$$; then
  echo "session_readiness_checks must not use raw transcript-lane counts as chat proof." >&2
  cat /tmp/moondesk-mooncode-readiness-transcript.$$ >&2
  rm -f /tmp/moondesk-mooncode-readiness-transcript.$$
  exit 1
fi
rm -f /tmp/moondesk-mooncode-readiness-transcript.$$

if ! rg -n 'conversation_projection\(session, events\)' "${ROOT}/internal/mooncode/session_readiness.mbt" >/dev/null; then
  echo "session_readiness_checks must derive chat readiness from conversation_projection(session, events)." >&2
  exit 1
fi

if ! rg -n 'canonical_conversation' "${READINESS_FILES[@]}" >/dev/null; then
  echo "MoonCode readiness contract must expose the canonical_conversation check." >&2
  exit 1
fi

echo "MoonCode readiness contract validation passed"
