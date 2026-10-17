# Moonzip upstream source

Vendored module: ivgtr/moonzip 0.2.4. Upstream: https://github.com/ivgtr/moonzip. License: MIT, copyright (c) 2025 ivgtr; original LICENSE retained.

Published registry archive SHA-256: 05f42a8c727cb35d900b0c1b7589d473efed35844d7f64e5e055125f49c7042e. This identifies the release archive, not an inferred Git commit.

Local compatibility patches: supported moon.mod metadata replacing legacy JSON, whose original bytes remain UPSTREAM_MANIFEST_PREIMAGE.json; Debug derivation for public FlateErrorCode alongside existing Eq/Show. No error cases, numeric codes, zip/compression algorithm or test assertions changed. Any formatter/interface updates are reviewed separately. Selected as a local workspace module for Desk native and UI builds. No external fork or registry publication.
