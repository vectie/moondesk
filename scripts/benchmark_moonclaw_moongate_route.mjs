import assert from "node:assert/strict";
import { mkdtempSync, mkdirSync, writeFileSync, readFileSync, rmSync, existsSync, realpathSync } from "node:fs";
import { createServer } from "node:http";
import { spawn } from "node:child_process";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { performance } from "node:perf_hooks";

const scriptRoot = dirname(fileURLToPath(import.meta.url));
const moondeskRoot = resolve(scriptRoot, "..");
const defaultMoonClawRoot = resolve(moondeskRoot, "../moonclaw");
const moonclawRoot = resolve(process.env.MOONCLAW_ROOT || defaultMoonClawRoot);
const candidateBins = [
  process.env.MOONCLAW_BIN,
  join(moonclawRoot, "_build/native/release/build/cmd/main/main.exe"),
  join(moonclawRoot, "_build/native/debug/build/cmd/main/main.exe"),
  join(moonclawRoot, "_build/native/release/build/vectie/moonclaw/cmd/main/main.exe"),
  join(moonclawRoot, "_build/native/debug/build/vectie/moonclaw/cmd/main/main.exe"),
].filter(Boolean);
const moonclawBin = candidateBins.find(existsSync);
if (!moonclawBin) {
  throw new Error("MoonClaw binary not found; build ../moonclaw or set MOONCLAW_BIN");
}
const candidateMoonDeskBins = [
  process.env.MOONDESK_BIN,
  join(moondeskRoot, "_build/native/release/build/cmd/main/main.exe"),
  join(moondeskRoot, "_build/native/debug/build/cmd/main/main.exe"),
].filter(Boolean);
const moondeskBin = candidateMoonDeskBins.find(existsSync);
if (!moondeskBin) {
  throw new Error("MoonDesk binary not found; build this repository or set MOONDESK_BIN");
}

mkdirSync(join(moondeskRoot, "_build"), { recursive: true });
const temporaryRoot = realpathSync(
  mkdtempSync(join(moondeskRoot, "_build/routing-benchmark-")),
);
const suiteRoot = join(temporaryRoot, "suite");
const appDataRoot = join(temporaryRoot, "app-data");
const controlRoot = join(appDataRoot, "control/execution-sandbox");
const controlPath = join(controlRoot, "control.json");
const daemonInfoPath = join(suiteRoot, ".moonsuite/products/moonclaw/daemon.json");
const instanceId = "0123456789abcdef0123456789abcdef";
const authToken = "a".repeat(64);
mkdirSync(join(suiteRoot, ".moonsuite"), { recursive: true });
mkdirSync(controlRoot, { recursive: true, mode: 0o700 });
writeFileSync(
  controlPath,
  JSON.stringify({
    protocol_version: 1,
    instance_id: instanceId,
    auth_token: authToken,
    workspace_id: "routing-benchmark",
    workspace_root: suiteRoot,
  }),
  { mode: 0o600 },
);

let moonGateRequests = 0;
const moonGate = createServer((request, response) => {
  moonGateRequests += 1;
  if (request.url === "/openclaw/v1/models") {
    response.writeHead(200, { "content-type": "application/json" });
    response.end(JSON.stringify({ data: [{ id: "benchmark-model", context_window: 128000 }] }));
    return;
  }
  if (request.url === "/health") {
    response.writeHead(200, { "content-type": "application/json" });
    response.end(JSON.stringify({ ready: true }));
    return;
  }
  response.writeHead(404).end();
});

