#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ROUTERS=(
  "${ROOT}/internal/moonwiki/api_desktop_router.mbt"
  "${ROOT}/internal/moonwiki/api_workspace_router.mbt"
  "${ROOT}/internal/moonwiki/api_town_router.mbt"
  "${ROOT}/internal/moonwiki/api_moonclaw_router.mbt"
  "${ROOT}/internal/moonwiki/api_review_preferences_router.mbt"
  "${ROOT}/internal/moonwiki/api_book_router.mbt"
)

policy_hits="$(
  rg -n 'is_read_method\(method_\)|method_ is (Get|Head|Post|Put|Patch|Delete|Options|Connect|Trace)|send_method_not_allowed\(conn, method_\)' "${ROUTERS[@]}" || true
)"

if [[ -n "${policy_hits}" ]]; then
  echo "Generic desktop API routers must use the shared core route method contract" >&2
  echo "${policy_hits}" >&2
  exit 1
fi

if rg -n '\"api\", \"town\", \"control\"|/api/town/control' "${ROOT}/internal/moonwiki" "${ROOT}/ui/rabbita-desk/main" --glob '*.mbt' --glob '!*_wbtest.mbt' >/tmp/moondesk-town-control-hits.$$; then
  echo "Retired /api/town/control route must not return; use /api/town/dispatch" >&2
  cat /tmp/moondesk-town-control-hits.$$ >&2
  rm -f /tmp/moondesk-town-control-hits.$$
  exit 1
fi
rm -f /tmp/moondesk-town-control-hits.$$

echo "Desktop API backend method contract validation passed"
