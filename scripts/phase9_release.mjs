#!/usr/bin/env node

import { createHash, createPrivateKey, sign } from "node:crypto";
import { mkdir, readFile, rename, rm, stat, writeFile } from "node:fs/promises";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const exit = Object.freeze({ usage: 64, invalid: 65, unsafe: 66, missing: 67, drift: 68, immutable: 69 });
function fail(code, message) { const error = new Error(message); error.exitCode = code; throw error; }
function object(value, label) { if (!value || typeof value !== "object" || Array.isArray(value)) fail(exit.invalid, `${label} must be an object`); return value; }
function string(value, label) { if (typeof value !== "string" || value.length === 0) fail(exit.invalid, `${label} must be a non-empty string`); return value; }
function sha(value, label) { if (typeof value !== "string" || !/^[0-9a-f]{64}$/.test(value)) fail(exit.invalid, `${label} must be a lowercase SHA-256`); return value; }
function portable(value, label) {
  string(value, label);
  if (value.includes("\\") || value.includes("\0") || path.posix.isAbsolute(value) || value.split("/").some(part => !part || part === "." || part === "..")) fail(exit.unsafe, `${label} must be a safe portable path`);
  return value;
}
function versionForChannel(version, channel) {
  string(version, "version");
  if (channel === "preview" && !/^\d+\.\d+\.\d+-preview\.\d+$/.test(version)) fail(exit.invalid, "preview channel requires MAJOR.MINOR.PATCH-preview.NUMBER");
  if (channel === "stable" && !/^\d+\.\d+\.\d+$/.test(version)) fail(exit.invalid, "stable channel requires MAJOR.MINOR.PATCH");
  if (channel !== "preview" && channel !== "stable") fail(exit.invalid, "channel must be stable or preview");
}
function requiredEnvironment(name) { const value = process.env[name]; if (!value) fail(exit.missing, `protected environment input ${name} is required`); return value; }
async function jsonFile(file) {
  try { return object(JSON.parse(await readFile(file, "utf8")), path.basename(file)); }
  catch (error) { if (error?.code === "ENOENT") fail(exit.missing, `missing ${file}`); if (error.exitCode) throw error; fail(exit.invalid, `${file}: ${error.message}`); }
}
async function digest(file) { return createHash("sha256").update(await readFile(file)).digest("hex"); }
async function writeFresh(file, value) {
  try { await stat(file); fail(exit.immutable, `refusing overwrite: ${file}`); } catch (error) { if (error?.code !== "ENOENT") throw error; }
  await mkdir(path.dirname(file), { recursive: true });
  await writeFile(file, value, { flag: "wx", mode: 0o600 });
}
function run(command, args, label) {
  const result = spawnSync(command, args, { stdio: "inherit" });
  if (result.error) fail(exit.missing, `${label}: ${result.error.message}`);
  if (result.status !== 0) fail(exit.invalid, `${label} exited ${result.status}`);
}

async function commandIdentity(args) {
  if (args.length !== 4 || args[0] !== "--root" || args[2] !== "--source-commit") fail(exit.usage, "identity --root DIR --source-commit COMMIT");
  const root = path.resolve(args[1]);
  const manifestPath = path.join(root, "release-manifest.json");
  const manifest = await jsonFile(manifestPath);
  const updatesPath = path.join(root, portable(manifest.update_manifest, "manifest.update_manifest"));
  const updates = await jsonFile(updatesPath);
  versionForChannel(manifest.version, manifest.channel);
  if (updates.version !== manifest.version || updates.channel !== manifest.channel) fail(exit.drift, "release and update manifest identity mismatch");
  const identity = { kind: "moondesk-release-identity.v1", product: "MoonDesk", version: manifest.version, channel: manifest.channel, source_commit: string(args[3], "source commit"), release_manifest: "release-manifest.json", release_manifest_sha256: await digest(manifestPath), update_manifest: manifest.update_manifest, update_manifest_sha256: await digest(updatesPath) };
  await writeFresh(path.join(root, "release-identity.json"), `${JSON.stringify(identity, null, 2)}\n`);
  console.log(`release identity written: ${identity.version} ${identity.channel}`);
}

