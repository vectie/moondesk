#!/usr/bin/env node

import { readFile } from "node:fs/promises";

function fail(message) {
  throw new Error(message);
}

function object(value, label) {
  if (!value || typeof value !== "object" || Array.isArray(value)) fail(`${label} must be an object`);
  return value;
}

function text(value, label) {
  if (typeof value !== "string" || value.length === 0) fail(`${label} must be a non-empty string`);
}

function sha(value, label) {
  if (typeof value !== "string" || !/^[0-9a-f]{64}$/.test(value)) fail(`${label} must be a lowercase SHA-256`);
}

function validateProof(value, label) {
  object(value, label);
  if (!["passed", "failed", "blocked", "not_run"].includes(value.status)) fail(`${label}.status is invalid`);
  text(value.owner, `${label}.owner`);
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value.target_date)) fail(`${label}.target_date must be YYYY-MM-DD`);
  if (!Array.isArray(value.evidence)) fail(`${label}.evidence must be an array`);
  if (value.status === "passed" && value.evidence.length === 0) fail(`${label} cannot pass without evidence`);
}

function validateEvidence(value) {
  object(value, "evidence");
  const kinds = ["moondesk-clean-machine-evidence.v1", "moondesk-install-update-rollback-removal-evidence.v1", "moondesk-soak-evidence.v1"];
  if (!kinds.includes(value.kind)) fail("unsupported evidence kind");
  sha(value.release_identity_sha256, "release_identity_sha256");
  text(value.started_at, "started_at");
  text(value.completed_at, "completed_at");
  text(value.operator, "operator");
  object(value.results, "results");
  if (Object.keys(value.results).length === 0) fail("results must be non-empty");
  for (const [name, proof] of Object.entries(value.results)) validateProof(proof, `results.${name}`);
  if (value.kind === kinds[0]) object(value.machine, "machine");
  if (value.kind === kinds[1]) {
    sha(value.user_data_before_sha256, "user_data_before_sha256");
    sha(value.user_data_after_sha256, "user_data_after_sha256");
  }
  if (value.kind === kinds[2]) {
    object(value.thresholds, "thresholds");
    if (!Array.isArray(value.samples)) fail("samples must be an array");
  }
}

const files = process.argv.slice(2);
if (files.length === 0) {
  console.error("usage: validate_phase9_evidence.mjs FILE...");
  process.exit(64);
}

try {
  for (const file of files) validateEvidence(JSON.parse(await readFile(file, "utf8")));
  console.log(`phase9 evidence verified: ${files.length} file(s)`);
} catch (error) {
  console.error(`phase9 evidence: ${error.message}`);
  process.exitCode = 65;
}
