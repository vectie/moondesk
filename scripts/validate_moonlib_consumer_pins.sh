#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORKSPACE_ROOT="$(cd "${ROOT}/.." && pwd)"
source "${ROOT}/scripts/moonsuite_phase8_inventory.sh"
EXPECTED_VERSION="${MOONLIB_VERSION:-0.1.8}"
EXPECTED_IMPORT="vectie/moonlib@${EXPECTED_VERSION}"

repos=("${MOONSUITE_PHASE8_MOONLIB_CONSUMER_REPOS[@]}")

failures=0

for repo in "${repos[@]}"; do
  repo_root="$(moonsuite_phase8_repo_root "${WORKSPACE_ROOT}" "${repo}")"
  mod_file="${repo_root}/moon.mod"

  if ! moonsuite_phase8_require_repo "${WORKSPACE_ROOT}" "${repo}"; then
    failures=$((failures + 1))
    continue
  fi

  if [[ ! -f "${mod_file}" ]]; then
    echo "missing moon.mod: ${mod_file}" >&2
    failures=$((failures + 1))
    continue
  fi

  if ! grep -q "\"${EXPECTED_IMPORT}\"" "${mod_file}"; then
    echo "stale or missing MoonLib pin in ${repo}/moon.mod; expected ${EXPECTED_IMPORT}" >&2
    grep -n 'vectie/moonlib@' "${mod_file}" >&2 || true
    failures=$((failures + 1))
    continue
  fi

  if grep -n 'vectie/moonlib@' "${mod_file}" | grep -v "${EXPECTED_IMPORT}" >&2; then
    echo "unexpected extra MoonLib pin in ${repo}/moon.mod" >&2
    failures=$((failures + 1))
    continue
  fi

  echo "ok ${repo}: ${EXPECTED_IMPORT}"
done

if [[ "${failures}" -ne 0 ]]; then
  echo "MoonLib consumer pin validation failed: ${failures} repo(s)" >&2
  exit 1
fi

echo "MoonLib consumer pin validation passed for ${#repos[@]} repo(s)"
