#!/usr/bin/env node

import { createHash } from "node:crypto";
import { mkdir, readFile, rm, writeFile } from "node:fs/promises";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const repo = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const root = path.join(repo, "_build", "phase9-smoke");
const release = path.join(root, "release");
const script = path.join(repo, "scripts/phase9_release.mjs");
const run = (args, expected = 0, env = process.env) => {
  const result = spawnSync(process.execPath, [script, ...args], { encoding: "utf8", env });
  if (result.status !== expected) throw new Error(`${args[0]} expected ${expected}, got ${result.status}: ${result.stderr}`);
  return result;
};
const sha = value => createHash("sha256").update(value).digest("hex");

await rm(root, { recursive: true, force: true });
await mkdir(path.join(release, "MoonDesk.app/Contents/Resources/lepusa"), { recursive: true });
await writeFile(path.join(release, "MoonDesk.app.zip"), "archive\n");
await writeFile(path.join(release, "MoonDesk.app/Contents/Resources/lepusa/runtime.json"), "runtime\n");
await writeFile(path.join(release, "RELEASE_NOTES.md"), "# Smoke\n");
const manifest = { kind: "moondesk-release-manifest.v1", version: "0.1.0-preview.99", channel: "preview", update_manifest: "updates.json", runtime_manifest: "MoonDesk.app/Contents/Resources/lepusa/runtime.json", release_notes: "RELEASE_NOTES.md", signed: false, notarized: false, dmg_created: false };
const updates = { kind: "moondesk-update-manifest.v1", version: manifest.version, channel: manifest.channel, notarized: false, artifacts: [{ kind: "zip", path: "MoonDesk.app.zip", sha256: sha("archive\n") }, { kind: "runtime-manifest", path: manifest.runtime_manifest, sha256: sha("runtime\n") }] };
await writeFile(path.join(release, "release-manifest.json"), `${JSON.stringify(manifest, null, 2)}\n`);
await writeFile(path.join(release, "updates.json"), `${JSON.stringify(updates, null, 2)}\n`);
run(["identity", "--root", release, "--source-commit", "f4a98028ccd02e13f0e069edba928211da7ca5e3"]);
const channel = path.join(root, "preview.json");
run(["channel", "--release-root", release, "--channel", "preview", "--targets", path.join(repo, "config/phase9-supported-targets.json"), "--out", channel]);
const updatesBefore = await readFile(path.join(release, "updates.json"), "utf8");
await writeFile(path.join(release, "updates.json"), `${updatesBefore}\n`);
run(["channel", "--release-root", release, "--channel", "preview", "--targets", path.join(repo, "config/phase9-supported-targets.json"), "--out", path.join(root, "drifted-preview.json")], 68);
await writeFile(path.join(release, "updates.json"), updatesBefore);
const identityBefore = await readFile(path.join(release, "release-identity.json"), "utf8");
const mismatchedUpdates = `${JSON.stringify({ ...updates, version: "0.1.0-preview.100" }, null, 2)}\n`;
await writeFile(path.join(release, "updates.json"), mismatchedUpdates);
const synchronizedIdentity = { ...JSON.parse(identityBefore), update_manifest_sha256: sha(mismatchedUpdates) };
await writeFile(path.join(release, "release-identity.json"), `${JSON.stringify(synchronizedIdentity, null, 2)}\n`);
run(["channel", "--release-root", release, "--channel", "preview", "--targets", path.join(repo, "config/phase9-supported-targets.json"), "--out", path.join(root, "identity-mismatch-preview.json")], 68);
await writeFile(path.join(release, "updates.json"), updatesBefore);
await writeFile(path.join(release, "release-identity.json"), identityBefore);
run(["validate-channel", channel]);
run(["identity", "--root", release, "--source-commit", "f4a98028ccd02e13f0e069edba928211da7ca5e3"], 69);
if (await readFile(path.join(release, "release-identity.json"), "utf8") !== identityBefore) throw new Error("immutable identity changed");
const unsignedEnv = { ...process.env }; delete unsignedEnv.MOONDESK_UPDATE_PRIVATE_KEY_FILE;
run(["sign-metadata", "--input", channel, "--out", `${channel}.signature.json`], 67, unsignedEnv);
const credentialEnv = { ...unsignedEnv }; delete credentialEnv.MOONDESK_DEVELOPER_ID_APPLICATION; delete credentialEnv.MOONDESK_NOTARY_KEYCHAIN_PROFILE;
run(["credentialed", "--app", "missing.app", "--archive", "missing.zip", "--dmg", "missing.dmg"], 67, credentialEnv);
const plan = JSON.parse(run(["plan", "--app", "MoonDesk.app", "--archive", "MoonDesk.app.zip", "--dmg", "MoonDesk.dmg"]).stdout);
const expected = ["Developer ID signing", "app signature verification", "temporary app notary upload creation", "app notarization", "app stapling", "app staple validation", "distributed ZIP creation from stapled app", "DMG creation from stapled app", "DMG signing", "DMG notarization", "DMG stapling", "DMG staple validation", "internal manifest/checksum reconciliation"];
if (JSON.stringify(plan.map(step => step.label)) !== JSON.stringify(expected)) throw new Error("credentialed command order drift");
if (plan.at(-1).command !== "internal") throw new Error("finalization must remain internal");
run(["finalize", "--app", "x"], 64);
run(["proof", "--out", path.join(root, "proof.json")], 64);
await writeFile(path.join(root, "bad-targets.json"), '{"kind":"moondesk-supported-targets.v1","platform":"macos","minimum_macos":"14","architectures":[]}\n');
run(["channel", "--release-root", release, "--channel", "preview", "--targets", path.join(root, "bad-targets.json"), "--out", path.join(root, "bad-channel.json")], 65);
console.log(`phase9 non-credentialed smoke passed; deliverables: ${path.relative(repo, root)}`);