const listen = (server) => new Promise((resolveListen, reject) => {
  server.once("error", reject);
  server.listen(0, "127.0.0.1", () => resolveListen(server.address().port));
});
const close = (server) => new Promise((resolveClose, reject) => {
  server.close((error) => (error ? reject(error) : resolveClose()));
});
const reservePort = async () => {
  const server = createServer();
  const port = await listen(server);
  await close(server);
  return port;
};
const wait = (milliseconds) => new Promise((resolveWait) => setTimeout(resolveWait, milliseconds));
const percentile = (values, fraction) => {
  const sorted = [...values].sort((left, right) => left - right);
  return sorted[Math.min(sorted.length - 1, Math.ceil(sorted.length * fraction) - 1)];
};
const summary = (name, timings, elapsedMs) => ({
  case: name,
  requests: timings.length,
  p50_ms: Number(percentile(timings, 0.5).toFixed(3)),
  p95_ms: Number(percentile(timings, 0.95).toFixed(3)),
  p99_ms: Number(percentile(timings, 0.99).toFixed(3)),
  throughput_rps: Number((timings.length * 1000 / elapsedMs).toFixed(1)),
});

let moonclaw;
let moondesk;
let stderr = "";
let moondeskStderr = "";
try {
  const moonGatePort = await listen(moonGate);
  writeFileSync(
    join(suiteRoot, ".moonsuite/suite-status.json"),
    JSON.stringify({
      contract: "moon.suite.status.v2",
      service: "moongate",
      status: "running",
      ready: true,
      manifest: {
        contract: "moon.suite.service.v1",
        service: "moongate",
        baseUrl: `http://127.0.0.1:${moonGatePort}`,
        defaultModel: "benchmark-model",
      },
    }),
  );
  moonclaw = spawn(moonclawBin, ["daemon", "--port", "0", "--serve", suiteRoot], {
    cwd: moonclawRoot,
    env: {
      ...process.env,
      LEPUSA_APP_DATA_DIR: appDataRoot,
      MOONDESK_EXECUTION_SANDBOX_CONFIG: controlPath,
    },
    stdio: ["ignore", "ignore", "pipe"],
  });
  moonclaw.stderr.on("data", (chunk) => {
    stderr = (stderr + chunk.toString()).slice(-8000);
  });
  const deadline = performance.now() + 15000;
  while (!existsSync(daemonInfoPath) && performance.now() < deadline) {
    if (moonclaw.exitCode !== null) {
      throw new Error(`MoonClaw exited during startup (${moonclaw.exitCode}): ${stderr}`);
    }
    await wait(25);
  }
  if (!existsSync(daemonInfoPath)) {
    throw new Error(`MoonClaw daemon info was not written: ${stderr}`);
  }
  const daemonInfo = JSON.parse(readFileSync(daemonInfoPath, "utf8"));
  const endpoint = `http://127.0.0.1:${daemonInfo.port}/v1/moongate-route`;
  const headers = {
    "x-moonclaw-execution-token": authToken,
    "x-moonclaw-instance-id": instanceId,
  };
  const probe = async (requestHeaders = headers) => {
    const started = performance.now();
    const response = await fetch(endpoint, { headers: requestHeaders });
    const payload = await response.json();
    return { elapsed: performance.now() - started, response, payload };
  };
  const moondeskPort = await reservePort();
  moondesk = spawn(
    moondeskBin,
    [
      "serve",
      suiteRoot,
      "--ui",
      join(moondeskRoot, "ui/rabbita-desk/dist"),
      "--host",
      "127.0.0.1",
      "--port",
      String(moondeskPort),
    ],
    {
      cwd: moondeskRoot,
      env: {
        ...process.env,
        LEPUSA_APP_DATA_DIR: appDataRoot,
        MOONDESK_EXECUTION_SANDBOX_CONFIG: controlPath,
      },
      stdio: ["ignore", "ignore", "pipe"],
    },
  );
  moondesk.stderr.on("data", (chunk) => {
    moondeskStderr = (moondeskStderr + chunk.toString()).slice(-8000);
  });
  const moondeskBase = `http://127.0.0.1:${moondeskPort}`;
  const moondeskDeadline = performance.now() + 15000;
  let moondeskHealthy = false;
  while (!moondeskHealthy && performance.now() < moondeskDeadline) {
    if (moondesk.exitCode !== null) {
      throw new Error(
        `MoonDesk exited during startup (${moondesk.exitCode}): ${moondeskStderr}`,
      );
    }
    try {
      const health = await fetch(`${moondeskBase}/__moondesk_health`);
      moondeskHealthy = health.ok;
    } catch {
      await wait(25);
    }
  }
  if (!moondeskHealthy) {
    throw new Error(`MoonDesk did not become healthy: ${moondeskStderr}`);
  }
  const deskProbe = async () => {
    const started = performance.now();
    const response = await fetch(`${moondeskBase}/api/moonclaw/models`);
    const payload = await response.json();
    return { elapsed: performance.now() - started, response, payload };
  };
  for (let index = 0; index < 10; index += 1) {
    const warm = await probe();
    assert.equal(warm.response.status, 200, JSON.stringify(warm.payload));
    assert.equal(warm.payload.contract, "moonclaw.moongate-route.v1");
    assert.equal(warm.payload.ready, true);
    assert.equal(warm.payload.default_model, "moongate/benchmark-model");
    assert.deepEqual(warm.payload.traffic_path, ["moondesk", "moonclaw", "moongate"]);
    assert.equal(warm.response.headers.get("x-moonclaw-instance-id"), instanceId);
  }

  const sequential = [];
  const sequentialStarted = performance.now();
  for (let index = 0; index < 200; index += 1) {
    const result = await probe();
    assert.equal(result.payload.ready, true);
    sequential.push(result.elapsed);
  }
  const sequentialElapsed = performance.now() - sequentialStarted;

  const concurrent = [];
  const concurrentStarted = performance.now();
  for (let batch = 0; batch < 10; batch += 1) {
    const results = await Promise.all(Array.from({ length: 20 }, () => probe()));
    for (const result of results) {
      assert.equal(result.payload.ready, true);
      concurrent.push(result.elapsed);
    }
  }
  const concurrentElapsed = performance.now() - concurrentStarted;

  const deskSequential = [];
  const deskSequentialStarted = performance.now();
  for (let index = 0; index < 100; index += 1) {
    const result = await deskProbe();
    assert.equal(result.response.status, 200, JSON.stringify(result.payload));
    assert.equal(result.payload.ok, true, JSON.stringify(result.payload));
    assert.deepEqual(
      result.payload.models.map((model) => model.name),
      ["moongate/benchmark-model"],
    );
    assert.deepEqual(
      result.payload.route.traffic_path,
      ["moondesk", "moonclaw", "moongate"],
    );
    deskSequential.push(result.elapsed);
  }
  const deskSequentialElapsed = performance.now() - deskSequentialStarted;

  const deskConcurrent = [];
  const deskConcurrentStarted = performance.now();
  for (let batch = 0; batch < 5; batch += 1) {
    const results = await Promise.all(
      Array.from({ length: 20 }, () => deskProbe()),
    );
    for (const result of results) {
      assert.equal(result.payload.ok, true, JSON.stringify(result.payload));
      deskConcurrent.push(result.elapsed);
    }
  }
  const deskConcurrentElapsed = performance.now() - deskConcurrentStarted;

  const invalidAuth = [];
  const invalidAuthStarted = performance.now();
  for (let index = 0; index < 50; index += 1) {
    const result = await probe({
      "x-moonclaw-execution-token": "b".repeat(64),
      "x-moonclaw-instance-id": instanceId,
    });
    assert.equal(result.response.status, 401);
    invalidAuth.push(result.elapsed);
  }
  const invalidAuthElapsed = performance.now() - invalidAuthStarted;

  await close(moonGate);
  const unavailable = [];
  const unavailableStarted = performance.now();
  for (let index = 0; index < 30; index += 1) {
    const result = await probe();
    assert.equal(result.response.status, 200);
    assert.equal(result.payload.ready, false);
    assert.equal(result.payload.default_model, "");
    unavailable.push(result.elapsed);
  }
  const unavailableElapsed = performance.now() - unavailableStarted;

  const deskUnavailable = [];
  const deskUnavailableStarted = performance.now();
  for (let index = 0; index < 10; index += 1) {
    const result = await deskProbe();
    assert.equal(result.response.status, 200);
    assert.equal(result.payload.ok, false);
    assert.deepEqual(result.payload.models, []);
    deskUnavailable.push(result.elapsed);
  }
  const deskUnavailableElapsed = performance.now() - deskUnavailableStarted;

  const cases = [
    summary("sequential-live-route", sequential, sequentialElapsed),
    summary("concurrent-live-route", concurrent, concurrentElapsed),
    summary("moondesk-sequential-live-route", deskSequential, deskSequentialElapsed),
    summary("moondesk-concurrent-live-route", deskConcurrent, deskConcurrentElapsed),
    summary("invalid-control-token", invalidAuth, invalidAuthElapsed),
    summary("moongate-unavailable", unavailable, unavailableElapsed),
    summary("moondesk-moongate-unavailable", deskUnavailable, deskUnavailableElapsed),
  ];
  const limits = {
    sequential_live_route_p95_ms: 10,
    concurrent_live_route_p95_ms: 50,
    moondesk_sequential_live_route_p95_ms: 25,
    moondesk_concurrent_live_route_p95_ms: 100,
    invalid_control_token_p95_ms: 10,
    moongate_unavailable_p95_ms: 1000,
    moondesk_moongate_unavailable_p95_ms: 1200,
  };
  const benchmarkEvidence = JSON.stringify(cases);
  assert.ok(
    cases[0].p95_ms <= limits.sequential_live_route_p95_ms,
    benchmarkEvidence,
  );
  assert.ok(
    cases[1].p95_ms <= limits.concurrent_live_route_p95_ms,
    benchmarkEvidence,
  );
  assert.ok(
    cases[2].p95_ms <= limits.moondesk_sequential_live_route_p95_ms,
    benchmarkEvidence,
  );
  assert.ok(
    cases[3].p95_ms <= limits.moondesk_concurrent_live_route_p95_ms,
    benchmarkEvidence,
  );
  assert.ok(
    cases[4].p95_ms <= limits.invalid_control_token_p95_ms,
    benchmarkEvidence,
  );
  assert.ok(
    cases[5].p95_ms <= limits.moongate_unavailable_p95_ms,
    benchmarkEvidence,
  );
  assert.ok(
    cases[6].p95_ms <= limits.moondesk_moongate_unavailable_p95_ms,
    benchmarkEvidence,
  );

  console.log(JSON.stringify({
    contract: "moondesk.routing-benchmark.v1",
    moondesk_binary: moondeskBin,
    moonclaw_binary: moonclawBin,
    traffic_path: ["moondesk", "moonclaw", "moongate"],
    correctness: {
      authenticated_instance_binding: true,
      direct_provider_models_exposed: false,
      invalid_auth_rejected: true,
      moongate_failure_closed: true,
    },
    moonGate_requests: moonGateRequests,
    limits,
    cases,
  }));
} finally {
  if (moonGate.listening) await close(moonGate);
  if (moondesk && moondesk.exitCode === null) {
    moondesk.kill("SIGTERM");
    await Promise.race([
      new Promise((resolveExit) => moondesk.once("exit", resolveExit)),
      wait(2000),
    ]);
    if (moondesk.exitCode === null) moondesk.kill("SIGKILL");
  }
  if (moonclaw && moonclaw.exitCode === null) {
    moonclaw.kill("SIGTERM");
    await Promise.race([
      new Promise((resolveExit) => moonclaw.once("exit", resolveExit)),
      wait(2000),
    ]);
    if (moonclaw.exitCode === null) moonclaw.kill("SIGKILL");
  }
  rmSync(temporaryRoot, { recursive: true, force: true });
}
