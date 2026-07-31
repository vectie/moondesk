# WP-MOONEDIT-DOCUMENT-API

## Prompt 2 recovery log

- Problem: The first recovery attempt added broken standalone request tests using invented helpers/APIs and failed before validation; those tests were deleted.
- Problem: The second recovery attempt then falsely reported completion after deleting all newly added request tests, leaving no live-server document coverage.
- Fix: This recovery extends the existing live-server test with localized document fixtures and assertions. Verification completed at core 20/20, focused moonwiki 123/123, and full native 226/226.
- Problem: Session 132 inserted two broken standalone HTTP tests that invented unavailable helpers and response APIs (`@fsx.remove_all`, `start_desk_server_for_test`, `response.status/body`, and `sha256_hex`) instead of extending the existing test that owns the live server.
- Fix: Remove those standalone tests and consolidate document fixtures/assertions into `desk server routes work end to end and reject path escapes`, using only installed package APIs. Exact focused and full native counts will be recorded only after all requested gates pass.
- Problem: The prior MoonCode pass implemented the document route but omitted the requested end-to-end HTTP document test entirely.
- Fix: Recovery added a dedicated async whitebox test with deterministic document fixtures and HTTP status/body assertions; final native counts were recorded only after the requested gates ran.
- Problem: The portable workspace-content route contract test retained the pre-document-route count of five and did not explicitly prove that the document endpoint is exported.
- Fix: Updated the expected count to six and added an explicit `workspace_action_route("document")` membership assertion.
- Verification: Required formatting, checking, focused core/internal moonwiki, full native, generated-interface review, and diff gates pass; exact counts are recorded below.
- Test scope: Request-level coverage must exercise GET success (including UTF-8 JSON fields and revision), missing and traversal paths (400), absent/non-regular paths (404), oversized input (413), invalid UTF-8 and forbidden controls (415), plus HEAD body suppression.
- Problem: Initial bounded discovery exhausted the inspection budget before implementation mutation; `moon ide doc moonbitlang/x/fs` returned no documentation result, so native filesystem API details must be established from compiler diagnostics and existing package usage without SDK inspection.
- Fix: Recorded this recovery boundary before proceeding with the revision-aware GET document route implementation.
- Verification: GET/HEAD implementation and route-level live-server coverage are present. Verified counts are core 20/20, focused moonwiki 123/123, and full native 226/226.
- Residual: GET/HEAD are implemented with live route coverage. POST/save and corresponding UI remain explicitly out of scope and pending.
- Hygiene: `moon fmt`, `moon check`, focused/core/full native tests, generated-interface review, and `git diff --check` pass.
- Hygiene progress: Required `moon info && moon fmt` completed successfully. Generated-interface review found and retained only the expected public desktop route addition, `workspace_document_url(String, String) -> String`, in `core/pkg.generated.mbti`; no unrelated generated noise is retained.
## Problem/fix ledger

## Scope and status

This is the canonical re-audit ledger for the MoonEdit document-path resolver checkpoint and Prompt 1 core follow-up. It records every implementation, recovery, harness, and documentation problem encountered. The revision-aware GET/HEAD document API is implemented and covered through the live HTTP server; POST/save and its UI remain pending.

Historical path-resolver checkpoint gates: **118/118 focused native tests** and **221/221 full native tests**. Current gate counts are recorded below only after the complete required validation sequence passes.

## Final behavior and coverage

The desktop route now serves revision-aware GET and HEAD requests through the live HTTP server. Live coverage exercises successful UTF-8 JSON content/revision responses, HEAD body suppression, traversal and symlink-resolver policy failures as HTTP 400, missing/non-regular paths as 404, invalid UTF-8 and forbidden controls as 415, and payloads of 4 MiB + 1 byte as 413. Provider-level tests retain the exact 4 MiB limit as accepted coverage. Responses report `writable: false` truthfully until a save implementation exists.

POST/save and all corresponding UI work remain pending. Residual risks also remain: filesystem stat/open/read operations are not atomic, and symlink substitution between validation and use leaves a TOCTOU window. These risks require a descriptor-relative or equivalent hardened filesystem design rather than stronger wording in the current resolver contract.

Canonical containment alone is not sufficient for the MoonClaw jobs authority. The resolver enforces a strict MoonClaw-only authority policy: every fixed component of `.moonsuite/products/moonclaw/jobs` must be an actual directory, not a symlink, and an existing candidate is accepted only when its kind is `Regular` or `Directory`. Missing descendants may resolve only after the failed child is tracked and absence is proved by enumerating its existing parent.

Coverage consists of exactly two test sets:

1. **Consolidated resolver and jobs-root tests** cover generic resolver and request-helper behavior plus real MoonClaw jobs directories, missing descendants, dangling and resolving symlinks, encoded traversal, and jobs-root links to both outside-suite and in-suite sibling targets.
2. **The every-component loop** covers the fixed topology `suite/books/research` and each fixed MoonClaw authority component. Coverage of the intermediate `.moonsuite/products/moonclaw` parent is inside this loop; it is not a third test set.

The existing-regular-file positive is generic, resolver-wide coverage. MoonClaw positive coverage uses a real jobs directory and missing descendants beneath it.

## Comprehensive problem / root-cause / fix / verification / residual ledger

### 1. Original symlink authority escape

- **Problem:** Native paths could pass canonical containment while a symlink at the jobs root or another fixed authority component changed who controlled the path. Links to in-suite siblings were also unsafe.
- **Root cause:** Canonicalizing the root and candidate checked destination containment, but erased the authority topology used to reach that destination.
- **Fix:** Added MoonClaw-specific component validation for every fixed authority component and reject symlinks even when they resolve inside the suite.
- **Verification:** Dedicated jobs-root tests and the every-component loop reject outside-suite and sibling links.
- **Residual:** The strict topology policy is MoonClaw-only; generic resolver callers do not inherit it.

### 2. Nonexistent `@fs.remove_file`

- **Problem:** Native test compilation failed during symlink cleanup.
- **Root cause:** The filesystem package has `@fs.remove`, not `@fs.remove_file`.
- **Fix:** Replaced cleanup with `@fs.remove`.
- **Verification:** Focused and full native suites compile and pass.
- **Residual:** Ordinary cleanup failures remain visible to the harness.

### 3. Missing fixture parent

- **Problem:** Installing the intermediate MoonClaw symlink fixture failed before resolver execution.
- **Root cause:** `.moonsuite/products`, the fixture's immediate parent, did not exist.
- **Fix:** Create the parent before creating the symlink.
- **Verification:** The intermediate-component cases now execute in the every-component loop.
- **Residual:** Symlink fixtures require host symlink support.

### 4. Duplicate regression consolidation

- **Problem:** Incremental diagnosis produced overlapping authority regressions and misleading coverage counts.
- **Root cause:** New cases were appended without assigning ownership to a stable test structure.
- **Fix:** Consolidated coverage into exactly two sets: dedicated jobs-root tests and the every-component loop. Intermediate moonclaw-parent coverage belongs to the loop.
- **Verification:** The focused suite passes without a third claimed test set.
- **Residual:** Future additions must preserve this ownership to avoid duplication.

### 5. Over-broad edit truncated `http_request_helpers` tail

- **Problem:** A broad replacement removed the tail of `http_request_helpers.mbt`, causing a cascade of unbound identifiers unrelated to the resolver.
- **Root cause:** The edit range extended past the intended resolver function.
- **Fix:** Restored the tail exactly from `HEAD` while preserving only the intended resolver changes.
- **Verification:** The mass unbound-identifier diagnostics disappeared; check and both native suites pass.
- **Residual:** Large text-range edits remain hazardous; use exact bounded replacements.

### 6. First recovery left `strip_query` incomplete

- **Problem:** The initial tail recovery still left `strip_query` truncated/incomplete.
- **Root cause:** Recovery restored an insufficient boundary rather than the complete original function and following tail.
- **Fix:** Performed a full exact repair from `HEAD`, retaining resolver work outside that range.
- **Verification:** Formatting, checking, and request-helper tests pass.
- **Residual:** None beyond avoiding partial source reconstruction.

### 7. Invalid tuple destructuring

- **Problem:** Recovery code used tuple destructuring in a form rejected by MoonBit.
- **Root cause:** Guard/pattern syntax was guessed instead of using valid MoonBit matches.
- **Fix:** Rewrote the logic with valid guards and `match` expressions.
- **Verification:** Native compilation and check pass.
- **Residual:** None specific.

### 8. Filesystem alias conflict

- **Problem:** Native filesystem imports collided with an existing `@fs` alias.
- **Root cause:** Two packages were assigned the same package alias in one package context.
- **Fix:** Assigned the native filesystem package the unique alias `@nativefs`.
- **Verification:** Package resolution and compilation pass.
- **Residual:** Keep aliases unique when adding dependencies.

### 9. Guessed `read_dir` and `basename` APIs