async function commandChannel(args) {
  if (args.length !== 8 || args[0] !== "--release-root" || args[2] !== "--channel" || args[4] !== "--targets" || args[6] !== "--out") fail(exit.usage, "channel --release-root DIR --channel stable|preview --targets FILE --out FILE");
  const releaseRoot = path.resolve(args[1]);
  const channel = args[3];
  const targets = await jsonFile(path.resolve(args[5]));
  if (targets.kind !== "moondesk-supported-targets.v1" || targets.platform !== "macos" || !/^\d+\.\d+$/.test(targets.minimum_macos) || !Array.isArray(targets.architectures) || targets.architectures.length === 0 || targets.architectures.some(value => !/^[a-z0-9_]+$/.test(value))) fail(exit.invalid, "supported target policy is invalid");
  const identity = await jsonFile(path.join(releaseRoot, "release-identity.json"));
  const manifestPath = path.join(releaseRoot, "release-manifest.json");
  const manifest = await jsonFile(manifestPath);
  versionForChannel(identity.version, channel);
  if (identity.channel !== channel) fail(exit.drift, "requested channel differs from release identity");
  const updateManifest = portable(identity.update_manifest, "identity.update_manifest");
  if (manifest.update_manifest !== updateManifest) fail(exit.drift, "release identity update manifest mismatch");
  const updatesPath = path.join(releaseRoot, updateManifest);
  const updates = await jsonFile(updatesPath);
  if (sha(identity.release_manifest_sha256, "identity.release_manifest_sha256") !== await digest(manifestPath) || sha(identity.update_manifest_sha256, "identity.update_manifest_sha256") !== await digest(updatesPath)) fail(exit.drift, "release identity digest drift");
  if (updates.version !== identity.version || updates.channel !== channel) fail(exit.drift, "release identity and update manifest identity mismatch");
  const metadata = { kind: "moondesk-update-channel.v1", channel, version: identity.version, compatibility: { platform: targets.platform, architectures: targets.architectures, minimum_macos: targets.minimum_macos }, hosted: false, release_identity: "release-identity.json", release_identity_sha256: await digest(path.join(releaseRoot, "release-identity.json")), update_manifest: identity.update_manifest, update_manifest_sha256: sha(identity.update_manifest_sha256, "identity.update_manifest_sha256"), artifacts: updates.artifacts, rollback: "Install the preceding immutable release after preserving user libraries and settings; never downgrade user data without a tested migration path." };
  await writeFresh(path.resolve(args[7]), `${JSON.stringify(metadata, null, 2)}\n`);
  console.log(`channel metadata written without hosting claim: ${args[7]}`);
}

async function commandValidateChannel(args) {
  if (args.length !== 1) fail(exit.usage, "validate-channel FILE");
  const metadata = await jsonFile(path.resolve(args[0]));
  if (metadata.kind !== "moondesk-update-channel.v1") fail(exit.invalid, "unexpected channel metadata kind");
  versionForChannel(metadata.version, metadata.channel);
  if (metadata.hosted !== false) fail(exit.invalid, "repository-local channel metadata must not claim hosting");
  sha(metadata.release_identity_sha256, "release identity digest"); sha(metadata.update_manifest_sha256, "update manifest digest"); object(metadata.compatibility, "compatibility");
  if (!Array.isArray(metadata.artifacts) || metadata.artifacts.length === 0) fail(exit.invalid, "channel artifacts must be non-empty");
  for (const [index, artifact] of metadata.artifacts.entries()) { object(artifact, `artifacts[${index}]`); portable(artifact.path, `artifacts[${index}].path`); sha(artifact.sha256, `artifacts[${index}].sha256`); }
  console.log(`channel metadata verified: ${metadata.channel} ${metadata.version}`);
}

