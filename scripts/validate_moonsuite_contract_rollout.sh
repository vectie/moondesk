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

is_allowed_direct_layout_hit() {
  local hit="$1"

  case "${hit}" in
    moonlib:./moonsuite/layout.mbt:*)
      # MoonLib is the only MoonSuite filesystem contract owner.
      return 0
      ;;
    moondesk:./scripts/desk_mode_browser_smoke.mjs:*|\
    moondesk:./scripts/lepusa_fresh_books_smoke.sh:*|\
    moondesk:./scripts/mooncode_live_runtime_smoke_lib.mjs:*|\
    moonbook:./scripts/fresh-suite-extension-smoke.sh:*|\
    moonclaw:./scripts/fresh-suite-product-home-smoke.sh:*|\
    moontown:./scripts/fresh-suite-writers-smoke.sh:*|\
    moonrobo:./scripts/fresh-suite-product-home-smoke.sh:*|\
    moonfish:./scripts/fresh-suite-product-home-smoke.sh:*|\
    moonmoon:./scripts/fresh-suite-product-home-smoke.sh:*|\
    moonchat:./scripts/fresh-suite-product-home-smoke.sh:*|\
    moonvis:./scripts/fresh-suite-product-home-smoke.sh:*|\
    lepusa:./scripts/fresh-suite-product-home-smoke.sh:*)
      # Smoke scripts assert concrete filesystem effects and absence of stale homes.
      return 0
      ;;
    moonvis:./src/moonsuiteLayout.js:*)
      # MoonVis is frontend-only and mirrors the MoonLib ProductHome shape.
      return 0
      ;;
  esac

  return 1
}

echo "==> MoonLib consumer pins"
bash "${ROOT}/scripts/validate_moonlib_consumer_pins.sh"

moonlib_root="$(moonsuite_phase8_repo_root "${WORKSPACE_ROOT}" "moonlib")"
moondesk_root="${ROOT}"
moonlib_layout="${moonlib_root}/moonsuite/layout.mbt"
moonlib_pkg="${moonlib_root}/moonsuite/moon.pkg"
moonlib_interface="${moonlib_root}/moonsuite/pkg.generated.mbti"
moondesk_layout="${moondesk_root}/internal/moonwiki/moonsuite_layout.mbt"
moondesk_core_paths="${moondesk_root}/core/paths.mbt"

if moonsuite_phase8_require_repo "${WORKSPACE_ROOT}" "moonlib"; then
  require_file "${moonlib_root}/moon.mod"
  require_file "${moonlib_layout}"
  require_file "${moonlib_pkg}"
  require_file "${moonlib_interface}"

  require_contains "${moonlib_root}/moon.mod" "version = \"${EXPECTED_MOONLIB_VERSION}\"" "MoonLib ${EXPECTED_MOONLIB_VERSION} source version"
  require_contains "${moonlib_layout}" "pub(all) struct ProductHome" "shared ProductHome type"
  require_contains "${moonlib_layout}" "pub fn suite_root_for_workspace_root" "workspace-root suite normalization"
  require_contains "${moonlib_layout}" "pub fn product_home_for_workspace_root" "workspace-root ProductHome constructor"
  require_contains "${moonlib_layout}" "pub fn product_artifact_for_workspace_root" "workspace-root product artifact constructor"
  require_contains "${moonlib_layout}" "pub fn product_accepted_output_path_for_workspace_root" "workspace-root accepted output constructor"
  require_contains "${moonlib_layout}" "pub fn product_registry" "shared product registry constructor"
  require_contains "${moonlib_layout}" "pub fn default_product_ids" "shared default product ids"
  require_contains "${moonlib_interface}" "pub fn product_home_for_workspace_root" "public ProductHome interface"
  require_contains "${moonlib_interface}" "pub fn product_registry" "public product registry interface"

  for product_id in "${MOONSUITE_PHASE8_PRODUCTS[@]}"; do
    require_contains "${moonlib_layout}" "\"${product_id}\"" "MoonLib default product ${product_id}"
  done
fi

require_file "${moondesk_root}/moon.mod"
require_file "${moondesk_layout}"
require_file "${moondesk_core_paths}"
require_contains "${moondesk_root}/moon.mod" "\"vectie/moonlib@${EXPECTED_MOONLIB_VERSION}\"" "Moondesk MoonLib ${EXPECTED_MOONLIB_VERSION} dependency"
require_contains "${moondesk_layout}" "@moonsuite.suite_root_for_workspace_root" "MoonWiki suite-root delegation"
require_contains "${moondesk_layout}" "@moonsuite.product_home_for_workspace_root" "MoonWiki ProductHome delegation"
require_contains "${moondesk_layout}" "@moonsuite.product_artifact_for_workspace_root" "MoonWiki product artifact delegation"
require_contains "${moondesk_layout}" "@moonsuite.default_product_ids()" "MoonWiki default product delegation"
require_contains "${moondesk_layout}" "@moonsuite.product_registry" "MoonWiki registry delegation"
require_contains "${moondesk_core_paths}" "@moonsuite.product_display_artifact" "core product display delegation"
require_contains "${moondesk_core_paths}" "@moonsuite.suite_root_for_workspace_root" "core suite-root delegation"

direct_layout_pattern='"\.moonsuite/products|"\.tmp/products'
repos=("${MOONSUITE_PHASE8_SOURCE_REPOS[@]}")

for repo in "${repos[@]}"; do
  repo_root="$(moonsuite_phase8_repo_root "${WORKSPACE_ROOT}" "${repo}")"
  if ! moonsuite_phase8_require_repo "${WORKSPACE_ROOT}" "${repo}"; then
    failures=$((failures + 1))
    continue
  fi

  repo_direct_failures=0
  while IFS= read -r line; do
    hit="${repo}:${line}"
    if ! is_allowed_direct_layout_hit "${hit}"; then
      fail "direct MoonSuite product-home formula outside contract owner: ${hit}"
      repo_direct_failures=$((repo_direct_failures + 1))
    fi
  done < <(
    cd "${repo_root}"
    rg -n "${direct_layout_pattern}" . \
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
      --glob '!scripts/validate_moonsuite_contract_rollout.sh' || true
  )

  if [[ "${repo_direct_failures}" -eq 0 ]]; then
    echo "ok ${repo}: no unapproved direct MoonSuite product-home formulas"
  fi
done

if [[ "${failures}" -ne 0 ]]; then
  echo "MoonSuite filesystem contract rollout validation failed: ${failures} issue(s)" >&2
  exit 1
fi

echo "MoonSuite filesystem contract rollout validation passed for ${#repos[@]} repo(s)"
