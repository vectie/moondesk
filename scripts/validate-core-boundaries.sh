#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
moondesk_root="$(cd "${script_dir}/.." && pwd)"
moon_bin="${MOON:-/Users/kq/.moon/bin/moon}"
moonclaw_root="${MOONCLAW_ROOT:-${moondesk_root}/../moonclaw}"
moonbook_root="${MOONBOOK_ROOT:-${moondesk_root}/../moonbook}"
moontown_root="${MOONTOWN_ROOT:-${moondesk_root}/../moontown}"

run_moon() {
  local root="$1"
  shift
  echo "+ (cd ${root} && ${moon_bin} $*)"
  (cd "${root}" && "${moon_bin}" "$@")
}

run_if_package_exists() {
  local root="$1"
  local package="$2"
  shift 2
  if [[ -f "${root}/${package}/moon.pkg" ]]; then
    run_moon "${root}" "$@" "${package}" --target native --diagnostic-limit 80
  else
    echo "skip: ${root}/${package}/moon.pkg not found"
  fi
}

require_repo() {
  local root="$1"
  local name="$2"
  if [[ ! -f "${root}/moon.mod" && ! -f "${root}/moon.mod.json" ]]; then
    echo "${name} checkout not found at ${root}" >&2
    echo "Set the corresponding *_ROOT variable to the checkout path or place it next to Moondesk." >&2
    exit 2
  fi
}

require_repo "${moondesk_root}" "moondesk"
require_repo "${moonclaw_root}" "moonclaw"
require_repo "${moonbook_root}" "moonbook"
require_repo "${moontown_root}" "moontown"

"${script_dir}/verify-mooncode-core-sync.sh"

run_if_package_exists "${moondesk_root}" "mooncode/core" test
run_if_package_exists "${moondesk_root}" "internal/mooncode" test
run_if_package_exists "${moondesk_root}" "internal/moonwiki" test

run_if_package_exists "${moonclaw_root}" "mooncode/core" test
run_if_package_exists "${moonclaw_root}" "cmd/daemon" test

run_if_package_exists "${moonbook_root}" "core" check
run_if_package_exists "${moonbook_root}" "wiki" check
run_if_package_exists "${moonbook_root}" "summary" check

run_if_package_exists "${moontown_root}" "src/core" check
run_if_package_exists "${moontown_root}" "src/moonbook_contracts" check
run_if_package_exists "${moontown_root}" "src/standing_watch_contracts" check
run_if_package_exists "${moontown_root}" "src/pdf_evidence_watch" check
run_if_package_exists "${moontown_root}" "src/moonclaw_runtime" check

echo "Core boundary validation passed."
