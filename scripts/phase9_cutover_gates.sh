#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MODE="${1:-fast}"

case "${MODE}" in
  fast | full)
    ;;
  *)
    echo "usage: $0 [fast|full]" >&2
    exit 2
    ;;
esac

echo "==> Phase 8 migration wall (${MODE})"
bash "${ROOT}/scripts/phase8_migration_gates.sh" "${MODE}"

echo "==> Phase 9 cutover validation"
bash "${ROOT}/scripts/validate_phase9_cutover.sh"

echo "==> Phase 9 conversation contract rollout validation"
bash "${ROOT}/scripts/validate_conversation_contract_rollout.sh"

echo "Phase 9 ${MODE} cutover gates passed"
