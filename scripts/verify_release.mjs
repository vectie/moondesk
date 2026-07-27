#!/usr/bin/env node

import { createHash } from "node:crypto";
import {
  access,
  readFile,
  realpath,
  rename,
  stat,
  writeFile,
} from "node:fs/promises";
import path from "node:path";
import { pathToFileURL } from "node:url";

export const releaseExit = Object.freeze({
  usage: 64,
  malformed: 65,
  unsafe: 66,
  missing: 67,
  drift: 68,
  immutable: 69,
});

export class ReleaseContractError extends Error {
  constructor(code, message) {
    super(message);
    this.name = "ReleaseContractError";
    this.exitCode = code;
  }
}

function reject(code, message) {
  throw new ReleaseContractError(code, message);
}

function compareText(left, right) {
  return left < right ? -1 : left > right ? 1 : 0;
}

function requireObject(value, label) {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    reject(releaseExit.malformed, `${label} must be an object`);
  }
  return value;
}

function requireString(value, label) {
  if (typeof value !== "string" || value.length === 0) {
    reject(releaseExit.malformed, `${label} must be a non-empty string`);
  }
  return value;
}

function requireBoolean(value, label) {
  if (typeof value !== "boolean") {
    reject(releaseExit.malformed, `${label} must be a boolean`);
  }
  return value;
}

function requireSha256(value, label) {
  if (typeof value !== "string" || !/^[0-9a-f]{64}$/.test(value)) {
    reject(releaseExit.unsafe, `${label} must be a lowercase SHA-256`);
  }
  return value;
}

export function requirePortablePath(value, label) {
  const relative = requireString(value, label);
  const segments = relative.split("/");
  if (
    relative.includes("\\") ||
    relative.includes("\0") ||
    path.posix.isAbsolute(relative) ||
    segments.some(segment => segment === "" || segment === "." || segment === "..")
  ) {
    reject(releaseExit.unsafe, `${label} is not a safe portable path: ${relative}`);
  }
  return relative;
}

async function readJson(root, name) {
  let text;
  try {
    text = await readFile(path.join(root, name), "utf8");
  } catch (error) {
    if (error?.code === "ENOENT") {
      reject(releaseExit.missing, `missing ${name}`);
    }
    reject(releaseExit.malformed, `${name}: ${error.message}`);
  }
  try {
    return requireObject(JSON.parse(text), name);
  } catch (error) {
    if (error instanceof ReleaseContractError) throw error;
    reject(releaseExit.malformed, `${name}: ${error.message}`);
  }
}

async function releaseRoot(root) {
  const absolute = path.resolve(root);
  try {
    const info = await stat(absolute);
    if (!info.isDirectory()) reject(releaseExit.missing, "release root is not a directory");
    return { absolute, real: await realpath(absolute) };
  } catch (error) {
    if (error instanceof ReleaseContractError) throw error;
    reject(releaseExit.missing, `release root is unavailable: ${absolute}`);
  }
}

async function confinedEntry(root, relative, label, expectedType = "file") {
  const portable = requirePortablePath(relative, label);
  const lexical = path.resolve(root.absolute, ...portable.split("/"));
  if (!lexical.startsWith(`${root.absolute}${path.sep}`)) {
    reject(releaseExit.unsafe, `${label} escapes the release root`);
  }
  let resolved;
  let info;
  try {
    resolved = await realpath(lexical);
    info = await stat(resolved);
  } catch {
    reject(releaseExit.missing, `missing ${label}: ${portable}`);
  }
  if (resolved !== root.real && !resolved.startsWith(`${root.real}${path.sep}`)) {
    reject(releaseExit.unsafe, `${label} resolves outside the release root`);
  }
  if (expectedType === "file" && !info.isFile()) {
    reject(releaseExit.missing, `${label} is not a file: ${portable}`);
  }
  if (expectedType === "directory" && !info.isDirectory()) {
    reject(releaseExit.missing, `${label} is not a directory: ${portable}`);
  }
  return { portable, resolved };
}

async function sha256(file) {
  return createHash("sha256").update(await readFile(file)).digest("hex");
}

