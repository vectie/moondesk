#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORKSPACE_ROOT="$(cd "${ROOT}/.." && pwd)"
source "${ROOT}/scripts/moonsuite_phase8_inventory.sh"

EXPECTED_MOONLIB_VERSION="${MOONLIB_VERSION:-0.1.8}"
failures=0

fail() {
  echo "$1" >&2
  failures=$((failures + 1))
}

require_file() {
  local path="$1"
  if [[ ! -f "${path}" ]]; then
    fail "missing required file: ${path}"
  fi
}

require_contains() {
  local path="$1"
  local pattern="$2"
  local description="$3"
  if ! grep -q "${pattern}" "${path}"; then
    fail "missing ${description} in ${path}"
  fi
}

is_allowed_wrapper_hit() {
  local hit="$1"

  case "${hit}" in
    moondesk:./mooncode/core/protocol.mbt:*) return 0 ;;
    moondesk:./internal/mooncode/protocol.mbt:*) return 0 ;;
    moonclaw:./mooncode/core/protocol.mbt:*) return 0 ;;
  esac

  return 1
}

echo "==> MoonLib consumer pins"
bash "${ROOT}/scripts/validate_moonlib_consumer_pins.sh"

moonlib_root="$(moonsuite_phase8_repo_root "${WORKSPACE_ROOT}" "moonlib")"
moondesk_root="${ROOT}"
moonlib_contract="${moonlib_root}/conversation/contract.mbt"
moonlib_pkg="${moonlib_root}/conversation/moon.pkg"
moonlib_interface="${moonlib_root}/conversation/pkg.generated.mbti"
moondesk_protocol="${moondesk_root}/mooncode/core/protocol.mbt"
moondesk_core_pkg="${moondesk_root}/mooncode/core/moon.pkg"

if moonsuite_phase8_require_repo "${WORKSPACE_ROOT}" "moonlib"; then
  require_file "${moonlib_root}/moon.mod"
  require_file "${moonlib_contract}"
  require_file "${moonlib_pkg}"
  require_file "${moonlib_interface}"

  require_contains "${moonlib_root}/moon.mod" "version = \"${EXPECTED_MOONLIB_VERSION}\"" "MoonLib ${EXPECTED_MOONLIB_VERSION} source version"
  require_contains "${moonlib_contract}" "pub fn contract_id()" "conversation contract id function"
  require_contains "${moonlib_contract}" "moonsuite-conversation.v1" "shared conversation contract id"
  require_contains "${moonlib_contract}" "pub fn contract_kind()" "conversation contract kind function"
  require_contains "${moonlib_contract}" "moonsuite-conversation-contract" "shared conversation contract kind"
  require_contains "${moonlib_contract}" "pub fn turn_required_fields()" "shared required turn fields"
  require_contains "${moonlib_contract}" "pub fn identity_fields()" "shared identity fields"
  require_contains "${moonlib_contract}" "pub fn event_identity_rule()" "shared event identity rule"
  require_contains "${moonlib_contract}" "pub fn diagnostics_rule()" "shared diagnostics rule"
  require_contains "${moonlib_contract}" "shared_contract_owner" "MoonLib shared owner declaration"
  require_contains "${moonlib_interface}" "pub fn contract_json" "public conversation contract JSON interface"
fi

require_file "${moondesk_root}/moon.mod"
require_file "${moondesk_core_pkg}"
require_file "${moondesk_protocol}"
require_contains "${moondesk_root}/moon.mod" "\"vectie/moonlib@${EXPECTED_MOONLIB_VERSION}\"" "MoonDesk MoonLib ${EXPECTED_MOONLIB_VERSION} dependency"
require_contains "${moondesk_core_pkg}" "\"vectie/moonlib/conversation\"" "MoonCode core conversation import"
require_contains "${moondesk_protocol}" "@conversation.contract_id()" "MoonCode contract id delegation"
require_contains "${moondesk_protocol}" "@conversation.conversation_kind" "MoonCode conversation kind delegation"
require_contains "${moondesk_protocol}" "@conversation.turn_kind" "MoonCode turn kind delegation"
require_contains "${moondesk_protocol}" "@conversation.message_roles()" "MoonCode role delegation"
require_contains "${moondesk_protocol}" "@conversation.turn_required_fields()" "MoonCode required-field delegation"
require_contains "${moondesk_protocol}" "@conversation.contract_json" "MoonCode contract JSON delegation"

legacy_contract_pattern='(mooncode-conversation\.v1|mooncode-conversation-contract|moonlib_target)'
wrapper_pattern='(conversation_contract_json|conversation_message_roles|conversation_turn_required_fields)'

repos=("${MOONSUITE_PHASE8_SOURCE_REPOS[@]}")

for repo in "${repos[@]}"; do
  repo_root="$(moonsuite_phase8_repo_root "${WORKSPACE_ROOT}" "${repo}")"
  if ! moonsuite_phase8_require_repo "${WORKSPACE_ROOT}" "${repo}"; then
    failures=$((failures + 1))
    continue
  fi

  repo_legacy_failures=0
  while IFS= read -r line; do
    fail "retired conversation contract mirror in active source: ${repo}:${line}"
    repo_legacy_failures=$((repo_legacy_failures + 1))
  done < <(
    cd "${repo_root}"
    rg -n "${legacy_contract_pattern}" . \
      --glob '*.mbt' \
      --glob '*.mjs' \
      --glob '*.js' \
      --glob '*.ts' \
      --glob '*.tsx' \
      --glob '*.sh' \
      --glob '!**/*_test.mbt' \
      --glob '!**/*_wbtest.mbt' \
      --glob '!**/docs/**' \
      --glob '!**/_build/**' \
      --glob '!**/.mooncakes/**' \
      --glob '!**/.repos/**' \
      --glob '!**/dist/**' \
      --glob '!scripts/validate_conversation_contract_rollout.sh' || true
  )

  if [[ "${repo_legacy_failures}" -eq 0 ]]; then
    echo "ok ${repo}: no retired conversation contract ids"
  fi

  repo_wrapper_failures=0
  while IFS= read -r line; do
    hit="${repo}:${line}"
    if ! is_allowed_wrapper_hit "${hit}"; then
      fail "product-local conversation wrapper outside MoonCode adapter: ${hit}"
      repo_wrapper_failures=$((repo_wrapper_failures + 1))
    fi
  done < <(
    cd "${repo_root}"
    rg -n "${wrapper_pattern}" . \
      --glob '*.mbt' \
      --glob '!**/*_test.mbt' \
      --glob '!**/*_wbtest.mbt' \
      --glob '!**/docs/**' \
      --glob '!**/_build/**' \
      --glob '!**/.mooncakes/**' \
      --glob '!**/.repos/**' \
      --glob '!scripts/validate_conversation_contract_rollout.sh' || true
  )

  if [[ "${repo_wrapper_failures}" -eq 0 ]]; then
    echo "ok ${repo}: no unapproved product-local conversation wrappers"
  fi
done

if [[ "${failures}" -ne 0 ]]; then
  echo "Conversation contract rollout validation failed: ${failures} issue(s)" >&2
  exit 1
fi

echo "Conversation contract rollout validation passed for ${#repos[@]} repo(s)"
