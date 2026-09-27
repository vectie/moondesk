import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import test from "node:test";

const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const validator = path.join(scriptDir, "validate_phase9_evidence.mjs");
const thresholds = JSON.parse(await readFile(path.join(scriptDir, "../config/phase9-soak-thresholds.json"), "utf8"));
const start = Date.parse("2026-08-01T00:00:00Z");

function fixture() {
  return {
    kind: "moondesk-soak-evidence.v1",
    release_identity_sha256: "a".repeat(64),
    started_at: new Date(start).toISOString(),
    completed_at: new Date(start + 24 * 3_600_000).toISOString(),
    operator: "fixture operator",
    thresholds,
    results: Object.fromEntries(thresholds.required_scenarios.map(name => [name, {
      status: "passed", owner: "fixture operator", target_date: "2026-08-02", evidence: ["fixture receipt"],
    }])),
    samples: Array.from({ length: 289 }, (_, index) => ({
      at: new Date(start + index * 300_000).toISOString(), rss_mib: 100, file_descriptors: 100,
    })),
    unexpected_process_exits: 0,
    failed_lifecycle_scenarios: 0,
  };
}

async function validate(value) {
  const directory = await mkdtemp(path.join(os.tmpdir(), "moondesk-soak-evidence-"));
  try {
    const file = path.join(directory, "evidence.json");
    await writeFile(file, JSON.stringify(value));
    return spawnSync(process.execPath, [validator, file], { encoding: "utf8" });
  } finally {
    await rm(directory, { recursive: true, force: true });
  }
}

test("accepts a complete fixture meeting the frozen soak policy", async () => {
  const result = await validate(fixture());
  assert.equal(result.status, 0, result.stderr);
});

test("rejects short, sparse, incomplete, and over-threshold soak claims", async () => {
  const cases = [
    ["short duration", value => { value.completed_at = new Date(start + 3_600_000).toISOString(); }],
    ["missing samples", value => { value.samples = []; }],
    ["missing scenario", value => { delete value.results[thresholds.required_scenarios[0]]; }],
    ["resource growth", value => { value.samples.at(-1).rss_mib = 500; }],
    ["unexpected exit", value => { value.unexpected_process_exits = 1; }],
    ["threshold drift", value => { value.thresholds = { ...thresholds, duration_hours: 1 }; }],
  ];
  for (const [name, change] of cases) {
    const value = fixture();
    change(value);
    const result = await validate(value);
    assert.equal(result.status, 65, `${name}: ${result.stdout}${result.stderr}`);
  }
});