- **Problem:** The first absence-proof implementation referenced guessed directory and basename APIs that did not exist as written.
- **Root cause:** API names/signatures were assumed rather than derived from the assigned package interface.
- **Fix:** Used the actual `moonbitlang/x/fs` `read_dir` API plus inline/local POSIX basename extraction via `rev_find('/')` and slicing.
- **Verification:** Check passes and missing-child regressions execute successfully.
- **Residual:** Dependency upgrades may require interface revalidation.

### 10. Existing regular file incorrectly rejected

- **Problem:** An intermediate resolver revision rejected an existing regular file.
- **Root cause:** Existing targets were treated as if only directories could be valid ancestors/targets.
- **Fix:** Permit `Regular` as well as `Directory` for existing resolver targets.
- **Verification:** The generic resolver-wide existing-regular-file positive passes. MoonClaw positives separately cover a real jobs directory and missing descendants.
- **Residual:** Special filesystem kinds must never be folded into this positive.

### 11. One-level missing child not proved absent

- **Problem:** A failed child lookup was treated as nonexistence, including the one-level-missing case, without proof.
- **Root cause:** Broad error handling conflated absence with permission, I/O, or unsupported-kind errors.
- **Fix:** Track the exact failed child, canonicalize/find its existing parent, enumerate that parent, and accept the missing suffix only when the child name is absent.
- **Verification:** One-level and deeper missing-descendant positives pass, while existing/error cases are not silently classified as missing.
- **Residual:** A TOCTOU window remains between enumeration/canonicalization and later use.

### 12. Wrong every-component topology made negatives vacuous

- **Problem:** Tests used a `suite/book` shape inconsistent with the resolver fixture, so some negative checks could pass without exercising the intended component.
- **Root cause:** The test topology did not match the expected three-level document shape.
- **Fix:** Corrected it to `suite/books/research`.
- **Verification:** Every-component negatives now reach and validate each intended component.
- **Residual:** Fixture topology must remain aligned with resolver semantics.

### 13. Repeated MoonCode sessions lost edit/test tool binding

- **Problem:** Recovery sessions repeatedly lacked the required edit/test binding and could not safely complete or verify changes.
- **Root cause:** Tool capability binding was not retained across those sessions.
- **Fix:** Started a new session with edit and test tools bound; no manual code edit was used as a workaround.
- **Verification:** Changes were applied and all final gates were run through the bound tools.
- **Residual:** Session capability continuity is operational rather than code-enforced.

### 14. FIFO, device, and `Unknown` kinds were accepted

- **Problem:** Logic that merely excluded symlinks could accept FIFOs, devices, or `Unknown` filesystem kinds as valid existing targets.
- **Root cause:** The policy used a denylist instead of defining the complete accepted set.
- **Fix:** Changed existing-target validation to the explicit allowlist `Regular | Directory` and added a native FIFO regression.
- **Verification:** The FIFO case is rejected and normal file/directory positives pass.
- **Residual:** The FIFO fixture is POSIX-only; platform coverage differs on Windows.

### 15. First FIFO FFI helper was invalid

- **Problem:** The initial native FIFO helper used invalid `#external` syntax and an unannotated FFI declaration, preventing compilation.
- **Root cause:** A custom FFI bridge was introduced without a valid MoonBit/native declaration contract.
- **Fix:** Deleted the untracked helper and created the FIFO through `@process.run` (`mkfifo`).
- **Verification:** Native tests compile and the FIFO regression passes.
- **Residual:** The fixture depends on the POSIX `mkfifo` command and is intentionally POSIX-only.

### 16. Last ledger rewrite dropped comprehensive history

- **Problem:** A rewrite of this canonical ledger retained only a shortened final narrative and omitted encountered failures and recoveries.
- **Root cause:** The document was rewritten as a summary instead of maintained as an append-preserving audit record.
- **Fix:** Restored this structured problem/root-cause/fix/verification/residual record for every re-audited item and corrected coverage and regular-file wording.
- **Verification:** The canonical ledger now enumerates all re-audited incidents, final gates, and residuals; repository formatting and diff checks are rerun after this documentation repair.
- **Residual:** Future rewrites must preserve complete history rather than replacing it with checkpoint-only prose.

## Preserved repository rationale

`.moonsuite/` remains ignored because it is runtime/test-generated workspace state. Tests create isolated temporary suite trees and must not make those artifacts source-controlled inputs.

## Final residual risks and intentionally incomplete work

- **TOCTOU:** Filesystem state can change between component inspection, parent enumeration/canonicalization, and eventual mutation.
- **POSIX/Windows gap:** Native path and special-file behavior differs across platforms; the FIFO regression is POSIX-only.
- **Generic revision API:** GET/HEAD are implemented; POST/save/UI remain pending.
- **Policy scope:** Strict fixed-component authority validation is MoonClaw-only, not a universal resolver policy.
- **Route-level coverage:** GET/HEAD now have live-server route coverage. There is no route-level POST mutation test because POST/save remains pending.

