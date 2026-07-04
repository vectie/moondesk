import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawn } from "node:child_process";

const repoRoot = path.resolve(path.dirname(new URL(import.meta.url).pathname), "..");
const workspaceRoot = path.resolve(repoRoot, "..");
const moonBin = process.env.MOON_BIN || process.env.MOON || "moon";
const moonclawRoot = path.resolve(process.env.MOONCLAW_ROOT || path.join(workspaceRoot, "moonclaw"));
const uiDist = path.resolve(process.env.UI_DIST || path.join(repoRoot, "ui/rabbita-desk/dist"));
const host = "127.0.0.1";
const suiteRoot = fs.mkdtempSync(path.join(os.tmpdir(), "moondesk-mooncode-live-runtime-"));
const pids = [];

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

function randomPort(base) {
  return base + Math.floor(Math.random() * 1000);
}

function logPath(name) {
  return path.join(suiteRoot, `${name}.log`);
}

function spawnLogged(label, command, args, cwd) {
  const stdout = fs.openSync(logPath(`${label}.out`), "a");
  const stderr = fs.openSync(logPath(`${label}.err`), "a");
  const child = spawn(command, args, {
    cwd,
    stdio: ["ignore", stdout, stderr],
  });
  pids.push(child);
  return child;
}

function processStillRunning(child) {
  return child.exitCode == null && child.signalCode == null;
}

async function waitFor(label, fn, timeoutMs = 30000) {
  const deadline = Date.now() + timeoutMs;
  let last;
  while (Date.now() < deadline) {
    last = await fn();
    if (last) {
      return last;
    }
    await sleep(100);
  }
  throw new Error(`Timed out waiting for ${label}; last=${JSON.stringify(last)}`);
}

async function requestJson(url, options = {}, expected = [200]) {
  const response = await fetch(url, {
    ...options,
    headers: {
      "content-type": "application/json",
      ...(options.headers || {}),
    },
  });
  const text = await response.text();
  let body = {};
  try {
    body = text ? JSON.parse(text) : {};
  } catch {
    body = { text };
  }
  assert(
    expected.includes(response.status),
    `HTTP ${response.status} for ${url}: ${text}`,
  );
  return body;
}

function readJsonFile(file) {
  try {
    return JSON.parse(fs.readFileSync(file, "utf8"));
  } catch {
    return null;
  }
}

function writeMoonClawServiceConfig() {
  const servicePath = path.join(
    suiteRoot,
    ".moonsuite/products/moonclaw/service.json",
  );
  fs.mkdirSync(path.dirname(servicePath), { recursive: true });
  fs.writeFileSync(
    servicePath,
    `${JSON.stringify({
      kind: "moondesk-moonclaw-service.v1",
      cwd: moonclawRoot,
      daemon: {
        command: moonBin,
        args: ["run", "cmd/main", "--", "daemon", "--port", "0", "--serve", suiteRoot],
      },
    }, null, 2)}\n`,
  );
}

async function startMoonClaw() {
  assert(fs.existsSync(path.join(moonclawRoot, "moon.mod")), `MoonClaw checkout not found: ${moonclawRoot}`);
  writeMoonClawServiceConfig();
  const child = spawnLogged(
    "moonclaw",
    moonBin,
    ["run", "cmd/main", "--", "daemon", "--port", "0", "--serve", suiteRoot],
    moonclawRoot,
  );
  const infoPath = path.join(
    suiteRoot,
    ".moonsuite/products/moonclaw/daemon.json",
  );
  const info = await waitFor("MoonClaw daemon info", () => {
    if (!processStillRunning(child)) {
      throw new Error(
        `MoonClaw daemon exited early; see ${logPath("moonclaw.err")}`,
      );
    }
    const parsed = readJsonFile(infoPath);
    return parsed?.port > 0 && parsed?.pid > 0 ? parsed : null;
  }, 60000);
  const base = `http://localhost:${info.port}`;
  await waitFor("MoonClaw native capabilities", async () => {
    try {
      const capabilities = await requestJson(`${base}/v1/code/capabilities`);
      return capabilities?.native_runtime_ready === true ? capabilities : null;
    } catch {
      return null;
    }
  }, 30000);
  return { base, info };
}

