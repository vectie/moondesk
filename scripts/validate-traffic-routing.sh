#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
moondesk_root="$(cd "${script_dir}/.." && pwd)"
moonclaw_root="${MOONCLAW_ROOT:-$(cd "${moondesk_root}/../moonclaw" && pwd)}"

fail() {
  echo "traffic routing validation failed: $*" >&2
  exit 1
}

production_globs=(
  --glob '*.mbt'
  --glob '*.js'
  --glob '!**/*_test.mbt'
  --glob '!**/*_wbtest.mbt'
  --glob '!**/*test*.js'
  --glob '!**/dist/**'
  --glob '!**/_build/**'
  --glob '!**/.mooncakes/**'
)

echo "+ reject direct provider endpoints in MoonDesk production sources"
if rg -n "api[.]openai[.]com|api[.]anthropic[.]com|openrouter[.]ai/api|api[.]githubcopilot[.]com|dashscope[.]aliyuncs[.]com|api[.]moonshot[.]cn" \
  "${production_globs[@]}" \
  "${moondesk_root}/internal" \
  "${moondesk_root}/mooncode" \
  "${moondesk_root}/ui/rabbita-desk/main"; then
  fail "MoonDesk contains a direct provider endpoint"
fi

echo "+ reject direct provider handoff redemption outside authenticated MoonClaw"
if rg -n 'client-handoffs:redeem' \
  "${production_globs[@]}" \
  "${moondesk_root}/internal" \
  "${moondesk_root}/plugin"; then
  fail "provider handoff redemption bypasses authenticated MoonClaw"
fi
while IFS= read -r source; do
  [[ "${source}" == "${moondesk_root}/internal/trusted_host_process/managed_daemon.mbt" ]] || \
    fail "unclassified LunaNexa issuer consumer: ${source#${moondesk_root}/}"
done < <(
  rg -l 'MOONDESK_LUNANEXA_ISSUER' \
    "${production_globs[@]}" \
    "${moondesk_root}/internal" \
    "${moondesk_root}/plugin" | sort
)
while IFS= read -r source; do
  [[ "${source}" == "${moonclaw_root}/cmd/daemon/daemon_provider_handoff.mbt" ]] || \
    fail "unclassified LunaNexa redemption owner: ${source#${moonclaw_root}/}"
done < <(
  rg -l 'client-handoffs:redeem|MOONDESK_LUNANEXA_ISSUER' \
    "${production_globs[@]}" \
    "${moonclaw_root}/cmd" \
    "${moonclaw_root}/plugin" | sort
)
rg -q '"/v1/client-handoffs:redeem"' \
  "${moonclaw_root}/cmd/daemon/daemon_provider_handoff.mbt" || \
  fail "MoonClaw LunaNexa redemption endpoint is missing"
rg -q 'configured_lunanexa_issuer' \
  "${moonclaw_root}/cmd/daemon/daemon_provider_handoff.mbt" || \
  fail "MoonClaw LunaNexa issuer pin is missing"
if ! rg -q 'MoonClaw owns the authenticated desktop operation' \
  "${moonclaw_root}/docs/LUNANEXA_PROVIDER_HANDOFF.md"; then
  fail "MoonClaw provider handoff ownership is not documented"
fi

echo "+ require MoonDesk AI ingress through authenticated MoonClaw control transport"
rg -q 'moonclaw_post_json\(daemon, "/v1/task"' \
  "${moondesk_root}/internal/moonwiki/moonclaw_general_chat_handlers.mbt" || \
  fail "general chat does not enter MoonClaw"
rg -q 'moonclaw_post_json' \
  "${moondesk_root}/internal/moonwiki/mooncode_turn_proxy.mbt" || \
  fail "MoonCode turns do not enter MoonClaw"
rg -q 'X-MoonClaw-Execution-Token' \
  "${moondesk_root}/internal/moonwiki/moonclaw_control_transport.mbt" || \
  fail "MoonClaw control authentication is missing"
rg -q 'moonclaw_post_json' \
  "${moondesk_root}/internal/moonwiki/provider_handoff.mbt" || \
  fail "provider handoff does not fail closed through MoonClaw"
if rg -q '@http[.]Client|client-handoffs:redeem' \
  "${moondesk_root}/internal/moonwiki/provider_handoff.mbt"; then
  fail "MoonDesk provider handoff contains direct egress"
fi

echo "+ require live MoonGate route authority and fail-closed selectors"
rg -q '"/v1/moongate-route"' \
  "${moondesk_root}/internal/moonwiki/mooncode_contracts.mbt" || \
  fail "MoonCode readiness does not use the live MoonGate route"
rg -q 'validate_mooncode_command_model_route' \
  "${moondesk_root}/internal/moonwiki/mooncode_turn_proxy.mbt" || \
  fail "MoonCode command route validation is missing"
rg -q '"model": routed_model' \
  "${moondesk_root}/internal/moonwiki/moonclaw_general_chat_handlers.mbt" || \
  fail "general chat does not pin the MoonGate model"

echo "+ require MoonClaw authenticated live MoonGate route endpoint"
rg -q 'moonclaw.moongate-route.v1' \
  "${moonclaw_root}/cmd/daemon/daemon_moongate_route.mbt" || \
  fail "MoonClaw route endpoint contract is missing"
rg -q 'moondesk_control_route_requires_auth\(Get, \["", "v1", "moongate-route"\]\)' \
  "${moonclaw_root}/cmd/daemon/moondesk_control_auth_wbtest.mbt" || \
  fail "MoonClaw route endpoint authentication is not tested"

echo "+ classify all MoonDesk native HTTP clients"
allowed_clients='^(internal/moonwiki/(moonclaw_control_transport|moonclaw_daemon_api|moonclaw_general_chat_handlers|source_semantics_sandbox_client|execution_sandbox_promotion_handlers|moontown_owner_api|pack_app_runtime)[.]mbt)$'
while IFS= read -r source; do
  relative="${source#${moondesk_root}/}"
  [[ "${relative}" =~ ${allowed_clients} ]] || fail "unclassified HTTP client: ${relative}"
done < <(
  rg -l '@http[.](get|post|get_stream)|@http[.]Client[(]' \
    "${production_globs[@]}" \
    "${moondesk_root}/internal/moonwiki" | sort
)

echo "traffic routing validation passed"
