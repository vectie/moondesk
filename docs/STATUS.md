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
repository-local phase completed is Phase 4 package boundaries.

Phase 4 closes with reviewed `internal/review`, `internal/preview`, and
`internal/town` leaf packages below the `internal/moonwiki` facade; private,
generation-scoped Source Pane state; behavior-owned UI state and test suites;
and generated interfaces that publish no Source Pane constructors, fields,
variants, or reducer functions (only compiler-retained opaque private names). Warm measured gates were root native check 0.41 s, UI JS check 0.42
s, review/preview/town focused tests 0.03/0.04/0.04 s, and Source Pane 11/11 in
0.15 s. Full command and ownership evidence is in
`docs/PHASE4_PACKAGE_OWNERSHIP_MAP.md`.

Phase 5 is complete. Canonical symlink-aware IO is enforced at workspace read
and write boundaries; unsupported archive inputs are rejected before writes
with a typed staging receipt; generated scriptable previews remain opaque;
the complete desktop route table carries explicit authority; MoonFlow action
receipts are durably persisted through confined IO; and the focused security
suite is part of CI. Exact evidence is in `docs/PHASE5_SECURITY_EVIDENCE.md`.

Phase 6 is complete locally at commit `568ec7c3`. The bounded audit confirmed
that canonical turn ordering, evidence-backed progress, reconnect/reload
preservation, stale-event rejection, and progressively disclosed diagnostics
already had owning tests. The only remaining user-visible gap was completed
approval copy: it now identifies the owning command and tool call and exposes
the durable decision receipt under Technical details. Exact exit-gate ownership
and validation evidence is in `docs/PHASE6_OPERATOR_EVIDENCE.md`.

Phase 7 and Phase 10 have not started; Phase 8 is partial; and Phase 9 has
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
