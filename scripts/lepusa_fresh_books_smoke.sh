#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(CDPATH= cd -- "${SCRIPT_DIR}/.." && pwd)"
ROOT="$(mktemp -d "${TMPDIR:-/tmp}/moondesk-lepusa-books.XXXXXX")"
MOON_BIN="${MOON:-moon}"
SCENARIO="${1:-all}"
UI_DIST="${REPO_ROOT}/ui/rabbita-desk/dist"

case "${SCENARIO}" in
  all | populated | empty)
    ;;
  *)
    echo "usage: $0 [all|populated|empty]" >&2
    exit 2
    ;;
esac

random_port() {
  printf '%s\n' "$((5600 + RANDOM % 1000))"
}

seed_populated_root() {
  local suite_root="$1"
  local book_root="${suite_root}/books/research-alpha"

  mkdir -p \
    "${book_root}/wiki" \
    "${book_root}/raw" \
    "${book_root}/book/site/generated/assets"

  printf '{"id":"research-alpha","name":"Research Alpha"}\n' >"${book_root}/book.json"
  printf '# Research Alpha\n\nFresh Lepusa smoke fixture.\n' >"${book_root}/wiki/index.md"
  printf 'alpha evidence\n' >"${book_root}/raw/evidence.txt"
  printf '{"title":"Research Alpha","projection_scope":"public"}\n' >"${book_root}/book/moonbook-ui-state.json"
  printf '<!doctype html><title>Research Alpha</title><main>Fresh Lepusa generated site</main>\n' >"${book_root}/book/site/generated/index.html"
  printf 'main { color: #123456; }\n' >"${book_root}/book/site/generated/assets/site.css"
}

run_lepusa_smoke() {
  local label="$1"
  local suite_root="$2"
  local port
  local out
  local live_project
  local manifest
  local sidecar

  port="$(random_port)"
  out="${suite_root}/lepusa"
  live_project="${out}/live-project/lepusa.json"
  manifest="${out}/moondesk-lepusa.app/Contents/Resources/lepusa/runtime.json"
  sidecar="${out}/moondesk-lepusa.app/Contents/MacOS/moondesk-sidecar"

  mkdir -p "${suite_root}"

  "${MOON_BIN}" run cmd/main --target native -- lepusa live-smoke macos --strict \
    --out "${out}" \
    --serve-port "${port}" \
    --workspace-root "${suite_root}" \
    --ui "${UI_DIST}"

  for path in "${live_project}" "${manifest}" "${sidecar}"; do
    if [[ ! -e "${path}" ]]; then
      echo "expected Lepusa ${label} smoke output missing: ${path}" >&2
      exit 1
    fi
  done

  if [[ ! -x "${sidecar}" ]]; then
    echo "Moondesk sidecar is not executable: ${sidecar}" >&2
    exit 1
  fi

  probe_bundled_sidecar "${label}" "${sidecar}" "${suite_root}" "$(random_port)"
  node - "${live_project}" "${manifest}" "${suite_root}" "${sidecar}" "${port}" <<'NODE'
const fs = require('node:fs')
const path = require('node:path')
const [liveProjectPath, manifestPath, root, sidecar, port] = process.argv.slice(2)
const expectedRoot = path.resolve(root)
const expectedSidecar = path.resolve(sidecar)

function fail(message) {
  console.error(message)
  process.exit(1)
}

function normalizeCommand(command) {
  return command.map(item => typeof item === 'string' && item.startsWith('/') ? path.resolve(item) : item)
}

const liveProject = JSON.parse(fs.readFileSync(liveProjectPath, 'utf8'))
const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'))
const liveCommand = normalizeCommand(liveProject?.window?.source?.localhost?.command ?? [])
if (!liveCommand.includes(expectedSidecar) || !liveCommand.includes('serve') || !liveCommand.includes(expectedRoot)) {
  fail(`live project does not launch bundled sidecar against fresh root: ${JSON.stringify(liveCommand)}`)
}

const services = manifest?.runtime?.localServices ?? []
const service = services.find(item => item.name === 'main')
if (!service) {
  fail('runtime manifest is missing the main local service')
}
const serviceCommand = normalizeCommand(service.command ?? [])
if (!serviceCommand.includes(expectedSidecar) || !serviceCommand.includes('serve') || !serviceCommand.includes(expectedRoot)) {
  fail(`runtime service does not launch bundled sidecar against fresh root: ${JSON.stringify(serviceCommand)}`)
}
const expectedReadiness = `http://127.0.0.1:${port}/__moondesk_health`
if (service.readinessUrl !== expectedReadiness) {
  fail(`runtime service readiness URL mismatch: ${service.readinessUrl}`)
}
NODE

  assert_bootstrap_layout "${label}" "${suite_root}"
}

