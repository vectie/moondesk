#!/usr/bin/env bash
set -euo pipefail

HOST="127.0.0.1"
CHROME="${CHROME:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"
MOON_BIN="${MOON:-moon}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MOONCLAW_ROOT="${MOONCLAW_ROOT:-$(cd "${REPO_ROOT}/.." && pwd)/moonclaw}"
UI_DIST="${UI_DIST:-ui/rabbita-desk/dist}"
ROOT="$(mktemp -d "${TMPDIR:-/tmp}/moondesk-desk-browser.XXXXXX")"
SCENARIO="${1:-all}"
PIDS=()

cleanup() {
  for pid in "${PIDS[@]}"; do
    if [[ -n "${pid}" ]] && kill -0 "${pid}" 2>/dev/null; then
      kill "${pid}" 2>/dev/null || true
      wait "${pid}" 2>/dev/null || true
    fi
  done
}
trap cleanup EXIT

case "${SCENARIO}" in
  all | full | empty | quickstart | keyboard | keyboard-transients | accessibility | screen-reader | capability | capability-responsive | capability-scale)
    ;;
  *)
    echo "usage: $0 [all|full|empty|quickstart|keyboard|keyboard-transients|accessibility|screen-reader|capability|capability-responsive|capability-scale]" >&2
    exit 2
    ;;
esac

if [[ ! -x "${CHROME}" ]]; then
  echo "Chrome executable not found: ${CHROME}" >&2
  exit 1
fi

create_full_fixture() {
  local fixture_root="$1"
  mkdir -p \
    "${fixture_root}/books/research-alpha/wiki/notes" \
    "${fixture_root}/books/research-alpha/raw" \
    "${fixture_root}/books/research-alpha/book/site/generated/assets" \
    "${fixture_root}/books/research-alpha/.git" \
    "${fixture_root}/books/research-beta/wiki" \
    "${fixture_root}/books/research-beta/raw" \
    "${fixture_root}/books/research-gamma/wiki" \
    "${fixture_root}/books/research-gamma/raw" \
    "${fixture_root}/books/research-recovered/wiki"

  printf '{"id":"research-alpha","name":"Research Alpha"}\n' >"${fixture_root}/books/research-alpha/book.json"
  printf '{"id":"research-beta","name":"Research Beta"}\n' >"${fixture_root}/books/research-beta/book.json"
  printf '{"id":"research-gamma","name":"Research Gamma"}\n' >"${fixture_root}/books/research-gamma/book.json"
  printf '# Alpha Desk\n\nBrowser smoke fixture.\n' >"${fixture_root}/books/research-alpha/wiki/index.md"
  printf 'alpha note\n' >"${fixture_root}/books/research-alpha/wiki/notes/alpha.md"
  printf 'raw evidence\n' >"${fixture_root}/books/research-alpha/raw/evidence.txt"
  printf '{"title":"Research Alpha","projection_scope":"public"}\n' >"${fixture_root}/books/research-alpha/book/moonbook-ui-state.json"
  printf '<!doctype html><title>Research Alpha Site</title><main>Research Alpha generated site</main>\n' >"${fixture_root}/books/research-alpha/book/site/generated/index.html"
  printf 'main { color: #123456; }\n' >"${fixture_root}/books/research-alpha/book/site/generated/assets/site.css"
  printf 'hidden config\n' >"${fixture_root}/books/research-alpha/.git/config"
  printf 'mac noise\n' >"${fixture_root}/books/research-alpha/.DS_Store"
  printf '# Beta Desk\n' >"${fixture_root}/books/research-beta/wiki/index.md"
  printf '# Gamma Desk\n' >"${fixture_root}/books/research-gamma/wiki/index.md"
  printf '# Recovered Desk\n' >"${fixture_root}/books/research-recovered/wiki/index.md"
}

random_port() {
  local base="$1"
  printf '%s\n' "$((base + RANDOM % 1000))"
}

