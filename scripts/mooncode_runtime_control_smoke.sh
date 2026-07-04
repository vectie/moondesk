#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${ROOT}"

node scripts/mooncode_runtime_control_smoke.mjs "$@"
