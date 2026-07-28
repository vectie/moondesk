import { createHash } from "node:crypto";
import {
  mkdtemp,
  mkdir,
  readFile,
  rm,
  writeFile,
} from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";
import test from "node:test";
import assert from "node:assert/strict";

import {
  verifyRelease,
  writeReleaseChecksums,
} from "./verify_release.mjs";

const script = fileURLToPath(new URL("./verify_release.mjs", import.meta.url));
const digest = value =>
  createHash("sha256").update(value).digest("hex");

async function writeJson(file, value) {
  await writeFile(file, `${JSON.stringify(value, null, 2)}\n`);
}

async function fixture(t) {
  const root = await mkdtemp(path.join(tmpdir(), "moondesk-release-verifier-"));
  t.after(() => rm(root, { recursive: true, force: true }));
  const runtimePath =
    "MoonDesk.app/Contents/Resources/lepusa/runtime.json";
  const archivePath = "MoonDesk.app.zip";
  await mkdir(path.join(root, path.dirname(runtimePath)), { recursive: true });
  await writeFile(path.join(root, runtimePath), "runtime\n");
  await writeFile(path.join(root, archivePath), "archive\n");
  await writeFile(path.join(root, "RELEASE_NOTES.md"), "# Preview\n");
  const archiveSha = digest("archive\n");
  const runtimeSha = digest("runtime\n");
  const manifest = {
    kind: "moondesk-release-manifest.v1",
    app: "MoonDesk.app",
    app_name: "MoonDesk.app",
    archive: archivePath,
    archive_sha256: archiveSha,
    runtime_manifest: runtimePath,
    runtime_manifest_sha256: runtimeSha,
    dmg: "",
    dmg_created: false,
    dmg_sha256: "",
    update_manifest: "updates.json",
    release_notes: "RELEASE_NOTES.md",
    version: "0.1.0-preview.4",
    channel: "preview",
    distribution_mode: "self-contained-local-app",
    shell_policy: "lepusa",
    native_host: "lepusa",
    native_window: true,
    signed: false,
    notary_profile_supplied: false,
    notarized: false,
    installer: "zip",
  };
  const updates = {
    kind: "moondesk-update-manifest.v1",
    name: "MoonDesk",
    version: manifest.version,
    channel: manifest.channel,
    notarized: false,
    release_notes: manifest.release_notes,
    artifacts: [
      { kind: "zip", path: archivePath, sha256: archiveSha },
      {
        kind: "runtime-manifest",
        path: runtimePath,
        sha256: runtimeSha,
      },
    ],
  };
  await writeJson(path.join(root, "release-manifest.json"), manifest);
  await writeJson(path.join(root, "updates.json"), updates);
  await writeReleaseChecksums(root);
  return { root, manifest, updates, archivePath, runtimePath };
}

function run(root, ...prefix) {
  return spawnSync(process.execPath, [script, ...prefix, root], {
    encoding: "utf8",
  });
}

test("positive fixture verifies twice without mutation", async t => {
  const release = await fixture(t);
  const before = await readFile(path.join(release.root, "SHA256SUMS"), "utf8");
  const first = await verifyRelease(release.root);
  const second = run(release.root);
  const after = await readFile(path.join(release.root, "SHA256SUMS"), "utf8");
  assert.equal(first.checksumCount, 5);
  assert.equal(second.status, 0, second.stderr);
  assert.match(second.stdout, /verified 5 files/);
  assert.equal(after, before);
});

test("checksum generation refuses an existing checksum file", async t => {
  const release = await fixture(t);
  const result = run(release.root, "--write-checksums");
  assert.equal(result.status, 69);
  assert.match(result.stderr, /refusing overwrite/);
});

test("artifact hash mismatch exits with digest drift", async t => {
  const release = await fixture(t);
  await writeFile(path.join(release.root, release.archivePath), "changed\n");
  const result = run(release.root);
  assert.equal(result.status, 68);
  assert.match(result.stderr, /hash mismatch/);
});

test("absolute artifact path exits with unsafe contract", async t => {
  const release = await fixture(t);
  release.manifest.archive = "/tmp/escape.zip";
  release.updates.artifacts[0].path = "/tmp/escape.zip";
  await writeJson(
    path.join(release.root, "release-manifest.json"),
    release.manifest,
  );
  await writeJson(path.join(release.root, "updates.json"), release.updates);
  const result = run(release.root);
  assert.equal(result.status, 66);
  assert.match(result.stderr, /safe portable path/);
});

test("parent traversal exits with unsafe contract", async t => {
  const release = await fixture(t);
  release.manifest.runtime_manifest = "../runtime.json";
  release.updates.artifacts[1].path = "../runtime.json";
  await writeJson(
    path.join(release.root, "release-manifest.json"),
    release.manifest,
  );
  await writeJson(path.join(release.root, "updates.json"), release.updates);
  const result = run(release.root);
  assert.equal(result.status, 66);
  assert.match(result.stderr, /safe portable path/);
});

test("missing declared artifact exits with missing evidence", async t => {
  const release = await fixture(t);
  await rm(path.join(release.root, release.archivePath));
  const result = run(release.root);
  assert.equal(result.status, 67);
  assert.match(result.stderr, /missing zip artifact/);
});

test("inconsistent notarization exits with unsafe contract", async t => {
  const release = await fixture(t);
  release.manifest.notarized = true;
  release.updates.notarized = true;
  await writeJson(
    path.join(release.root, "release-manifest.json"),
    release.manifest,
  );
  await writeJson(path.join(release.root, "updates.json"), release.updates);
  const result = run(release.root);
  assert.equal(result.status, 66);
  assert.match(result.stderr, /require signing, credentials, and a DMG/);
});

test("extra checksum entry exits with checksum drift", async t => {
  const release = await fixture(t);
  const sums = await readFile(path.join(release.root, "SHA256SUMS"), "utf8");
  const lines = sums.trimEnd().split("\n");
  lines.push(`${"0".repeat(64)}  extra.bin`);
  await writeFile(
    path.join(release.root, "SHA256SUMS"),
    `${lines.sort().join("\n")}\n`,
  );
  const result = run(release.root);
  assert.equal(result.status, 68);
  assert.match(result.stderr, /extra checksum entry/);
});
