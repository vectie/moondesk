# Phase 9 native distribution report

Date: 2026-07-30
Status: repository-owned work implemented; Phase 9 external exit evidence remains blocked.

## Repository-local implementation

MoonDesk reuses the existing `preview_release.sh`, MoonBit bundle/release command, `verify_release.mjs`, CI, and preview workflow. Phase 9 adds no parallel packager. It adds:

- immutable `release-identity.json` binding version, channel, source commit, and SHA-256 digests of existing release/update manifests
- validated stable/preview metadata consuming versioned `config/phase9-supported-targets.json` policy and setting `hosted: false`
- Ed25519 update-metadata signing from `MOONDESK_UPDATE_PRIVATE_KEY_FILE` only
- a credentialed macOS command path that signs the app, notarizes/staples/validates it, recreates the archive and DMG, signs and separately notarizes/staples/validates the distributed DMG, then reconciles final artifact hashes; afterward, `preview_release.sh` generates release identity and channel metadata and signs that channel metadata; absent protected inputs fail rather than falling back
- clean-machine, lifecycle, and soak evidence contracts/checklists
- thresholds frozen before a 24-hour soak
- repository-local non-credentialed smoke evidence under `_build/phase9-smoke`

No generated local result is evidence of Apple credentials, notarization, Gatekeeper, hosting, a clean machine, update/rollback, or a long soak.

## Protected inputs

- `MOONDESK_DEVELOPER_ID_APPLICATION`: Developer ID Application identity
- `MOONDESK_NOTARY_KEYCHAIN_PROFILE`: CI-created protected notarytool keychain profile
- `MOONDESK_UPDATE_PRIVATE_KEY_FILE`: protected Ed25519 PEM file
- `MOONDESK_UPDATE_PRIVATE_KEY_PASSPHRASE`: optional protected passphrase

The repository does not contain these values.

## External blockers

| Proof unavailable locally | Owner | Target date | Required retained evidence |
| --- | --- | --- | --- |
| Developer ID and hardened-runtime signature | Release Engineering | 2026-08-07 | identity, codesign details, immutable artifact hashes |
| Apple notarization and stapling | Release Engineering | 2026-08-07 | notary submission ID/result and stapler validation |
| Gatekeeper acceptance on clean Macs | macOS QA | 2026-08-12 | `spctl`/launch result on minimum and current macOS |
| Stable/preview channel hosting and hosted checksums | Release Operations | 2026-08-14 | immutable URLs, permissions, retrieval and checksum evidence |
| Clean-machine matrix | macOS QA | 2026-08-14 | completed schema-valid matrix, including no toolchain/source checkout |
| Install/update/interruption/rollback/removal | macOS QA | 2026-08-18 | schema-valid lifecycle evidence and before/after user-data hashes |
| 24-hour lifecycle/resource soak | Reliability Engineering | 2026-08-21 | raw samples and schema-valid report against frozen thresholds |

Phase 9 is not declared complete until these blockers are closed. Phase 10 has not started.