async function commandSignMetadata(args) {
  if (args.length !== 4 || args[0] !== "--input" || args[2] !== "--out") fail(exit.usage, "sign-metadata --input FILE --out FILE");
  const key = createPrivateKey({ key: await readFile(requiredEnvironment("MOONDESK_UPDATE_PRIVATE_KEY_FILE")), passphrase: process.env.MOONDESK_UPDATE_PRIVATE_KEY_PASSPHRASE });
  if (key.asymmetricKeyType !== "ed25519") fail(exit.invalid, "update signing key must be Ed25519");
  const input = path.resolve(args[1]); const payload = await readFile(input);
  const envelope = { kind: "moondesk-update-signature.v1", algorithm: "Ed25519", payload: path.basename(input), payload_sha256: createHash("sha256").update(payload).digest("hex"), signature_base64: sign(null, payload, key).toString("base64") };
  await writeFresh(path.resolve(args[3]), `${JSON.stringify(envelope, null, 2)}\n`);
}

export function credentialedCommandPlan({ app, uploadArchive, archive, dmg, identity, profile, entitlements }) {
  return [
    ["codesign", ["--force", "--deep", "--options", "runtime", "--timestamp", "--entitlements", entitlements, "--sign", identity, app], "Developer ID signing"],
    ["codesign", ["--verify", "--deep", "--strict", app], "app signature verification"],
    ["ditto", ["-c", "-k", "--keepParent", app, uploadArchive], "temporary app notary upload creation"],
    ["xcrun", ["notarytool", "submit", uploadArchive, "--keychain-profile", profile, "--wait"], "app notarization"],
    ["xcrun", ["stapler", "staple", app], "app stapling"],
    ["xcrun", ["stapler", "validate", app], "app staple validation"],
    ["ditto", ["-c", "-k", "--keepParent", app, archive], "distributed ZIP creation from stapled app"],
    ["hdiutil", ["create", "-volname", "MoonDesk", "-srcfolder", app, "-ov", "-format", "UDZO", dmg], "DMG creation from stapled app"],
    ["codesign", ["--force", "--timestamp", "--sign", identity, dmg], "DMG signing"],
    ["xcrun", ["notarytool", "submit", dmg, "--keychain-profile", profile, "--wait"], "DMG notarization"],
    ["xcrun", ["stapler", "staple", dmg], "DMG stapling"],
    ["xcrun", ["stapler", "validate", dmg], "DMG staple validation"],
    ["internal", ["reconcile-release-manifests", archive, dmg], "internal manifest/checksum reconciliation"],
  ];
}

async function reconcileRelease(releaseRoot, app, archive, dmg) {
  const manifestPath = path.join(releaseRoot, "release-manifest.json"); const updatesPath = path.join(releaseRoot, "updates.json");
  const manifest = await jsonFile(manifestPath); const updates = await jsonFile(updatesPath);
  const runtimePath = portable(manifest.runtime_manifest, "manifest.runtime_manifest");
  const archiveSha = await digest(archive); const runtimeSha = await digest(path.join(releaseRoot, runtimePath)); const dmgSha = await digest(dmg);
  const finalManifest = { ...manifest, app: path.basename(app), app_name: path.basename(app), archive: path.basename(archive), archive_sha256: archiveSha, runtime_manifest_sha256: runtimeSha, dmg: path.basename(dmg), dmg_created: true, dmg_sha256: dmgSha, signed: true, notary_profile_supplied: true, notarized: true, installer: "dmg" };
  const finalUpdates = { ...updates, notarized: true, artifacts: [{ kind: "zip", path: path.basename(archive), sha256: archiveSha }, { kind: "dmg", path: path.basename(dmg), sha256: dmgSha }, { kind: "runtime-manifest", path: runtimePath, sha256: runtimeSha }] };
  const temporaries = [`${manifestPath}.phase9-new`, `${updatesPath}.phase9-new`];
  try {
    for (const temporary of temporaries) await rm(temporary, { force: true });
    for (const [file, value] of [[manifestPath, finalManifest], [updatesPath, finalUpdates]]) await writeFile(`${file}.phase9-new`, `${JSON.stringify(value, null, 2)}\n`, { flag: "wx" });
    await rename(temporaries[0], manifestPath); await rename(temporaries[1], updatesPath);
  } finally {
    for (const temporary of temporaries) await rm(temporary, { force: true });
  }
  await rm(path.join(releaseRoot, "SHA256SUMS"), { force: true });
  const verifier = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "verify_release.mjs");
  run(process.execPath, [verifier, "--write-checksums", releaseRoot], "final checksum generation"); run(process.execPath, [verifier, releaseRoot], "final release verification");
}

