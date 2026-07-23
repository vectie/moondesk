# WP-MOONEDIT-DOCUMENT-API problem/fix ledger

## Scope and status

This is the canonical re-audit ledger for the MoonEdit document-path resolver checkpoint. It records every implementation, recovery, harness, and documentation problem encountered. The generic revision-aware document API remains unimplemented.

Final gates: **118/118 focused native tests**, **221/221 full native tests**, and **format, check, diff-check, and info gates green**.

## Final behavior and coverage

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
- **Generic revision API:** The generic revision-aware document API is still unimplemented.
- **Policy scope:** Strict fixed-component authority validation is MoonClaw-only, not a universal resolver policy.
- **Route-level coverage:** There is no route-level mutation test; verification is at resolver/request-helper scope.

## Final verification record

- Focused native tests: **118/118 passed**.
- Full native tests: **221/221 passed**.
- `moon fmt`: green.
- `moon check`: green.
- `git diff --check`: green.
- `moon info`: green.
