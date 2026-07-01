#!/usr/bin/env bash
set -euo pipefail

ROOT="$(mktemp -d "${TMPDIR:-/tmp}/moondesk-desk-browser.XXXXXX")"
PORT="${PORT:-$((5400 + RANDOM % 1000))}"
CDP_PORT="${CDP_PORT:-$((9400 + RANDOM % 1000))}"
HOST="127.0.0.1"
BASE="http://${HOST}:${PORT}"
LOG="${ROOT}/server.log"
CHROME_LOG="${ROOT}/chrome.log"
CHROME_PROFILE="${ROOT}/chrome-profile"
CHROME="${CHROME:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"
PID=""
CHROME_PID=""

cleanup() {
  if [[ -n "${CHROME_PID}" ]] && kill -0 "${CHROME_PID}" 2>/dev/null; then
    kill "${CHROME_PID}" 2>/dev/null || true
    wait "${CHROME_PID}" 2>/dev/null || true
  fi
  if [[ -n "${PID}" ]] && kill -0 "${PID}" 2>/dev/null; then
    kill "${PID}" 2>/dev/null || true
    wait "${PID}" 2>/dev/null || true
  fi
}
trap cleanup EXIT

if [[ ! -x "${CHROME}" ]]; then
  echo "Chrome executable not found: ${CHROME}" >&2
  exit 1
fi

mkdir -p \
  "${ROOT}/books/research-alpha/wiki/notes" \
  "${ROOT}/books/research-alpha/raw" \
  "${ROOT}/books/research-alpha/.git" \
  "${ROOT}/books/research-beta/wiki" \
  "${ROOT}/books/research-beta/raw" \
  "${ROOT}/books/research-gamma/wiki" \
  "${ROOT}/books/research-gamma/raw" \
  "${ROOT}/books/research-recovered/wiki"

printf '{"id":"research-alpha","name":"Research Alpha"}\n' >"${ROOT}/books/research-alpha/book.json"
printf '{"id":"research-beta","name":"Research Beta"}\n' >"${ROOT}/books/research-beta/book.json"
printf '{"id":"research-gamma","name":"Research Gamma"}\n' >"${ROOT}/books/research-gamma/book.json"
printf '# Alpha Desk\n\nBrowser smoke fixture.\n' >"${ROOT}/books/research-alpha/wiki/index.md"
printf 'alpha note\n' >"${ROOT}/books/research-alpha/wiki/notes/alpha.md"
printf 'raw evidence\n' >"${ROOT}/books/research-alpha/raw/evidence.txt"
printf 'hidden config\n' >"${ROOT}/books/research-alpha/.git/config"
printf 'mac noise\n' >"${ROOT}/books/research-alpha/.DS_Store"
printf '# Beta Desk\n' >"${ROOT}/books/research-beta/wiki/index.md"
printf '# Gamma Desk\n' >"${ROOT}/books/research-gamma/wiki/index.md"
printf '# Recovered Desk\n' >"${ROOT}/books/research-recovered/wiki/index.md"

moon run cmd/main -- serve "${ROOT}" --ui ui/rabbita-desk/dist --host "${HOST}" --port "${PORT}" >"${LOG}" 2>&1 &
PID="$!"

for _ in {1..200}; do
  if curl -fsS "${BASE}/__moondesk_health" >/dev/null 2>&1; then
    break
  fi
  sleep 0.1
done

if ! curl -fsS "${BASE}/__moondesk_health" >/dev/null 2>&1; then
  echo "server did not become healthy; log follows" >&2
  cat "${LOG}" >&2
  exit 1
fi

"${CHROME}" \
  --headless=new \
  --disable-gpu \
  --no-first-run \
  --no-default-browser-check \
  --user-data-dir="${CHROME_PROFILE}" \
  --remote-debugging-address="${HOST}" \
  --remote-debugging-port="${CDP_PORT}" \
  about:blank >"${CHROME_LOG}" 2>&1 &
CHROME_PID="$!"

for _ in {1..200}; do
  if curl -fsS "http://${HOST}:${CDP_PORT}/json/version" >/dev/null 2>&1; then
    break
  fi
  sleep 0.1
done

if ! curl -fsS "http://${HOST}:${CDP_PORT}/json/version" >/dev/null 2>&1; then
  echo "Chrome DevTools endpoint did not become healthy; log follows" >&2
  cat "${CHROME_LOG}" >&2
  exit 1
fi

node scripts/desk_mode_browser_smoke.mjs "${BASE}" "${CDP_PORT}" "${ROOT}"
echo "Desk browser smoke passed on ${BASE}"