## Final verification record

- Historical path-resolver checkpoint (superseded counts): **118/118 focused native tests** and **221/221 full native tests** passed.
- Final test gates: **core 20/20**, **focused moonwiki 123/123**, and **full native 226/226** passed.
- Final hygiene gates: **`moon fmt --check` passes** and **`git diff --check` passes**.
- Final implementation status: **GET/HEAD implemented; POST/save/UI pending**.

### 17. First failed document-provider core attempt

- **Problem:** The initial private core was left with nine compile errors and no verification.
- **Root cause:** Implementation was written/submitted before checking the current APIs and language syntax.
- **Fix:** Reworked the bounded core without adding routes or persistence.
- **Verification:** Native format, check, test, info, format-check, and diff-check gates were rerun.
- **Residual:** Routes and saves remain intentionally out of scope.

### 18. Guessed UTF-8 decode Result contract

- **Problem:** Decode was pattern-matched as a `Result`.
- **Root cause:** The exception-raising API contract was guessed.
- **Fix:** Catch `@encoding/utf8.Malformed` and map it to typed `InvalidUtf8`.
- **Verification:** A whitebox invalid-byte test expects `Err(InvalidUtf8)`.
- **Residual:** None for strict document decoding.

### 19. Deprecated postfix propagation syntax

- **Problem:** Postfix `?` caused compilation failures.
- **Root cause:** Obsolete propagation syntax was used.
- **Fix:** Explicitly match control-validation results.
- **Verification:** Both load and save validation paths are exercised.
- **Residual:** None.

### 20. String indexing and hex mismatch

- **Problem:** Indexed string code units were passed to `write_char`, producing a type mismatch.
- **Root cause:** String indexing yields `UInt16`, not `Char`.
- **Fix:** Concatenate each digest byte's exact lowercase two-digit `Byte::to_hex()` representation.
- **Verification:** Direct byte-hex and empty, ASCII, and multibyte SHA-256 vectors are asserted.
- **Residual:** None.

### 21. Missing document-provider tests

- **Problem:** The first attempt added no tests, leaving private helpers unexercised.
- **Root cause:** Verification was deferred.
- **Fix:** Added a dedicated whitebox suite covering digest vectors, empty/ASCII/multibyte input, byte boundaries, malformed UTF-8, controls, DEL, and encoded-byte save limits.
- **Historical verification (superseded):** At that checkpoint, the package native test gate ran the suite and focused tests exercised the core. The former warning count and assumption that both GET and POST handlers still needed to consume the core are superseded: GET/HEAD are now implemented, and the current reproduced `internal/moonwiki` check reports exactly five warnings—unused `Oversized` fields (two), unused `BinaryControl` field (one), unused `MoonEditDocument.byte_size`, and unused `moonedit_validate_document_for_save`. POST/save remains pending.
- **Residual:** POST/save route and filesystem-save tests await their separately scoped implementations.

### 22. Recovery verification gates

- **Problem:** The failed attempt had no recorded format, compile, test, metadata, or diff hygiene result.
- **Root cause:** The turn ended before gates were run or the ledger was updated.
- **Fix:** Corrected the core and tests, then ran all required native and repository hygiene gates.
- **Verification:** `moon fmt`, native package check and test, `moon info`, `moon fmt --check`, and `git diff --check` are the recovery gates.
- **Residual:** None within document-provider core scope.

## Unicode SHA-256 test-vector correction

- The externally expected SHA-256 vector for the UTF-8 bytes of `你好` was wrong: `670d9743542cae3e7122e3b1aeefc5ebc5542f43a22000081b15ac11e69bec20`.
- Independent verification with `shasum` produced `670d9743542cae3ea7ebe36af56bd53648b0a1126162e78d81a32934a711302e`.
- Both Unicode test expectations were corrected to the independently verified digest; the SHA-256 implementation was deliberately left unchanged.
- **Historical validation (partly superseded):** Validation passed with 123/123 native `internal/moonwiki` tests. The former warning count and claim that GET had not consumed the core are superseded: GET/HEAD are implemented with live-server route coverage. The current reproduced `internal/moonwiki` check reports exactly five warnings—two unused `Oversized` fields, one unused `BinaryControl` field, `MoonEditDocument.byte_size`, and `moonedit_validate_document_for_save`; the save-validation warning remains while POST/save is pending.