start_moonclaw_for_fixture() {
  local fixture_root="$1"
  local moonclaw_log="${fixture_root}/moonclaw.log"
  local product_dir="${fixture_root}/.moonsuite/products/moonclaw"
  local service_path="${product_dir}/service.json"
  local daemon_path="${product_dir}/daemon.json"

  if [[ ! -f "${MOONCLAW_ROOT}/moon.mod" ]]; then
    echo "MoonClaw checkout not found: ${MOONCLAW_ROOT}" >&2
    exit 1
  fi

  mkdir -p "${product_dir}"
  node -e '
const fs = require("node:fs");
const [servicePath, moonBin, moonclawRoot, fixtureRoot] = process.argv.slice(1);
fs.writeFileSync(servicePath, `${JSON.stringify({
  kind: "moondesk-moonclaw-service.v1",
  cwd: moonclawRoot,
  daemon: {
    command: moonBin,
    args: ["run", "cmd/main", "--", "daemon", "--port", "0", "--serve", fixtureRoot],
  },
}, null, 2)}\n`);
' "${service_path}" "${MOON_BIN}" "${MOONCLAW_ROOT}" "${fixture_root}"

  (cd "${MOONCLAW_ROOT}" && "${MOON_BIN}" run cmd/main -- daemon --port 0 --serve "${fixture_root}") >"${moonclaw_log}" 2>&1 &
  local moonclaw_pid="$!"
  PIDS+=("${moonclaw_pid}")

  for _ in {1..400}; do
    if node -e '
const fs = require("node:fs");
const path = process.argv[1];
try {
  const info = JSON.parse(fs.readFileSync(path, "utf8"));
  process.exit(info.port > 0 && info.pid > 0 ? 0 : 1);
} catch {
  process.exit(1);
}
' "${daemon_path}" >/dev/null 2>&1; then
      break
    fi
    sleep 0.1
  done

  if ! node -e '
const fs = require("node:fs");
const path = process.argv[1];
try {
  const info = JSON.parse(fs.readFileSync(path, "utf8"));
  process.exit(info.port > 0 && info.pid > 0 ? 0 : 1);
} catch {
  process.exit(1);
}
' "${daemon_path}" >/dev/null 2>&1; then
    echo "MoonClaw daemon did not become healthy; log follows" >&2
    cat "${moonclaw_log}" >&2
    exit 1
  fi

  local moonclaw_port
  moonclaw_port="$(node -e 'const fs = require("node:fs"); console.log(JSON.parse(fs.readFileSync(process.argv[1], "utf8")).port)' "${daemon_path}")"
  for _ in {1..600}; do
    if curl -fsS "http://localhost:${moonclaw_port}/v1/code/capabilities" >/dev/null 2>&1; then
      return
    fi
    sleep 0.1
  done

  echo "MoonClaw native capabilities did not become healthy; log follows" >&2
  cat "${moonclaw_log}" >&2
  exit 1
}

