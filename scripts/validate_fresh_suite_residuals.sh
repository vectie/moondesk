#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORKSPACE_ROOT="$(cd "${ROOT}/.." && pwd)"
source "${ROOT}/scripts/moonsuite_phase8_inventory.sh"

repos=("${MOONSUITE_PHASE8_SOURCE_REPOS[@]}")

legacy_hidden_home_pattern='"\.(moontown|moonclaw|moondesk|moonbook|moonwiki|mooncode|moonfish|moonmoon|moonchat|moonvis|lepusa|rabbita|bookkeeper)(/|"|$)'

is_allowed_hit() {
  local hit="$1"

  case "${hit}" in
    moonstat:./suite.mbt:*)
      # MoonStat is the drift detector. These strings are probe signatures,
      # paired with canonical MoonLib paths in the same records.
      return 0
      ;;
    moondesk:./scripts/desk_mode_browser_smoke.mjs:*)
      # Browser smoke asserts the old projection path is not created.
      return 0
      ;;
    moondesk:./scripts/lepusa_fresh_books_smoke.sh:*)
      # Lepusa smoke asserts legacy product roots are not created.
      return 0
      ;;
    moonbook:./internal/moonwiki/server.mbt:*'assert_false(live_reload_token_file.has_prefix(".moonbook"))'*)
      # MoonBook keeps a package-local test in the implementation file.
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
      echo "legacy hidden product home in active source: ${hit}" >&2
      failures=$((failures + 1))
      repo_failures=$((repo_failures + 1))
    fi
  done < <(
    cd "${repo_root}"
    rg -n "${legacy_hidden_home_pattern}" . \
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
      --glob '!scripts/validate_fresh_suite_residuals.sh' || true
  )

  if [[ "${repo_failures}" -eq 0 ]]; then
    echo "ok ${repo}: no unapproved legacy hidden-home source strings"
  fi
done

if [[ "${failures}" -ne 0 ]]; then
  echo "Fresh MoonSuite residual validation failed: ${failures} issue(s)" >&2
  exit 1
fi

echo "Fresh MoonSuite residual validation passed for ${#repos[@]} repo(s)"
