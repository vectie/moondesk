# Unsigned Preview Release Proof — 2026-07-27

This record preserves the local evidence for the
`0.1.0-preview.4` unsigned macOS arm64 candidate. The candidate was built only
to prove the release path and was not published. The temporary binary output
was moved to Trash after the evidence below was captured.

## Evidence boundary

This proof establishes that the current local source can:

- build an unsigned application bundle, ZIP archive, and DMG from a fresh
  output path
- emit portable, versioned release and update manifests
- generate exact checksums once and verify the same output repeatedly without
  mutation
- reject both wrapper and direct-command attempts to reuse a populated output
  root
- run the verifier's positive and negative fixture suite

It does not establish a remote workflow run, a hosted artifact, independent
remote reproduction, signing, notarization, stapling, clean-machine
installation, update, rollback, or long-running reliability.

## Phase A — source validation

The validation slice used the project warning policy and current generated
interfaces:

```sh
moon check --target all --warn-list +73 --diagnostic-limit 1000
moon test
npm --prefix ui/rabbita-desk test
npm --prefix ui/rabbita-desk run test:i18n
moon info
moon fmt
scripts/validate.sh fast
```

Final local counts were:

| Suite | Result |
| --- | ---: |
| Native MoonBit | 231/231 |
| UI MoonBit JavaScript | 379/379 |
| Localization | 3/3 |
| Focused release-command tests | 4/4 |
| Node release-verifier fixtures | 8/8 |
| UI warnings | 0 |

Shell syntax, Node syntax, workflow YAML parsing, generated-interface review,
and `git diff --check` also passed. The full validator was not used as a
closeout command in the dirty working tree because its final gate requires a
clean generated tree. Its new release-verifier stage was run independently,
and the previously retained clean-checkout full proof remains in
`FULL_VALIDATION_PROOF_2026-07-27.md`.

## Phase B — fresh candidate build

The canonical wrapper was invoked with an absolute path that did not exist:

```sh
sh scripts/preview_release.sh \
  --version 0.1.0-preview.4 \
  --notes docs/releases/0.1.0-preview.4.md \
  --out /Users/kq/Workspace/moondesk/.command041-preview-output
```

The wrapper completed the production UI build, Lepusa verification and bundle
checks, app construction, ZIP and DMG creation, one-time checksum generation,
and two read-only verification passes. Its terminal result was:

```text
release complete: .../MoonDesk.app (lepusa, signed=false, notarized=false, dmg=true)
wrote and checked 6 files for 0.1.0-preview.4 (preview)
verified 6 files for 0.1.0-preview.4 (preview)
verified 6 files for 0.1.0-preview.4 (preview)
preview release verified: .../.command041-preview-output
```

The app contained 12 regular files and no symbolic links. The release root
contained:

| Path | Bytes |
| --- | ---: |
| `MoonDesk.app.zip` | 2,867,686 |
| `MoonDesk.app/Contents/Resources/lepusa/runtime.json` | 23,913 |
| `moondesk-0.1.0-preview.4-macos-arm64.dmg` | 3,533,743 |
| `RELEASE_NOTES.md` | 1,204 |
| `release-manifest.json` | 946 |
| `updates.json` | 1,004 |
| `SHA256SUMS` | 558 |

## Phase C — portable metadata contract

`release-manifest.json` used kind `moondesk-release-manifest.v1`, version
`0.1.0-preview.4`, channel `preview`, and reported `signed=false`,
`notarized=false`, and `installer=dmg`.

`updates.json` used kind `moondesk-update-manifest.v1` and agreed on version,
channel, runtime policy, notarization state, release notes, and all three
artifacts.

Every public path was release-root-relative. A targeted scan found no user
home, repository, temporary, runner, absolute, or parent-traversal path in
either manifest.

## Phase D — exact digest evidence

The candidate's bytewise-sorted `SHA256SUMS` was:

```text
02940c5e81fb551b5e5df965cd4f6d7893978358ae58c47cb58e098c2505c1be  moondesk-0.1.0-preview.4-macos-arm64.dmg
24ce319c82c61a041b745fae7db02567aafe0f95ce785404823e8203f6e7e52d  MoonDesk.app/Contents/Resources/lepusa/runtime.json
3b9f2175c360d9684b3ac70cb54fdc1d9ce3d9001f5a87f2b176579ae8d33852  RELEASE_NOTES.md
7a4aeed244300c48778a81f51dc185847dd53185887aa0d51203ad394b9431da  MoonDesk.app.zip
c528ef89d4fc2f4d26c77d770e7b9d1453fff0fa9c22fd1a86eb2abd53d3b3fe  release-manifest.json
e0daff5e88991b5b76481d46f118d16e3a4a6fcbf8c0f78b270a73d89612da4a  updates.json
```

These hashes identify this disposable local candidate only. They are not
published-release hashes and must not be copied into the release note as remote
evidence.

## Phase E — immutability and repeat verification

A complete regular-file hash snapshot was captured before each refusal check
and compared afterward.

Repeating the wrapper against the populated output returned:

```text
exit 69
preview release: output already exists; refusing overwrite: .../.command041-preview-output
```

Invoking the lower-level command against the same populated output returned:

```text
exit 1
release failed: output directory is not empty; refusing overwrite: .../.command041-preview-output
```

Both before/after snapshots were identical. Two additional verifier calls then
reported:

```text
verified 6 files for 0.1.0-preview.4 (preview)
verified 6 files for 0.1.0-preview.4 (preview)
```

This proves repeat verification is read-only and both supported release entry
points refuse silent artifact replacement.

## Phase F — next gate

The local implementation slice is complete. Phase 2 remains open until the
workflow exists on the remote default branch and retained pull-request, push,
and preview-tag runs pass. The tag artifact must then be downloaded, verified,
and reproduced independently. Credentialed and clean-machine qualification
remain later gates.
