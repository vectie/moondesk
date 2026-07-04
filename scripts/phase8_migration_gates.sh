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
run_step "Rabbita desktop route ownership" bash "${ROOT}/scripts/validate_rabbita_desktop_routes.sh"
run_step "Desktop API backend method contract ownership" bash "${ROOT}/scripts/validate_desktop_api_backend_method_contract.sh"
run_step "Desktop API capability contract ownership" bash "${ROOT}/scripts/validate_desktop_api_capability_contract.sh"
run_step "Desktop API HTTP route method contract coverage" node "${ROOT}/scripts/desktop_api_http_method_contract_smoke.mjs"
run_step "Portable API route contract ownership" bash "${ROOT}/scripts/validate_portable_api_route_contract.sh"
run_repo_step "MoonCode frontend session effect ownership" "${ROOT}/ui/rabbita-desk" "${MOON_BIN}" test main --target js --filter "mooncode session effects*"
run_repo_step "MoonCode backend route contract ownership" "${ROOT}" "${MOON_BIN}" test internal/moonwiki --target native --filter "mooncode backend route contract*"
run_step "MoonCode backend route source ownership" node "${ROOT}/scripts/validate_mooncode_backend_route_ownership.mjs"
run_repo_step "MoonCode route method contract ownership" "${ROOT}" "${MOON_BIN}" test internal/mooncode --target native --filter "desktop projection endpoint contract*"
run_step "MoonCode native endpoint contract ownership" bash "${ROOT}/scripts/validate_mooncode_native_endpoint_contract.sh"
run_step "MoonCode readiness contract ownership" bash "${ROOT}/scripts/validate_mooncode_readiness_contract.sh"
run_step "MoonCode event lane contract ownership" bash "${ROOT}/scripts/validate_mooncode_event_lane_contract.sh"
run_step "MoonCode runtime event-name contract ownership" bash "${ROOT}/scripts/validate_mooncode_event_name_contract.sh"
run_step "MoonCode command action contract ownership" bash "${ROOT}/scripts/validate_mooncode_command_action_contract.sh"
run_step "MoonCode backend method dispatch ownership" bash "${ROOT}/scripts/validate_mooncode_backend_method_dispatch.sh"
run_step "MoonCode HTTP route method contract coverage" node "${ROOT}/scripts/mooncode_http_method_contract_smoke.mjs"
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