async function commandCredentialed(args) {
  if (args.length !== 6 || args[0] !== "--app" || args[2] !== "--archive" || args[4] !== "--dmg") fail(exit.usage, "credentialed --app APP --archive ZIP --dmg DMG");
  if (process.platform !== "darwin") fail(exit.missing, "credentialed distribution requires macOS");
  const identity = requiredEnvironment("MOONDESK_DEVELOPER_ID_APPLICATION"); const profile = requiredEnvironment("MOONDESK_NOTARY_KEYCHAIN_PROFILE"); requiredEnvironment("MOONDESK_UPDATE_PRIVATE_KEY_FILE");
  const app = path.resolve(args[1]); const archive = path.resolve(args[3]); const dmg = path.resolve(args[5]);
  const releaseRoot = path.dirname(app);
  if (path.dirname(archive) !== releaseRoot || path.dirname(dmg) !== releaseRoot) fail(exit.unsafe, "app, archive, and DMG must be direct entries in one release root");
  const uploadArchive = `${archive}.notary-upload.zip`;
  const plan = credentialedCommandPlan({ app, uploadArchive, archive, dmg, identity, profile, entitlements: path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../packaging/macos/MoonDesk.entitlements") });
  await rm(uploadArchive, { force: true });
  await rm(archive, { force: true }); await rm(dmg, { force: true });
  try { for (const [command, commandArgs, label] of plan.slice(0, -1)) run(command, commandArgs, label); await reconcileRelease(releaseRoot, app, archive, dmg); }
  finally { await rm(uploadArchive, { force: true }); }
  console.log("credentialed artifacts and existing release manifests finalized");
}

async function commandPlan(args) {
  if (args.length !== 6 || args[0] !== "--app" || args[2] !== "--archive" || args[4] !== "--dmg") fail(exit.usage, "plan --app APP --archive ZIP --dmg DMG");
  const plan = credentialedCommandPlan({ app: args[1], uploadArchive: `${args[3]}.notary-upload.zip`, archive: args[3], dmg: args[5], identity: "${MOONDESK_DEVELOPER_ID_APPLICATION}", profile: "${MOONDESK_NOTARY_KEYCHAIN_PROFILE}", entitlements: "packaging/macos/MoonDesk.entitlements" });
  console.log(JSON.stringify(plan.map(([command, commandArgs, label]) => ({ command, args: commandArgs, label })), null, 2));
}

async function main() {
  const [command, ...args] = process.argv.slice(2);
  if (command === "identity") await commandIdentity(args); else if (command === "channel") await commandChannel(args); else if (command === "validate-channel") await commandValidateChannel(args); else if (command === "sign-metadata") await commandSignMetadata(args); else if (command === "credentialed") await commandCredentialed(args); else if (command === "plan") await commandPlan(args); else fail(exit.usage, "commands: identity, channel, validate-channel, sign-metadata, plan, credentialed");
}
main().catch(error => { console.error(`phase9 release: ${error.message}`); process.exitCode = error.exitCode ?? 1; });
