#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
UI_MAIN="${ROOT}/ui/rabbita-desk/main"

raw_hits="$(
  rg -n '"/api/|/api/' "${UI_MAIN}" \
    --glob '*.mbt' \
    --glob '!*_wbtest.mbt' || true
)"

encoder_hits="$(
  rg -n 'encode_component|encode_path' "${UI_MAIN}" \
    --glob '*.mbt' \
    --glob '!*_wbtest.mbt' || true
)"

if [[ -n "${raw_hits}" || -n "${encoder_hits}" ]]; then
  echo "Rabbita desktop API routes must live in vectie/moondesk/core route helpers" >&2
  if [[ -n "${raw_hits}" ]]; then
    echo "${raw_hits}" >&2
  fi
  if [[ -n "${encoder_hits}" ]]; then
    echo "${encoder_hits}" >&2
  fi
  exit 1
fi

echo "Rabbita desktop route ownership validation passed"
