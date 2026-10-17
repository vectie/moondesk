# Moonzip upstream source

Vendored module: ivgtr/moonzip 0.2.4. Upstream: https://github.com/ivgtr/moonzip. License: MIT, copyright (c) 2025 ivgtr; original LICENSE retained.

Published registry archive SHA-256: 05f42a8c727cb35d900b0c1b7589d473efed35844d7f64e5e055125f49c7042e. This identifies the release archive, not an inferred Git commit.

Local compatibility patches: supported moon.mod metadata replacing legacy JSON, whose original bytes remain UPSTREAM_MANIFEST_PREIMAGE.json; Debug derivation for public FlateErrorCode alongside existing Eq/Show. Demo target metadata also selects its existing pure MoonBit decoder on native/LLVM, retaining the existing Wasm and JavaScript selections. A regression test checks both ASCII and the retained single-byte decoding behavior on every target. No decoder algorithm, error cases, numeric codes, zip/compression algorithm or existing test assertions changed. Formatter/interface updates are reviewed separately. Selected as a local workspace module for Desk native and UI builds. No external fork or registry publication.

The approved current-compiler compatibility update replaces deprecated Show derivation with explicit implementations preserving the existing public methods and output. Thirty-one captured baseline values check both Show methods. Existing derived methods are explicitly promoted where required; diagnostic-only namespace, constructor, collection-count and annotation edits retain the algorithms and original assertions. The resulting 440 tests pass on each of wasm, wasm-gc, JavaScript and native. The archive hash and manifest preimage above continue to identify the pristine published source; these local patches do not change that provenance.
