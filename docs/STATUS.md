# MoonDesk productization status

The authoritative scope and phase gates are defined in `docs/MOONDESK_PRODUCTIZATION_UPGRADE_PLAN.md`.

## Current execution

The full Phase 2–10 repository-local implementation is present on the current branch. Canonical validation passes with 239/239 native tests and 402/402 UI tests, along with format, MoonBit check, UI check, generated-interface, localization, production-build, contract-boundary, and credential-free smoke coverage. The active CI and preview-release workflows, typed MoonCode boundary, ownership splits, path and authority controls, unified evidence surfaces, Office document editing, direct Code editing, localization/accessibility work, and release verification are retained in code and their focused suites.

Repository-local gates are closed. Remaining irreducible evidence is external: a clean hosted pull-request CI run; a tag-driven hosted preview artifact reproduction; signed and notarized macOS artifacts; clean-machine install/launch, update, rollback, and uninstall proofs on supported operating systems; 24-hour idle and 8-hour active soak reports; a completed release-candidate bug bash; and production credential/operator approval. These are not claimed by local validation and do not conceal an independently reachable repository deliverable.

No production release has been published and no branch has been merged by this execution.

## Evidence policy and navigation contract

Repository-local work is complete only when its phase gate passes. Hosted CI,
signing, notarization, clean-machine, update/rollback, and soak claims remain
external evidence until their actual artifacts or URLs are recorded; missing
external proof does not block independent repository-local work in later
phases.

Primary navigation remains exactly **Desk, Wiki, Code, Flow, Packs**, with
**Requests, Runs, Review, Publish** below Wiki.