function artifactMap(updates) {
  if (!Array.isArray(updates.artifacts) || updates.artifacts.length === 0) {
    reject(releaseExit.malformed, "updates.artifacts must be a non-empty array");
  }
  const artifacts = new Map();
  for (const [index, candidate] of updates.artifacts.entries()) {
    const artifact = requireObject(candidate, `updates.artifacts[${index}]`);
    const kind = requireString(artifact.kind, `updates.artifacts[${index}].kind`);
    if (artifacts.has(kind)) {
      reject(releaseExit.unsafe, `duplicate artifact kind: ${kind}`);
    }
    artifacts.set(kind, {
      kind,
      path: requirePortablePath(
        artifact.path,
        `updates.artifacts[${index}].path`,
      ),
      sha256: requireSha256(
        artifact.sha256,
        `updates.artifacts[${index}].sha256`,
      ),
    });
  }
  return artifacts;
}

function requireMatchingArtifact(artifacts, kind, relative, digest) {
  const artifact = artifacts.get(kind);
  if (!artifact) reject(releaseExit.unsafe, `missing ${kind} artifact declaration`);
  if (artifact.path !== relative || artifact.sha256 !== digest) {
    reject(releaseExit.unsafe, `${kind} artifact disagrees with release manifest`);
  }
}

async function inspectRelease(rootPath) {
  const root = await releaseRoot(rootPath);
  const manifest = await readJson(root.absolute, "release-manifest.json");
  const updates = await readJson(root.absolute, "updates.json");
  if (manifest.kind !== "moondesk-release-manifest.v1") {
    reject(releaseExit.malformed, "unsupported release manifest kind");
  }
  if (updates.kind !== "moondesk-update-manifest.v1") {
    reject(releaseExit.malformed, "unsupported update manifest kind");
  }
  const version = requireString(manifest.version, "manifest.version");
  const channel = requireString(manifest.channel, "manifest.channel");
  if (updates.version !== version || updates.channel !== channel) {
    reject(releaseExit.unsafe, "release/update version or channel disagreement");
  }

  const app = requirePortablePath(manifest.app, "manifest.app");
  if (manifest.app_name !== app) {
    reject(releaseExit.unsafe, "manifest app and app_name disagree");
  }
  await confinedEntry(root, app, "app bundle", "directory");

  const archive = requirePortablePath(manifest.archive, "manifest.archive");
  const archiveSha = requireSha256(
    manifest.archive_sha256,
    "manifest.archive_sha256",
  );
  const runtime = requirePortablePath(
    manifest.runtime_manifest,
    "manifest.runtime_manifest",
  );
  const runtimeSha = requireSha256(
    manifest.runtime_manifest_sha256,
    "manifest.runtime_manifest_sha256",
  );
  const releaseNotes = requirePortablePath(
    manifest.release_notes,
    "manifest.release_notes",
  );
  if (manifest.update_manifest !== "updates.json") {
    reject(releaseExit.unsafe, "manifest.update_manifest must be updates.json");
  }
  if (updates.release_notes !== releaseNotes) {
    reject(releaseExit.unsafe, "release-note path disagreement");
  }

  const signed = requireBoolean(manifest.signed, "manifest.signed");
  const notarized = requireBoolean(manifest.notarized, "manifest.notarized");
  const notaryProfileSupplied = requireBoolean(
    manifest.notary_profile_supplied,
    "manifest.notary_profile_supplied",
  );
  const dmgCreated = requireBoolean(
    manifest.dmg_created,
    "manifest.dmg_created",
  );
  if (updates.notarized !== notarized) {
    reject(releaseExit.unsafe, "notarization disagreement");
  }
  if (notarized && (!signed || !notaryProfileSupplied || !dmgCreated)) {
    reject(
      releaseExit.unsafe,
      "notarized releases require signing, credentials, and a DMG",
    );
  }
  if (manifest.installer !== (dmgCreated ? "dmg" : "zip")) {
    reject(releaseExit.unsafe, "installer selection disagrees with DMG state");
  }

  const artifacts = artifactMap(updates);
  requireMatchingArtifact(artifacts, "zip", archive, archiveSha);
  requireMatchingArtifact(artifacts, "runtime-manifest", runtime, runtimeSha);
  if (dmgCreated) {
    const dmg = requirePortablePath(manifest.dmg, "manifest.dmg");
    const dmgSha = requireSha256(manifest.dmg_sha256, "manifest.dmg_sha256");
    requireMatchingArtifact(artifacts, "dmg", dmg, dmgSha);
  } else {
    if (manifest.dmg !== "" || manifest.dmg_sha256 !== "" || artifacts.has("dmg")) {
      reject(releaseExit.unsafe, "non-DMG release declares DMG data");
    }
  }
  const expectedKinds = dmgCreated
    ? ["dmg", "runtime-manifest", "zip"]
    : ["runtime-manifest", "zip"];
  const actualKinds = [...artifacts.keys()].sort();
  if (actualKinds.join("\n") !== expectedKinds.join("\n")) {
    reject(releaseExit.unsafe, "unexpected artifact kind");
  }

  const declared = new Map();
  for (const artifact of artifacts.values()) {
    const entry = await confinedEntry(
      root,
      artifact.path,
      `${artifact.kind} artifact`,
    );
    const actual = await sha256(entry.resolved);
    if (actual !== artifact.sha256) {
      reject(releaseExit.drift, `hash mismatch: ${artifact.path}`);
    }
    declared.set(artifact.path, artifact.sha256);
  }
  for (const metadata of [
    "release-manifest.json",
    "updates.json",
    releaseNotes,
  ]) {
    const entry = await confinedEntry(root, metadata, metadata);
    declared.set(metadata, await sha256(entry.resolved));
  }
  return { root, manifest, updates, version, channel, declared };
}

