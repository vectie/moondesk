# MoonDesk productization status

The authoritative scope and phase gates are defined in `docs/MOONDESK_PRODUCTIZATION_UPGRADE_PLAN.md`.

## Current execution

Phase 3 is complete and all nine slices are closed. Accepted evidence: **17
public types**; **30 public functions/methods**; **0 public impl/raw helpers**;
**47 public declarations**; generated interface **245 lines / 7,053 bytes**;
all **11 ownership validators** green; `mooncode/core` **61/61** on wasm,
wasm-gc, js, and native; `internal/mooncode` **15/15** on all four targets;
MoonWiki **155/155**; UI **379/379**.

Downstream consumer migration commit `716870857725abd5fb0853675cf5ee494a87bd2f`
was validated but deliberately is not part of this integration. The immediate
next phase is Phase 4 package boundaries.

Phases 5–7 and 10 have not started; Phase 8 is partial; and Phase 9 has
unsigned-local evidence only. These repository-local requirements remain open
where the plan says they are open and are not reclassified as external.

## Evidence policy and navigation contract

Repository-local work is complete only when its phase gate passes. Hosted CI,
signing, notarization, clean-machine, update/rollback, and soak claims remain
external evidence until their actual artifacts or URLs are recorded; missing
external proof does not block repository-local work that the authoritative
plan explicitly marks independent, but it does block dependency gates such as
Phase 2 to Phase 3.

Primary navigation remains exactly **Desk, Wiki, Code, Flow, Packs**, with
**Requests, Runs, Review, Publish** below Wiki.
