#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORKSPACE_ROOT="$(cd "${ROOT}/.." && pwd)"
MOON_BIN="${MOON_BIN:-/Users/kq/.moon/bin/moon}"

run_gate() {
  local label="$1"
  local repo="$2"
  local script="$3"
  local path="${WORKSPACE_ROOT}/${repo}/${script}"

  if [[ ! -x "${path}" ]]; then
    echo "missing executable smoke gate for ${label}: ${path}" >&2
    exit 1
  fi

  echo "==> ${label}"
  (
    cd "${WORKSPACE_ROOT}/${repo}"
    MOON_BIN="${MOON_BIN}" "${path}"
  )
}

run_zsh_gate() {
  local label="$1"
  local repo="$2"
  local script="$3"
  local path="${WORKSPACE_ROOT}/${repo}/${script}"

  if [[ ! -x "${path}" ]]; then
    echo "missing executable smoke gate for ${label}: ${path}" >&2
    exit 1
  fi

  echo "==> ${label}"
  (
    cd "${WORKSPACE_ROOT}/${repo}"
    MOON_BIN="${MOON_BIN}" zsh "${path}"
  )
}

run_local_gate() {
  local label="$1"
  local script="$2"
  local path="${ROOT}/${script}"

  if [[ ! -x "${path}" ]]; then
    echo "missing executable smoke gate for ${label}: ${path}" >&2
    exit 1
  fi

  echo "==> ${label}"
  (
    cd "${ROOT}"
    MOON_BIN="${MOON_BIN}" "${path}"
  )
}

run_gate "Moontown fresh-suite writers" "moontown" "scripts/fresh-suite-writers-smoke.sh"
run_gate "MoonClaw fresh-suite product home" "moonclaw" "scripts/fresh-suite-product-home-smoke.sh"
run_gate "MoonBook fresh-suite extension" "moonbook" "scripts/fresh-suite-extension-smoke.sh"
run_zsh_gate "MoonRobo fresh-suite product home" "moonrobo" "scripts/fresh-suite-product-home-smoke.sh"
run_zsh_gate "MoonFish fresh-suite product home" "moonfish" "scripts/fresh-suite-product-home-smoke.sh"
run_zsh_gate "MoonMoon fresh-suite product home" "moonmoon" "scripts/fresh-suite-product-home-smoke.sh"
run_zsh_gate "MoonChat fresh-suite product home" "moonchat" "scripts/fresh-suite-product-home-smoke.sh"
run_zsh_gate "MoonVis fresh-suite product home" "moonvis" "scripts/fresh-suite-product-home-smoke.sh"
run_local_gate "Lepusa fresh-books" "scripts/lepusa_fresh_books_smoke.sh"

echo "Fresh MoonSuite product smoke passed"
