#!/usr/bin/env node

import { readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

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

function timestamp(value, label) {
  text(value, label);
  if (!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})$/.test(value)) fail(`${label} must be an ISO 8601 timestamp with timezone`);
  const milliseconds = Date.parse(value);
  if (!Number.isFinite(milliseconds)) fail(`${label} is not a valid timestamp`);
  return milliseconds;
}

function nonnegative(value, label, integer = false) {
  if (typeof value !== "number" || !Number.isFinite(value) || value < 0 || (integer && !Number.isInteger(value))) fail(`${label} must be a nonnegative ${integer ? "integer" : "number"}`);
  return value;
}

function validateProof(value, label) {
  object(value, label);
  if (!["passed", "failed", "blocked", "not_run"].includes(value.status)) fail(`${label}.status is invalid`);
  text(value.owner, `${label}.owner`);
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value.target_date)) fail(`${label}.target_date must be YYYY-MM-DD`);
  if (!Array.isArray(value.evidence)) fail(`${label}.evidence must be an array`);
  if (value.status === "passed" && value.evidence.length === 0) fail(`${label} cannot pass without evidence`);
  for (const item of value.evidence) text(item, `${label}.evidence item`);
}

function validateSoak(value, frozen, started, completed) {
  object(value.thresholds, "thresholds");
  if (JSON.stringify(Object.entries(value.thresholds).sort()) !== JSON.stringify(Object.entries(frozen).sort())) fail("soak thresholds differ from frozen policy");
  if (Date.parse(`${frozen.defined_before_execution}T00:00:00Z`) >= started) fail("soak thresholds were not frozen before execution");
  if (completed - started < frozen.duration_hours * 3_600_000) fail("soak duration is shorter than frozen policy");
  for (const scenario of frozen.required_scenarios) {
    if (!value.results[scenario]) fail(`missing required soak scenario ${scenario}`);
    if (value.results[scenario].status !== "passed") fail(`required soak scenario ${scenario} did not pass`);
  }
  if (!Array.isArray(value.samples) || value.samples.length < frozen.minimum_samples) fail(`soak requires at least ${frozen.minimum_samples} samples`);
  const interval = frozen.sample_interval_seconds * 1_000;
  let previousAt = null;
  let initialRss = null;
  let initialDescriptors = null;
  let maximumRss = 0;
  let maximumDescriptors = 0;
  for (const [index, sample] of value.samples.entries()) {
    object(sample, `samples[${index}]`);
    const at = timestamp(sample.at, `samples[${index}].at`);
    const rss = nonnegative(sample.rss_mib, `samples[${index}].rss_mib`);
    const descriptors = nonnegative(sample.file_descriptors, `samples[${index}].file_descriptors`, true);
    if (at < started || at > completed) fail(`samples[${index}] falls outside the soak interval`);
    if (previousAt !== null && (at <= previousAt || at - previousAt > interval * 2)) fail(`samples[${index}] is out of order or leaves an excessive gap`);
    if (index === 0) {
      if (at - started > interval) fail("soak samples begin too late");
      initialRss = rss;
      initialDescriptors = descriptors;
    }
    previousAt = at;
    maximumRss = Math.max(maximumRss, rss);
    maximumDescriptors = Math.max(maximumDescriptors, descriptors);
  }
  if (completed - previousAt > interval) fail("soak samples end too early");
  const rssGrowth = Math.max(0, maximumRss - initialRss);
  const rssGrowthPercent = initialRss === 0 ? (maximumRss === 0 ? 0 : Infinity) : 100 * rssGrowth / initialRss;
  if (rssGrowth > frozen.maximum_rss_growth_mib || rssGrowthPercent > frozen.maximum_rss_growth_percent) fail("soak RSS growth exceeds frozen policy");
  if (maximumDescriptors - initialDescriptors > frozen.maximum_file_descriptor_growth || maximumDescriptors > frozen.maximum_file_descriptor_count) fail("soak file descriptor usage exceeds frozen policy");
  if (nonnegative(value.unexpected_process_exits, "unexpected_process_exits", true) > frozen.maximum_unexpected_process_exits) fail("soak unexpected process exits exceed frozen policy");
  if (nonnegative(value.failed_lifecycle_scenarios, "failed_lifecycle_scenarios", true) > frozen.maximum_failed_lifecycle_scenarios) fail("soak failed lifecycle scenarios exceed frozen policy");
}

function validateEvidence(value, frozen) {
  object(value, "evidence");
  const kinds = ["moondesk-clean-machine-evidence.v1", "moondesk-install-update-rollback-removal-evidence.v1", "moondesk-soak-evidence.v1"];
  if (!kinds.includes(value.kind)) fail("unsupported evidence kind");
  sha(value.release_identity_sha256, "release_identity_sha256");
  const started = timestamp(value.started_at, "started_at");
  const completed = timestamp(value.completed_at, "completed_at");
  if (completed <= started) fail("completed_at must follow started_at");
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
    validateSoak(value, frozen, started, completed);
  }
}

const files = process.argv.slice(2);
if (files.length === 0) {
  console.error("usage: validate_phase9_evidence.mjs FILE...");
  process.exit(64);
}

try {
  const frozen = JSON.parse(await readFile(path.join(repoRoot, "config/phase9-soak-thresholds.json"), "utf8"));
  for (const file of files) validateEvidence(JSON.parse(await readFile(file, "utf8")), frozen);
  console.log(`phase9 evidence verified: ${files.length} file(s)`);
} catch (error) {
  console.error(`phase9 evidence: ${error.message}`);
  process.exitCode = 65;
}
