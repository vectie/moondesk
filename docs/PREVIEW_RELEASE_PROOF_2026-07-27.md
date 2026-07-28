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

## Phase F — retained Preview 11 evidence

The immutable annotated tag `v0.1.0-preview.11` peels to source commit
`01e5b4d0ed468d12cea8271011dd3147c079f2fb`. GitHub retained successful push
run [`30335949331`](https://github.com/vectie/moondesk/actions/runs/30335949331)
for that exact SHA. Its `preview` job is
[`90200737627`](https://github.com/vectie/moondesk/actions/runs/30335949331/job/90200737627),
ran from 2026-07-28 06:46:37 through 06:50:09 UTC, and completed successfully.
The API reports runner `GitHub Actions 1000001278`, runner group
`GitHub Actions`, and labels `["macos-14"]`; the workflow also declares
`macos-14`. No more specific hosted image version was retained, so none is
claimed here.

The non-overwriting uploaded artifact is:

| Field | Retained value |
| --- | --- |
| Artifact ID | `8679181026` |
| Name | `moondesk-0.1.0-preview.11-01e5b4d0ed468d12cea8271011dd3147c079f2fb-macos-arm64-unsigned` |
| API size | 18,011,747 bytes |
| Created | 2026-07-28 06:50:01 UTC |
| Expiration recorded by API | 2026-08-11 06:49:58 UTC |

The unchanged download is retained in ignored lane
`.moonsuite/phase2-preview11/download`. The repository-defined read-only
command

```sh
node scripts/verify_release.mjs .moonsuite/phase2-preview11/download
```

reported `verified 6 files for 0.1.0-preview.11 (preview)`. An independent
`shasum -a 256 -c SHA256SUMS` pass reported all six entries `OK`.

## Phase G — clean-checkout rebuild and comparison

The exact tagged source was materialized beneath the ignored rebuild lane, and
all output remained inside that checkout. No `..` segment was used. The
effective commands were:

```sh
rm -rf .moonsuite/phase2-preview11-rebuild
mkdir -p .moonsuite/phase2-preview11-rebuild/checkout
git archive 01e5b4d0ed468d12cea8271011dd3147c079f2fb |
  tar -x -C .moonsuite/phase2-preview11-rebuild/checkout
cd .moonsuite/phase2-preview11-rebuild/checkout
npm ci --prefix ui/rabbita-desk
scripts/validate.sh full
sh scripts/preview_release.sh \
  --version 0.1.0-preview.11 \
  --notes docs/releases/0.1.0-preview.11.md \
  --out "$PWD/.moonsuite/rebuild-output"
node scripts/verify_release.mjs .moonsuite/rebuild-output
```

The clean full validator passed with 260 native tests, 422 UI tests, five
localization tests, eight release-verifier fixtures, and its remaining build,
interface, smoke, and cleanliness gates. The preview wrapper and final
read-only verifier also passed.

The stable release contract compares as follows:

- exact equality: version `0.1.0-preview.11`, channel `preview`, manifest kinds,
  declared artifact names and paths, unsigned/notarized/DMG state, install
  instructions, and `RELEASE_NOTES.md` bytes (SHA-256
  `e3c796ef78273d2a8e886d1c35a45f0b667f87632d42c2f5285ff928ce6c7430`)
- exact differences: runtime-manifest digest
  `0d98e7099df3519e3fcb7f5e6a9e7a78be343355f3af8d7e03240cb21bdfac1e`
  became `4fce392e6167c9dbdf05bd69ee9c51958c0993175b22810f83124610ca7e24d3`;
  ZIP `6efeeb75d7b376467c60170dab757cd7dd1845e9a0ccc6a008584aaf3ad32a28`
  became `f155acfc5d58172a88614c3d6dd92e3a22392910d44926aabb3987c50c1f9902`;
  DMG `3ec47f3c12b383f98b2f3a13ff544077b818c432fc8e8b55fab002829612bfe9`
  became `53db176a53bbb422d8ae9a0e2c34827da5a6c6f5233e502fbc55789db0af2df7`
- those embedded digests also change `release-manifest.json`, `updates.json`,
  and `SHA256SUMS`; downloaded/rebuilt ZIP sizes are 2,956,919/2,951,978 bytes
  and DMG sizes are 3,643,529/3,636,873 bytes
- the runtime manifest contains build-host absolute source paths, so its hosted
  and local macOS 26.2 forms differ; ZIP/DMG packaging also carries
  host/toolchain and timestamp-sensitive bytes

Both outputs independently satisfy the strict repository verifier, but this is
contract reproducibility, not byte identity. It does not establish signing,
notarization, stapling, clean-machine installation, update/rollback, or soak
evidence; those remain Phase 9 work.

**Phase 2 gate result:** complete. The retained pull-request and default-branch
CI runs, immutable Preview 11 run and artifact, downloaded-artifact
verification, and clean-checkout rebuild close the Phase 2 evidence gate
without claiming byte-for-byte reproducibility.
