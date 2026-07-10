import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawn } from "node:child_process";

export const repoRoot = path.resolve(path.dirname(new URL(import.meta.url).pathname), "..");
export const workspaceRoot = path.resolve(repoRoot, "..");
export const moonBin = process.env.MOON_BIN || process.env.MOON || "moon";
export const moonclawRoot = path.resolve(process.env.MOONCLAW_ROOT || path.join(workspaceRoot, "moonclaw"));
export const uiDist = path.resolve(process.env.UI_DIST || path.join(repoRoot, "ui/rabbita-desk/dist"));
export const host = "127.0.0.1";
export const suiteRoot = fs.mkdtempSync(path.join(os.tmpdir(), "moondesk-mooncode-live-runtime-"));

const pids = [];

export function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

export function acceptedCommandId(payload) {
  if (!payload || typeof payload !== "object") {
    return "";
  }
  return payload.command_id ||
    payload.mooncode_turn?.command_id ||
    payload.turn_id ||
    payload.mooncode_conversation?.turns?.at(-1)?.command_id ||
    "";
}

export function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

function randomPort(base) {
  return base + Math.floor(Math.random() * 1000);
}

export function suitePath(...parts) {
  return path.join(suiteRoot, ...parts);
}

export function logPath(name) {
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

export function processStillRunning(child) {
  return child.exitCode == null && child.signalCode == null;
}

export async function waitFor(label, fn, timeoutMs = 30000) {
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

export async function requestJson(url, options = {}, expected = [200]) {
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

export async function fetchCanonicalSession(base, sessionId) {
  return await requestJson(
    `${base}/api/mooncode/sessions/${encodeURIComponent(sessionId)}?format=chat`,
  );
}

function readJsonFile(file) {
  try {
    return JSON.parse(fs.readFileSync(file, "utf8"));
  } catch {
    return null;
  }
}

function writeMoonClawServiceConfig() {
  const servicePath = suitePath(".moonsuite/products/moonclaw/service.json");
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

export async function startMoonClaw() {
  assert(fs.existsSync(path.join(moonclawRoot, "moon.mod")), `MoonClaw checkout not found: ${moonclawRoot}`);
  writeMoonClawServiceConfig();
  const child = spawnLogged(
    "moonclaw",
    moonBin,
    ["run", "cmd/main", "--", "daemon", "--port", "0", "--serve", suiteRoot],
    moonclawRoot,
  );
  const infoPath = suitePath(".moonsuite/products/moonclaw/daemon.json");
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

export async function startMoondesk() {
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

export function cleanupProcesses() {
  for (const child of pids.reverse()) {
    if (processStillRunning(child)) {
      child.kill();
    }
  }
}
