#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${ROOT}"

node scripts/mooncode_live_runtime_control_boundary_smoke.mjs "$@"