function parseChecksums(text) {
  const lines = text.endsWith("\n")
    ? text.slice(0, -1).split("\n")
    : text.split("\n");
  if (lines.length === 1 && lines[0] === "") {
    reject(releaseExit.drift, "SHA256SUMS is empty");
  }
  const sorted = [...lines].sort(compareText);
  if (lines.join("\n") !== sorted.join("\n")) {
    reject(releaseExit.drift, "SHA256SUMS is not sorted");
  }
  const sums = new Map();
  for (const line of lines) {
    const match = /^([0-9a-f]{64})  (.+)$/.exec(line);
    if (!match) reject(releaseExit.drift, "invalid SHA256SUMS line");
    const relative = requirePortablePath(match[2], "SHA256SUMS path");
    if (sums.has(relative)) reject(releaseExit.drift, `duplicate checksum: ${relative}`);
    sums.set(relative, match[1]);
  }
  return sums;
}

export async function writeReleaseChecksums(rootPath) {
  const inspected = await inspectRelease(rootPath);
  const checksumPath = path.join(inspected.root.absolute, "SHA256SUMS");
  try {
    await access(checksumPath);
    reject(releaseExit.immutable, "SHA256SUMS already exists; refusing overwrite");
  } catch (error) {
    if (error instanceof ReleaseContractError) throw error;
    if (error?.code !== "ENOENT") {
      reject(releaseExit.immutable, `cannot establish checksum freshness: ${error.message}`);
    }
  }
  const lines = [...inspected.declared.entries()]
    .map(([relative, digest]) => `${digest}  ${relative}`)
    .sort(compareText);
  const temporary = `${checksumPath}.tmp-${process.pid}`;
  await writeFile(temporary, `${lines.join("\n")}\n`, { flag: "wx", mode: 0o644 });
  await rename(temporary, checksumPath);
  return { ...inspected, checksumCount: lines.length };
}

export async function verifyRelease(rootPath) {
  const inspected = await inspectRelease(rootPath);
  let text;
  try {
    text = await readFile(
      path.join(inspected.root.absolute, "SHA256SUMS"),
      "utf8",
    );
  } catch {
    reject(releaseExit.missing, "missing SHA256SUMS");
  }
  const sums = parseChecksums(text);
  for (const [relative, digest] of inspected.declared) {
    if (sums.get(relative) !== digest) {
      reject(releaseExit.drift, `missing or drifting checksum: ${relative}`);
    }
  }
  for (const relative of sums.keys()) {
    if (!inspected.declared.has(relative)) {
      reject(releaseExit.drift, `extra checksum entry: ${relative}`);
    }
  }
  return { ...inspected, checksumCount: sums.size };
}

async function cli() {
  const args = process.argv.slice(2);
  const write = args[0] === "--write-checksums";
  const root = write ? args[1] : args[0];
  if (!root || args.length !== (write ? 2 : 1)) {
    reject(
      releaseExit.usage,
      "usage: verify_release.mjs [--write-checksums] RELEASE_ROOT",
    );
  }
  const result = write
    ? await writeReleaseChecksums(root)
    : await verifyRelease(root);
  const verb = write ? "wrote and checked" : "verified";
  process.stdout.write(
    `${verb} ${result.checksumCount} files for ${result.version} (${result.channel})\n`,
  );
}

const invokedPath = process.argv[1] ? pathToFileURL(path.resolve(process.argv[1])).href : "";
if (import.meta.url === invokedPath) {
  cli().catch(error => {
    const code =
      error instanceof ReleaseContractError
        ? error.exitCode
        : releaseExit.malformed;
    process.stderr.write(`release verifier: ${error.message}\n`);
    process.exit(code);
  });
}
