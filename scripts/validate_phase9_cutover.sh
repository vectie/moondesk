#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORKSPACE_ROOT="$(cd "${ROOT}/.." && pwd)"
source "${ROOT}/scripts/moonsuite_phase8_inventory.sh"

repos=("${MOONSUITE_PHASE8_SOURCE_REPOS[@]}")

legacy_cutover_pattern='(\.moontown/books|/\.moontown/trash|\.moontown/moondesk-daemon|\.moonbook(/|"|$)|moonclaw-jobs(/|"|$)|\.moonclaw-worktrees(/|"|$)|\.moonclaw-tool-journal(/|"|$)|source_checkout_safe_workspace_root|workspace_root_source_checkout_warning|workspace_root_contains_path|Using dedicated user workspace root|source checkout redirect|outside source checkouts|home fallback workspace|USERPROFILE|HOME/moondesk[-]workspace|USERPROFILE/moondesk[-]workspace|default_workspace_root_from_env\([^)]*,)'
machine_local_source_pattern='([/]Users/[^[:space:]`"]+|C:\\Users|[/]home/(user|ci[[:alnum:]]*)/[^[:space:]`"]+)'

is_allowed_hit() {
  local hit="$1"

  case "${hit}" in
    moondesk:./scripts/desk_mode_browser_smoke.mjs:*)
      # Browser smoke asserts legacy MoonBook projection/trash paths are absent.
      return 0
      ;;
    moondesk:./scripts/desk_mode_api_smoke.sh:*)
      # API smoke asserts retired source-checkout redirect warnings are absent.
      return 0
      ;;
    moondesk:./scripts/lepusa_fresh_books_smoke.sh:*)
      # Lepusa smoke asserts legacy product roots are not created.
      return 0
      ;;
    moondesk:./scripts/mooncode_runtime_control_smoke.mjs:*|\
    moondesk:./scripts/mooncode_live_runtime_control_boundary_smoke.mjs:*|\
    moondesk:./scripts/mooncode_runtime_service_failure_smoke.mjs:*|\
    moondesk:./scripts/mooncode_live_runtime_loop_smoke.mjs:*|\
    moondesk:./scripts/mooncode_live_runtime_contract_smoke.mjs:*|\
    moondesk:./scripts/mooncode_live_runtime_multiturn_smoke.mjs:*)
      # MoonCode runtime smokes assert legacy MoonClaw roots are not created.
      return 0
      ;;
    moondesk:./scripts/validate_fresh_suite_residuals.sh:*)
      # Phase 8 residual scan has its own legacy-string detector and allowlist.
      return 0
      ;;
    moonstat:./suite.mbt:*)
      # MoonGate is the drift detector for legacy product-home candidates.
      return 0
      ;;
    moontown:./scripts/fresh-suite-writers-smoke.sh:*)
      # MoonTown fresh-suite smoke asserts old roots are absent after writes.
      return 0
      ;;
    moonclaw:./scripts/fresh-suite-product-home-smoke.sh:*)
      # MoonClaw fresh-suite smoke asserts old roots are absent after writes.
      return 0
      ;;
    moonbook:./scripts/fresh-suite-extension-smoke.sh:*)
      # MoonBook fresh-suite smoke asserts old extension roots are absent.
      return 0
      ;;
    moonbook:./internal/moonwiki/server.mbt:*'assert_false(live_reload_token_file.has_prefix(".moonbook"))'*)
      # MoonBook keeps a package-local negative assertion in the server file.
      return 0
      ;;
    moonbook:./wiki/extensions.mbt:*'assert_true(!@fsx.exists(root + "/.moonclaw/providers.json"))'*)
      # MoonBook extension coverage asserts provider manifests use MoonSuite homes.
      return 0
      ;;
  esac

  return 1
}

failures=0

for repo in "${repos[@]}"; do
  repo_root="$(moonsuite_phase8_repo_root "${WORKSPACE_ROOT}" "${repo}")"
  if ! moonsuite_phase8_require_repo "${WORKSPACE_ROOT}" "${repo}"; then
    failures=$((failures + 1))
    continue
  fi

  repo_failures=0
  while IFS= read -r line; do
    hit="${repo}:${line}"
    if ! is_allowed_hit "${hit}"; then
      echo "legacy cutover path in active source: ${hit}" >&2
      failures=$((failures + 1))
      repo_failures=$((repo_failures + 1))
    fi
  done < <(
    cd "${repo_root}"
    rg -n "${legacy_cutover_pattern}" . \
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
      --glob '!scripts/validate_phase9_cutover.sh' || true
  )

  if [[ "${repo_failures}" -eq 0 ]]; then
    echo "ok ${repo}: no unapproved Phase 9 legacy cutover paths"
  fi

  repo_machine_failures=0
  while IFS= read -r line; do
    hit="${repo}:${line}"
    echo "machine-local absolute path in active source: ${hit}" >&2
    failures=$((failures + 1))
    repo_machine_failures=$((repo_machine_failures + 1))
  done < <(
    cd "${repo_root}"
    rg -n "${machine_local_source_pattern}" . \
      --glob '*.mbt' \
      --glob '!**/*_test.mbt' \
      --glob '!**/*_wbtest.mbt' \
      --glob '!**/docs/**' \
      --glob '!**/_build/**' \
      --glob '!**/.mooncakes/**' \
      --glob '!**/.repos/**' || true
  )

  if [[ "${repo_machine_failures}" -eq 0 ]]; then
    echo "ok ${repo}: no machine-local absolute paths in active MoonBit source"
  fi
done

if [[ "${failures}" -ne 0 ]]; then
  echo "Phase 9 cutover validation failed: ${failures} issue(s)" >&2
  exit 1
fi

echo "Phase 9 cutover validation passed for ${#repos[@]} repo(s)"