run_browser_scenario() {
  local scenario="$1"
  local fixture_root="$2"
  local port
  local cdp_port
  if [[ "${SCENARIO}" == "all" ]]; then
    port="$(random_port 5400)"
    cdp_port="$(random_port 9400)"
  else
    port="${PORT:-$(random_port 5400)}"
    cdp_port="${CDP_PORT:-$(random_port 9400)}"
  fi
  local base="http://${HOST}:${port}"
  local log="${fixture_root}/server.log"
  local chrome_log="${fixture_root}/chrome.log"
  local chrome_profile="${fixture_root}/chrome-profile"
  local pid=""
  local chrome_pid=""

  if [[ "${scenario}" == "full" || "${scenario}" == "quickstart" || "${scenario}" == "keyboard-transients" || "${scenario}" == "accessibility" || "${scenario}" == "screen-reader" || "${scenario}" == "capability" || "${scenario}" == "capability-responsive" || "${scenario}" == "capability-scale" ]]; then
    start_moonclaw_for_fixture "${fixture_root}"
  fi

  "${MOON_BIN}" run cmd/main -- serve "${fixture_root}" --ui "${UI_DIST}" --host "${HOST}" --port "${port}" >"${log}" 2>&1 &
  pid="$!"
  PIDS+=("${pid}")

  for _ in {1..200}; do
    if curl -fsS "${base}/__moondesk_health" >/dev/null 2>&1; then
      break
    fi
    sleep 0.1
  done

  if ! curl -fsS "${base}/__moondesk_health" >/dev/null 2>&1; then
    echo "server did not become healthy for ${scenario}; log follows" >&2
    cat "${log}" >&2
    exit 1
  fi

  "${CHROME}" \
    --headless=new \
    --disable-gpu \
    --no-first-run \
    --no-default-browser-check \
    --lang=en-US \
    --user-data-dir="${chrome_profile}" \
    --remote-debugging-address="${HOST}" \
    --remote-debugging-port="${cdp_port}" \
    about:blank >"${chrome_log}" 2>&1 &
  chrome_pid="$!"
  PIDS+=("${chrome_pid}")

  for _ in {1..200}; do
    if curl -fsS "http://${HOST}:${cdp_port}/json/version" >/dev/null 2>&1; then
      break
    fi
    sleep 0.1
  done

  if ! curl -fsS "http://${HOST}:${cdp_port}/json/version" >/dev/null 2>&1; then
    echo "Chrome DevTools endpoint did not become healthy for ${scenario}; log follows" >&2
    cat "${chrome_log}" >&2
    exit 1
  fi

  if [[ "${scenario}" == "quickstart" ]]; then
    node scripts/desk_mode_browser_smoke.mjs \
      "${base}" "${cdp_port}" "${fixture_root}" quickstart-before-restart

    if kill -0 "${pid}" 2>/dev/null; then
      kill "${pid}" 2>/dev/null || true
      wait "${pid}" 2>/dev/null || true
    fi

    : >"${log}"
    "${MOON_BIN}" run cmd/main -- serve "${fixture_root}" --ui "${UI_DIST}" --host "${HOST}" --port "${port}" >"${log}" 2>&1 &
    pid="$!"
    PIDS+=("${pid}")

    for _ in {1..200}; do
      if curl -fsS "${base}/__moondesk_health" >/dev/null 2>&1; then
        break
      fi
      sleep 0.1
    done
    if ! curl -fsS "${base}/__moondesk_health" >/dev/null 2>&1; then
      echo "server did not recover for quickstart relaunch; log follows" >&2
      cat "${log}" >&2
      exit 1
    fi

    node scripts/desk_mode_browser_smoke.mjs \
      "${base}" "${cdp_port}" "${fixture_root}" quickstart-after-restart
  else
    node scripts/desk_mode_browser_smoke.mjs "${base}" "${cdp_port}" "${fixture_root}" "${scenario}"
  fi
  echo "Desk browser ${scenario} smoke passed on ${base}"

  if kill -0 "${chrome_pid}" 2>/dev/null; then
    kill "${chrome_pid}" 2>/dev/null || true
    wait "${chrome_pid}" 2>/dev/null || true
  fi
  if kill -0 "${pid}" 2>/dev/null; then
    kill "${pid}" 2>/dev/null || true
    wait "${pid}" 2>/dev/null || true
  fi
}

if [[ "${SCENARIO}" == "all" || "${SCENARIO}" == "full" || "${SCENARIO}" == "keyboard" ]]; then
  FULL_ROOT="${ROOT}/full"
  create_full_fixture "${FULL_ROOT}"
  run_browser_scenario "full" "${FULL_ROOT}"
fi

if [[ "${SCENARIO}" == "keyboard-transients" ]]; then
  KEYBOARD_TRANSIENTS_ROOT="${ROOT}/keyboard-transients"
  create_full_fixture "${KEYBOARD_TRANSIENTS_ROOT}"
  run_browser_scenario "keyboard-transients" "${KEYBOARD_TRANSIENTS_ROOT}"
fi

if [[ "${SCENARIO}" == "all" || "${SCENARIO}" == "accessibility" ]]; then
  ACCESSIBILITY_ROOT="${ROOT}/accessibility"
  create_full_fixture "${ACCESSIBILITY_ROOT}"
  run_browser_scenario "accessibility" "${ACCESSIBILITY_ROOT}"
fi

