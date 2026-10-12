# JSON and JSONL tables

Select a `.json`, `.jsonl`, or `.ndjson` file in Desk or Wiki and click **View as table**. The same explicit action is available in Code's source editor after saving any draft. A separate read-only tab shows the saved file, the union of top-level keys, and **Export CSV** / **Export XLSX** links. The source file is not rewritten by viewing or exporting. Ordinary JSON editing remains the default.

JSON must contain an array of objects; JSONL/NDJSON uses one object per nonblank line. Optional fields are blank, null displays as `null`, and nested values remain compact JSON text. The first appearance of a key determines its column order. CSV contains a fully quoted header and values. XLSX preserves numeric/boolean cell types and stores strings as literal text. Numeric spelling may normalize (12.50 → 12.5). Existing MoonLeaf XLSX size limits apply.

## Local source integration

Place the accepted `moonleaf` source next to this `moondesk` directory. `moon.work` and `ui/rabbita-desk/moon.work` select that normal sibling workspace member, and `moon.mod` declares `vectie/moonleaf@0.1.16`. No registry package or cached dependency is edited to add the feature.

## HTTP surface

`GET /api/workspaces/<id>/json-table?path=<URL-encoded-path>&format=html` returns the table view. `format=csv` and `format=xlsx` download exports. These are read-only routes using the existing selected-workspace path resolver. The regular preview/source routes retain their normal behavior.

## Verification

- Native `cmd/main` product build and Rabbita JS `main` product build passed.
- UI table-action test passed; JSON continues to use source buffers and normal editing.
- Actual native HTTP host test opens JSON and JSONL fixtures, checks optional fields, decimals, Unicode and nested values, downloads CSV/XLSX, independently reopens both, confirms original bytes remain unchanged, and saves/reopens a normal JSON object using the existing source route.
- Focused host projection/read tests are included in `workspace_json_table_wbtest.mbt`.
- MoonLeaf's full 159-test Wasm suite and product build passed.
- Default-stack native whitebox compilation hit a pinned-compiler stack overflow; a process-local 64 MiB stack (`prlimit --stack=67108864:67108864`) allowed the same frozen test to compile and pass. No global resource settings changed.
- No graphical browser or macOS verification was performed. The feature is checked through compiled UI/controller tests and the actual native HTTP host.

Run the focused host journey with `moon test internal/moonwiki/json_table_http_wbtest.mbt --target native --strip -j 1`. Set `MOONDESK_JSON_TABLE_EVIDENCE` to a private empty directory to retain HTML, CSV, XLSX, source fixtures, and its receipt. Otherwise it uses a temporary workspace. Keep native compilation serialized under the shared build lock in this qualification environment.

## Local exploration

The table view now supports shared text/numeric filters, sorting, group summaries and filtered exports, including CSV/TSV and the first sheet of XLSX. See [Local data explorer](TABLE_EXPLORER.md) for the normal workflow, query parameters and projection limits. The original source-editing and JSON interpretation rules above still apply.

## Explore a nested current draft

For nested objects or scalar roots, [Explore JSON values](SOURCE_JSON_VALUES.md)
in the source editor selects and downloads an exact subtree without saving
or flattening the document into records.