probe_bundled_sidecar() {
  local label="$1"
  local sidecar="$2"
  local suite_root="$3"
  local port="$4"
  local log="${suite_root}/lepusa-sidecar-${label}.log"
  local pid=""

  "${sidecar}" serve "${suite_root}" --ui "${UI_DIST}" --host 127.0.0.1 --port "${port}" >"${log}" 2>&1 &
  pid="$!"
  for _ in {1..200}; do
    if curl -fsS "http://127.0.0.1:${port}/__moondesk_health" >/dev/null 2>&1; then
      break
    fi
    sleep 0.1
  done

  if ! curl -fsS "http://127.0.0.1:${port}/__moondesk_health" >/dev/null 2>&1; then
    echo "Lepusa ${label} bundled sidecar did not become healthy; log follows" >&2
    cat "${log}" >&2
    kill "${pid}" 2>/dev/null || true
    wait "${pid}" 2>/dev/null || true
    exit 1
  fi

  kill "${pid}" 2>/dev/null || true
  wait "${pid}" 2>/dev/null || true
}

assert_bootstrap_layout() {
  local label="$1"
  local suite_root="$2"
  local required_paths=(
    "books"
    "inbox"
    "exports"
    ".tmp"
    ".moonsuite"
    ".moonsuite/suite.json"
    ".moonsuite/product-registry.json"
    ".moonsuite/products/moondesk"
    ".moonsuite/products/moonbook"
    ".moonsuite/products/mooncode"
    ".moonsuite/products/moonclaw"
    ".moonsuite/products/moontown"
    ".moonsuite/products/lepusa"
    ".moonsuite/products/rabbita"
  )

  for path in "${required_paths[@]}"; do
    if [[ ! -e "${suite_root}/${path}" ]]; then
      echo "Lepusa ${label} smoke did not bootstrap ${path}" >&2
      exit 1
    fi
  done

  for legacy_path in ".moontown" ".moonclaw" ".moonbook" ".moonclaw-worktrees"; do
    if [[ -e "${suite_root}/${legacy_path}" ]]; then
      echo "Lepusa ${label} smoke created legacy root ${legacy_path}" >&2
      exit 1
    fi
  done
}

assert_populated_outputs() {
  local suite_root="$1"
  local book_root="${suite_root}/books/research-alpha"

  for path in "${book_root}/book/moonbook-ui-state.json" "${book_root}/book/site/generated/index.html"; do
    if [[ ! -f "${path}" ]]; then
      echo "expected fresh MoonBook projection file missing: ${path}" >&2
      exit 1
    fi
  done
}

assert_empty_outputs() {
  local suite_root="$1"

  if find "${suite_root}/books" -mindepth 1 -maxdepth 1 | grep -q .; then
    echo "Lepusa empty smoke should keep an empty books library until user creates a MoonBook" >&2
    exit 1
  fi
}

if [[ "${SCENARIO}" == "all" || "${SCENARIO}" == "populated" ]]; then
  POPULATED_ROOT="${ROOT}/populated"
  seed_populated_root "${POPULATED_ROOT}"
  run_lepusa_smoke "populated" "${POPULATED_ROOT}"
  assert_populated_outputs "${POPULATED_ROOT}"
  echo "Lepusa populated fresh-books smoke passed on ${POPULATED_ROOT}"
fi

if [[ "${SCENARIO}" == "all" || "${SCENARIO}" == "empty" ]]; then
  EMPTY_ROOT="${ROOT}/empty"
  run_lepusa_smoke "empty" "${EMPTY_ROOT}"
  assert_empty_outputs "${EMPTY_ROOT}"
  echo "Lepusa empty fresh-books smoke passed on ${EMPTY_ROOT}"
fi
