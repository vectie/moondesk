#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORKSPACE_ROOT="$(cd "${ROOT}/.." && pwd)"
MOON_BIN="${MOON_BIN:-${MOON:-moon}}"
MODE="${1:-fast}"

export MOON="${MOON:-${MOON_BIN}}"
export MOONCLAW_ROOT="${MOONCLAW_ROOT:-${WORKSPACE_ROOT}/moonclaw}"
export MOONBOOK_ROOT="${MOONBOOK_ROOT:-${WORKSPACE_ROOT}/moonbook}"
export MOONTOWN_ROOT="${MOONTOWN_ROOT:-${WORKSPACE_ROOT}/moontown}"

run_step() {
  local label="$1"
  shift
  echo "==> ${label}"
  "$@"
}

run_repo_step() {
  local label="$1"
  local dir="$2"
  shift 2
  echo "==> ${label}"
  (
    cd "${dir}"
    "$@"
  )
}

case "${MODE}" in
  fast | full)
    ;;
  *)
    echo "usage: $0 [fast|full]" >&2
    exit 2
    ;;
esac

run_repo_step "Moondesk moon fmt" "${ROOT}" "${MOON_BIN}" fmt
run_repo_step "Moondesk moon info" "${ROOT}" "${MOON_BIN}" info
run_repo_step "Moondesk native check" "${ROOT}" "${MOON_BIN}" check --target native --diagnostic-limit 120
run_repo_step "Moondesk native tests" "${ROOT}" "${MOON_BIN}" test --target native

run_repo_step "Rabbita JS check" "${ROOT}/ui/rabbita-desk" "${MOON_BIN}" check --target js --diagnostic-limit 120
run_repo_step "Rabbita JS tests" "${ROOT}/ui/rabbita-desk" "${MOON_BIN}" test --target js
run_repo_step "Rabbita production build" "${ROOT}/ui/rabbita-desk" npm run build

run_step "MoonCode frontend route ownership" bash "${ROOT}/scripts/validate_mooncode_frontend_routes.sh"
run_repo_step "MoonCode frontend session effect ownership" "${ROOT}/ui/rabbita-desk" "${MOON_BIN}" test main --target js --filter "mooncode session effects*"
run_step "MoonLib consumer pins" bash "${ROOT}/scripts/validate_moonlib_consumer_pins.sh"
run_step "MoonSuite contract rollout" bash "${ROOT}/scripts/validate_moonsuite_contract_rollout.sh"
run_step "Fresh-suite residual scan" bash "${ROOT}/scripts/validate_fresh_suite_residuals.sh"
run_step "Core boundary validation" bash "${ROOT}/scripts/validate-core-boundaries.sh"

if [[ "${MODE}" == "full" ]]; then
  run_step "Moondesk API smoke" bash "${ROOT}/scripts/desk_mode_api_smoke.sh"
  run_step "Desk browser smoke" bash "${ROOT}/scripts/desk_mode_browser_smoke.sh"
  run_step "Fresh-suite product smoke" bash "${ROOT}/scripts/fresh_suite_product_smoke.sh"
fi

echo "Phase 8 ${MODE} migration gates passed"