# Screen-reader proof must never reuse another scenario's daemon, browser, or
# mutated fixture: run_browser_scenario owns a fresh runtime for this full fixture.
if [[ "${SCENARIO}" == "all" || "${SCENARIO}" == "screen-reader" ]]; then
  SCREEN_READER_ROOT="${ROOT}/screen-reader"
  create_full_fixture "${SCREEN_READER_ROOT}"
  run_browser_scenario "screen-reader" "${SCREEN_READER_ROOT}"
fi

if [[ "${SCENARIO}" == "all" || "${SCENARIO}" == "capability" ]]; then
  CAPABILITY_ROOT="${ROOT}/capability"
  create_full_fixture "${CAPABILITY_ROOT}"
  run_browser_scenario "capability" "${CAPABILITY_ROOT}"
fi

if [[ "${SCENARIO}" == "all" || "${SCENARIO}" == "capability-responsive" ]]; then
  CAPABILITY_RESPONSIVE_ROOT="${ROOT}/capability-responsive"
  create_full_fixture "${CAPABILITY_RESPONSIVE_ROOT}"
  run_browser_scenario "capability-responsive" "${CAPABILITY_RESPONSIVE_ROOT}"
fi

if [[ "${SCENARIO}" == "all" || "${SCENARIO}" == "capability-scale" ]]; then
  CAPABILITY_SCALE_ROOT="${ROOT}/capability-scale"
  create_full_fixture "${CAPABILITY_SCALE_ROOT}"
  run_browser_scenario "capability-scale" "${CAPABILITY_SCALE_ROOT}"
fi

if [[ "${SCENARIO}" == "all" || "${SCENARIO}" == "empty" ]]; then
  EMPTY_ROOT="${ROOT}/empty"
  mkdir -p "${EMPTY_ROOT}"
  run_browser_scenario "empty" "${EMPTY_ROOT}"
fi

if [[ "${SCENARIO}" == "quickstart" || "${SCENARIO}" == "keyboard" ]]; then
  QUICKSTART_ROOT="${ROOT}/quickstart"
  mkdir -p "${QUICKSTART_ROOT}"
  run_browser_scenario "quickstart" "${QUICKSTART_ROOT}"
fi

if [[ "${SCENARIO}" == "keyboard" ]]; then
  KEYBOARD_PROOF="${ROOT}/desk-workspace-keyboard-matrix-proof.json"
  node -e '
const fs = require("node:fs");
const [onePath, manyPath, outputPath] = process.argv.slice(1);
const one = JSON.parse(fs.readFileSync(onePath, "utf8"));
const many = JSON.parse(fs.readFileSync(manyPath, "utf8"));
const cases = [...one.cases, ...many.cases];
if (one.cardinality !== "one" || many.cardinality !== "many") {
  throw new Error("keyboard proof cardinalities do not agree");
}
if (one.caseCount !== 4 || many.caseCount !== 4 || cases.length !== 8) {
  throw new Error(`keyboard proof requires four one-book and four many-book cases: ${cases.length}`);
}
const expected = new Set([
  "one:1440x900", "one:1024x768", "one:390x844", "one:320x700",
  "many:1440x900", "many:1024x768", "many:390x844", "many:320x700"
]);
for (const item of cases) {
  expected.delete(`${item.cardinality}:${item.viewport.width}x${item.viewport.height}`);
}
if (expected.size !== 0) {
  throw new Error(`keyboard proof is missing cases: ${[...expected].join(", ")}`);
}
fs.writeFileSync(outputPath, `${JSON.stringify({
  kind: "moondesk-workspace-keyboard-matrix-proof.v1",
  caseCount: cases.length,
  cardinalities: ["one", "many"],
  viewports: [
    { width: 1440, height: 900 },
    { width: 1024, height: 768 },
    { width: 390, height: 844 },
    { width: 320, height: 700 }
  ],
  cases
}, null, 2)}\n`);
' \
    "${QUICKSTART_ROOT}/desk-workspace-keyboard-one-proof.json" \
    "${FULL_ROOT}/desk-workspace-keyboard-many-proof.json" \
    "${KEYBOARD_PROOF}"
  echo "Desk workspace keyboard matrix proof: ${KEYBOARD_PROOF}"
fi
