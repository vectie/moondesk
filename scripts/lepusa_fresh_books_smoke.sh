#!/usr/bin/env bash
set -euo pipefail

ROOT="$(mktemp -d "${TMPDIR:-/tmp}/moondesk-lepusa-books.XXXXXX")"
OUT="${ROOT}/lepusa"
PORT="${PORT:-$((5600 + RANDOM % 1000))}"
BOOK_ROOT="${ROOT}/books/research-alpha"
LIVE_PROJECT="${OUT}/live-project/lepusa.json"
MANIFEST="${OUT}/moondesk-lepusa.app/Contents/Resources/lepusa/runtime.json"
SIDECAR="${OUT}/moondesk-lepusa.app/Contents/MacOS/moondesk-sidecar"

mkdir -p \
  "${BOOK_ROOT}/wiki" \
  "${BOOK_ROOT}/raw" \
  "${BOOK_ROOT}/book/site/generated/assets" \
  "${ROOT}/.moonsuite/products/moondesk" \
  "${ROOT}/.tmp/products/moondesk"

printf '{"id":"research-alpha","name":"Research Alpha"}\n' >"${BOOK_ROOT}/book.json"
printf '# Research Alpha\n\nFresh Lepusa smoke fixture.\n' >"${BOOK_ROOT}/wiki/index.md"
printf 'alpha evidence\n' >"${BOOK_ROOT}/raw/evidence.txt"
printf '{"title":"Research Alpha","projection_scope":"public"}\n' >"${BOOK_ROOT}/book/moonbook-ui-state.json"
printf '<!doctype html><title>Research Alpha</title><main>Fresh Lepusa generated site</main>\n' >"${BOOK_ROOT}/book/site/generated/index.html"
printf 'main { color: #123456; }\n' >"${BOOK_ROOT}/book/site/generated/assets/site.css"

moon run cmd/main --target native -- lepusa live-smoke macos --strict \
  --out "${OUT}" \
  --serve-port "${PORT}" \
  --workspace-root "${ROOT}" \
  --ui ui/rabbita-desk/dist

for path in "${LIVE_PROJECT}" "${MANIFEST}" "${SIDECAR}"; do
  if [[ ! -e "${path}" ]]; then
    echo "expected Lepusa smoke output missing: ${path}" >&2
    exit 1
  fi
done

if [[ ! -x "${SIDECAR}" ]]; then
  echo "Moondesk sidecar is not executable: ${SIDECAR}" >&2
  exit 1
fi

node - "${LIVE_PROJECT}" "${MANIFEST}" "${ROOT}" "${SIDECAR}" "${PORT}" <<'NODE'
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

for path in "${BOOK_ROOT}/book/moonbook-ui-state.json" "${BOOK_ROOT}/book/site/generated/index.html"; do
  if [[ ! -f "${path}" ]]; then
    echo "expected fresh MoonBook projection file missing: ${path}" >&2
    exit 1
  fi
done

if [[ -e "${ROOT}/.moontown/books/research-alpha" ]]; then
  echo "legacy .moontown book root was created" >&2
  exit 1
fi

echo "Lepusa fresh-books smoke passed on ${ROOT}"
