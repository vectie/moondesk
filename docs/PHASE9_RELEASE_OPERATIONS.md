# Phase 9 release operations

All output and evidence paths used locally must be beneath repository `_build` or `.moonagent`.

## Unsigned/adhoc local path

Build with the existing wrapper, using a fresh `_build` output:

```sh
export TMPDIR="$PWD/_build/tmp"
mkdir -p "$TMPDIR"
sh scripts/preview_release.sh --version 0.1.0-preview.99 \
  --notes docs/releases/0.1.0-preview.4.md \
  --out "$PWD/_build/releases/moondesk-0.1.0-preview.99"
```

The wrapper writes `release-identity.json`, generates `preview-channel.json`, and validates that channel metadata. The underlying `identity` and `channel` commands refuse overwrite. Stable versions must be `MAJOR.MINOR.PATCH`; preview versions must be `MAJOR.MINOR.PATCH-preview.NUMBER`.

## Credentialed path

Only a protected release environment may set the four variables listed in `PHASE9_NATIVE_DISTRIBUTION_REPORT.md`. Run the existing package build first, then:

```sh
node scripts/phase9_release.mjs credentialed \
  --app "$APP" --archive "$ARCHIVE" --dmg "$DMG"
```

The `credentialed` command performs Developer ID signing with hardened runtime and timestamp, notarizes and staples/validates the app, recreates the archive and DMG from that stapled app, signs and separately notarizes/staples/validates the DMG, and then reconciles the release and update manifests with the final artifact digests. It fails if credentials or Apple tools are unavailable. It does not claim hosting, and notarizing the ZIP alone is not DMG proof.

For the complete credentialed preview flow, use `scripts/preview_release.sh --credentialed`. After `credentialed` finishes manifest reconciliation, the wrapper generates release identity and preview-channel metadata, validates the channel, and then signs the channel metadata.

## Qualification evidence

Use `schemas/phase9-evidence.schema.json` and the checklists in `checklists/`. Validate captured JSON locally:

```sh
node scripts/validate_phase9_evidence.mjs _build/phase9-evidence/*.json
```

Do not convert a local smoke or checklist into an external qualification claim.