async function startMoondesk() {
  assert(fs.existsSync(path.join(uiDist, "index.html")), `UI dist not found: ${uiDist}`);
  const port = Number(process.env.PORT || randomPort(5600));
  const child = spawnLogged(
    "moondesk",
    moonBin,
    ["run", "cmd/main", "--", "serve", suiteRoot, "--ui", uiDist, "--host", host, "--port", String(port)],
    repoRoot,
  );
  const base = `http://${host}:${port}`;
  await waitFor("Moondesk health", async () => {
    if (!processStillRunning(child)) {
      throw new Error(`Moondesk exited early; see ${logPath("moondesk.err")}`);
    }
    try {
      const response = await fetch(`${base}/__moondesk_health`);
      return response.ok;
    } catch {
      return false;
    }
  }, 30000);
  return { base };
}

async function runSmoke() {
  const moonclaw = await startMoonClaw();
  const moondesk = await startMoondesk();
  const created = await requestJson(
    `${moondesk.base}/api/mooncode/sessions`,
    {
      method: "POST",
      body: JSON.stringify({
        title: "MoonCode - Live Runtime Contract Smoke",
        message: "Live runtime contract smoke",
        client_turn_id: "live-runtime-contract-client-turn",
        model: "codex/gpt-5.4",
        web_search: false,
        max_turns: 1,
        live_wait_ms: 0,
        poll_ms: 25,
      }),
    },
  );
  const sessionId = created.id;
  const commandId = created.command_id;
  assert(sessionId && commandId, `Created session did not return ids: ${JSON.stringify(created)}`);

  const reply = "Live MoonClaw runtime contract smoke reply.";
  const nativePost = await requestJson(
    `${moonclaw.base}/v1/code/sessions/${encodeURIComponent(sessionId)}/runtime-events?book_root=${encodeURIComponent(suiteRoot)}`,
    {
      method: "POST",
      body: JSON.stringify({
        events: [
          {
            event: "assistant_message",
            id: "live-native-assistant-1",
            created_at: "2026-07-04T00:00:00Z",
            content: reply,
            command_id: commandId,
            action: "prompt",
            session_id: sessionId,
          },
        ],
      }),
    },
    [202],
  );
  assert(nativePost.owner === "moonclaw", `Native event owner mismatch: ${JSON.stringify(nativePost)}`);
  assert(nativePost.event_count === 1, `Native event count mismatch: ${JSON.stringify(nativePost)}`);

  const runtimeState = await waitFor("Moondesk native runtime contract import", async () => {
    const state = await requestJson(
      `${moondesk.base}/api/mooncode/sessions/${encodeURIComponent(sessionId)}/runtime-events`,
    );
    const safe = state.native_runtime_contract_projection_safe === true &&
      state.native_runtime_contract_status === "projection-safe" &&
      state.native_runtime_contract_unscoped_projection_event_count === 0 &&
      state.native_event_count >= 1;
    return safe ? state : null;
  }, 20000);

  const sessions = await requestJson(`${moondesk.base}/api/mooncode/sessions`);
  const session = sessions.find(item => item.id === sessionId);
  assert(session, `Moondesk session missing after native import: ${JSON.stringify(sessions)}`);
  const turns = session.mooncode_conversation?.turns || [];
  const turn = turns.find(item => item.command_id === commandId);
  assert(turn?.assistant?.content === reply, `Native reply was not canonical conversation output: ${JSON.stringify(turns)}`);
  assert(
    !fs.existsSync(path.join(suiteRoot, ".moonclaw")),
    "Live runtime smoke created legacy .moonclaw root",
  );
  console.log(JSON.stringify({
    ok: true,
    suite_root: suiteRoot,
    moondesk: moondesk.base,
    moonclaw: moonclaw.base,
    session_id: sessionId,
    command_id: commandId,
    native_runtime_contract_status: runtimeState.native_runtime_contract_status,
  }, null, 2));
}

try {
  await runSmoke();
} finally {
  for (const child of pids.reverse()) {
    if (processStillRunning(child)) {
      child.kill();
    }
  }
}
