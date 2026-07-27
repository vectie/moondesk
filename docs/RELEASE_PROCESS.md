# MoonDesk Release Process

Last updated: 2026-07-27.

## Status and evidence boundary

The repository contains a local CI workflow and an unsigned-preview workflow.
Local validation and release-fixture evidence do not prove that either workflow
has run on the remote default branch. Phase 2 remains open until clean
pull-request, push, and version-tag runs are retained and a tag artifact is
reproduced independently.

The exact disposable-candidate commands, sizes, hashes, refusal checks, and
test counts are retained in
[`PREVIEW_RELEASE_PROOF_2026-07-27.md`](PREVIEW_RELEASE_PROOF_2026-07-27.md).

Unsigned previews are test artifacts. They are not signed, notarized,
clean-machine-qualified production releases. Credentialed signing,
notarization, update hosting, clean-machine installation, and rollback remain
later distribution gates.

## Version and tag policy

Preview versions use:

```text
MAJOR.MINOR.PATCH-preview.NUMBER
```

The matching immutable tag has a leading `v`, for example:

```text
v0.1.0-preview.4
```

The release-note source is `docs/releases/<version>.md`. A released note is
never edited to describe a different artifact. Corrections require a new
preview number. Every user-visible change first receives one concise entry in
the `Unreleased` section of `CHANGELOG.md`.

## Phase A: Validate a clean source state

Install pinned project dependencies, then run:

```sh
scripts/validate.sh full
```

Full validation covers formatting, all-target checks, native and UI tests,
localization, release-verifier positive/negative fixtures, the production UI
build, generated-interface stability, optional configured boundary checks,
whitespace, and generated-tree cleanliness.

## Phase B: Build a fresh unsigned preview

The canonical local command is:

```sh
sh scripts/preview_release.sh \
  --version 0.1.0-preview.4 \
  --notes docs/releases/0.1.0-preview.4.md \
  --out /absolute/fresh/path/moondesk-0.1.0-preview.4
```

The output path must be absolute and must not exist. The wrapper refuses even
an empty existing directory. It creates temporary workspace and UI-build
directories, builds the production UI, invokes the existing native release
command with explicit version/channel and unsigned mode, copies the release
notes, generates `SHA256SUMS` once, and verifies the result twice without
mutation.

The wrapper requires macOS because the native bundle, archive, and DMG tools
are macOS-specific. Temporary workspace and UI directories are removed on
exit. A partial release output is intentionally retained after failure for
diagnosis; it cannot be overwritten by a retry. Move it aside or to Trash and
start with a new path.

## Phase C: Verify the artifact contract

Each release root contains:

- `MoonDesk.app`
- `MoonDesk.app.zip`
- `moondesk-<version>-macos-arm64.dmg`
- the packaged `MoonDesk.app/Contents/Resources/lepusa/runtime.json`
- `release-manifest.json`
- `updates.json`
- `RELEASE_NOTES.md`
- sorted `SHA256SUMS`

Public JSON uses only safe release-root-relative paths. It does not contain
workspace, UI, dependency-cache, temporary, runner, or user-home paths.

Run the read-only verifier with:

```sh
node scripts/verify_release.mjs /absolute/release/root
```

Checksum generation is a separate one-time operation:

```sh
node scripts/verify_release.mjs --write-checksums /absolute/release/root
```

Generation exits 69 if `SHA256SUMS` already exists. Verification checks manifest
kind, version/channel agreement, portable confined paths, app/artifact
existence, SHA-256 values, signing/notarization/installer consistency, release
notes, exact checksum coverage, and checksum ordering.

Stable failure classes are:

| Exit | Meaning |
| --- | --- |
| 64 | Invalid command usage |
| 65 | Malformed JSON or schema |
| 66 | Unsafe path or inconsistent release contract |
| 67 | Missing release evidence |
| 68 | Artifact digest or checksum drift |
| 69 | Immutable output would be overwritten |

## Phase D: Remote unsigned-preview workflow

`.github/workflows/preview-release.yml` runs on matching preview tags and
explicit manual dispatch. It uses `macos-14`, read-only repository permission,
per-ref concurrency cancellation, Node 22, `npm ci`, full validation, the
canonical wrapper, an independent final verification, and a uniquely named
artifact containing the version and commit SHA. Artifact overwrite is disabled
and retention is bounded.

The workflow does not create, edit, or replace a hosted release. Its first
successful tag run must be retained before the local Phase 2 implementation can
be called active remote evidence.

## Phase E: Credentialed production boundary

Credentialed operation requires both values:

```sh
sh scripts/preview_release.sh \
  --version <version> \
  --notes <release-note-file> \
  --out <fresh-absolute-output> \
  --sign-identity <developer-id-identity> \
  --notary-profile <keychain-profile>
```

Supplying only one credential input is rejected. When credentials are
requested, signing, notarization, and stapling failures are terminal. A
credential name is never serialized into public release metadata; only the
fact that a profile was supplied is recorded.

This command path does not itself prove production readiness. Production still
requires protected credentials, a retained remote run, hosted immutable
checksums and update metadata, clean-machine install/update/rollback evidence,
and the Phase 8 reliability qualification.

## Phase F: Promote evidence, not local bytes

After a clean pull request and push are green:

1. Create the matching immutable preview tag.
2. Retain the workflow run URL, source commit, runner image, and uploaded
   artifact identifier.
3. Download the artifact into a fresh verification root.
4. Run `node scripts/verify_release.mjs <root>` without generating or replacing
   checksums.
5. Rebuild the same version from the tagged source in an independent clean
   checkout.
6. Compare the contract, declared artifacts, and reproducible portions. Record
   any platform-container bytes that are expected to vary.
7. If any check fails, preserve the failed output for diagnosis and issue a new
   preview number. Never replace the tag or artifact.

Only those retained remote and independent results can close the Phase 2
release-evidence gate.
