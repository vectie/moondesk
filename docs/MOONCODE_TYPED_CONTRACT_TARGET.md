# MoonCode Typed Contract Target

| Field | Value |
| --- | --- |
| Status | Phase 3 complete; all nine slices closed |
| Scope | `mooncode/core/pkg.generated.mbti` and its owning package |
| Evidence date | 2026-07-29 |

## Purpose and evidence boundary

This document records the Phase 3 inventory, target, and accepted closure. The
evidence boundary covers the generated interface, its owning package, direct
repository consumers, and the bounded downstream consumer validation.

## Accepted Phase 3 closure

All nine Phase 3 slices are closed. The final public surface has **17 public
types**, **30 public functions/methods**, **0 public impl/raw helpers**, and
**47 public declarations**. The generated interface is **245 lines / 7,053
bytes**.

All **11 ownership validators** are green. `mooncode/core` is **61/61** on
wasm, wasm-gc, js, and native; `internal/mooncode` is **15/15** on all four
targets; MoonWiki is **155/155**; and UI is **379/379**.

Downstream consumer migration commit `716870857725abd5fb0853675cf5ee494a87bd2f`
was validated but deliberately is not part of this integration. The immediate
next phase is Phase 4 package boundaries.

## Exact baseline

`mooncode/core/pkg.generated.mbti` is **1,017 lines / 28,305 bytes** and exports:

| Declaration kind | Count |
| --- | ---: |
| Public types | 1 |
| Public functions (including the one public method) | 491 |
| Public constants/values | 0 |
| Type/value aliases | 0 |
| Explicitly deprecated symbols | 0 |
| Total public symbols | 492 |

The sole type is `NativeCapabilityEndpoints`; its 17 fields are public through
`pub(all)`. `NativeCapabilityEndpoints::required_endpoints` is included in the
491-function count. There are no `pub let`, `pub const`, type aliases, or
`deprecated` annotations in the actual interface. These facts correct any
metric that counted string-returning functions as constants, counted fields as
types, or inferred deprecation from naming.

## Decision rules for the complete public surface

The generated interface proves the complete 492-symbol inventory. The following
ordered rules define a migration decision for every symbol; earlier rows take
precedence when names overlap. They are a decision framework, not a completed
semantic, per-symbol categorization: exact category counts beyond the proven
consumer set require the migration-slice review described below.

| Exact symbol or ordered name family | Current classification | Decision |
| --- | --- | --- |
| `NativeCapabilityEndpoints` | Endpoint construction | **Private** after routes consume typed endpoint builders |
| `NativeCapabilityEndpoints::required_endpoints`, `native_capability_endpoints`, and every public `native_*endpoint*` function | Endpoint construction | **Private**; endpoint strings are transport implementation |
| Every public function ending `_contract_json`, `_contract`, `_json`, `_rows`, `_specs`, `_report`, `_problem`, or taking/returning `Json` | Serialization helper | **Private** behind the single codec, except typed decode/encode entry points |
| Every `*_assert*`, `*_matches_contract*`, `*_required_fields`, `*_required_endpoints`, `*_projection_problem*` function | Test-only assertion | **Private** or move to tests |
| Every `*_alias*` and canonicalization synonym mapping (`runtime_tool_from_moonclaw_tool`, legacy action/tool spelling adapters) | Compatibility alias | **Deprecate**, then remove after consumer and fixture proof |
| Every zero-argument `String`/`Array[String]` vocabulary getter, including all `*_kind`, `*_status_*`, `*_state_*`, `*_action*`, `*_lane*`, `*_mode`, `*_reason*`, `*_role*`, `*_event*`, `*_tool*`, `*_control*`, `*_approval*`, and `*_next_*` getters | Private implementation detail | **Type** with a target enum/opaque ID where in the target model; otherwise **private** |
| Predicates/classifiers over those strings (`*_is_*`, `*_has_*`, `*_requires_*`, `*_allowed*`, `*_supported*`, `*_mutates*`, `*_writes*`) | Private implementation detail | **Private** as methods/matches on typed values |
| Conversation/session/watch/command/evidence/approval/lifecycle projection and transition functions not matched above | Domain operation | **Retain** only as narrow typed operations; replace `String`/`Json` parameters and results |
| Package/review/action-plan/journal/runtime-control/runtime-consumer/native-execution/event-projection helpers not matched above | Domain operation or private implementation detail | **Private** by default; retain only if a direct external consumer is proven during its migration slice |
| `protocol_version`, stable contract/capability negotiation access, and the future codec entry points | Serialization helper/domain operation | **Retain/type** as the versioned transport boundary |
| Symbols made redundant by typed values, duplicate contract documents, legacy spellings, or duplicate projection state | Obsolete symbol | **Deprecate**, then remove under the criteria below |

The rules cover one type and all 491 function declarations, but their semantic
categories are intentionally not presented as disjoint numeric totals. For each
implementation slice, the generated-interface diff is the authoritative
symbol-by-symbol check: every touched declaration must map to a named target
operation, become private, or carry a time-bounded deprecation.

### Owner-file inventory

The 491 functions are owned by 16 implementation files; their prefixes provide
a second completeness index for the ledger: `command_actions.mbt`,
`conversation_ownership.mbt`, `conversation_watch.mbt`, `event_lanes.mbt`,
`event_names.mbt`, `journal_contract.mbt`, `model_planner_evidence.mbt`,
`native_command_execution.mbt`, `native_endpoints.mbt`,
`native_event_projection.mbt`, `package_review_flow.mbt`, `protocol.mbt`,
`runtime_consumer.mbt`, `runtime_control.mbt`, `runtime_evidence.mbt`, and
`runtime_tools.mbt`. The seventeenth package file, `protocol_wbtest.mbt`, is
test-only and adds no interface symbol.

## Proven consumer surface

The direct package consumer is `internal/mooncode`, whose manifest imports
`vectie/moondesk/mooncode/core` as `@mooncode_core`. Four source files in that
package reference **29 distinct public functions**. A sibling checkout,
`moondesk-document-provider`, contains the same 29-symbol adapter surface and
must be treated as a downstream compatibility target rather than ignored.

The proven functions are:

```text
command_action_approval
command_action_control
command_action_is_supported
command_advertised_actions
conversation_contract_id
conversation_kind
conversation_watch_contract_id
conversation_watch_contract_json
conversation_watch_response
journal_contract_id
native_archived_session_listing_endpoint
native_capability_contract_id
native_capability_endpoints
native_capability_required_endpoints
native_capability_required_tools
native_capability_surface_fingerprint
native_capability_surface_json
native_session_lifecycle_endpoint
native_session_listing_endpoint
native_session_show_endpoint
native_session_turns_endpoint
native_stream_endpoint
protocol_version
runtime_tool_call_contract_json
runtime_tool_capability_names
runtime_tool_capability_specs
runtime_tool_contract_json
runtime_tool_contract_tool_ids
runtime_tool_names
```

`NativeCapabilityEndpoints` is also part of the effective consumer contract
because `native_capability_endpoints` returns it and the adapter reads its
public fields. The compatibility baseline is therefore **30 proven public
symbols**: 29 functions plus one type. The other **462 symbols** have no direct
source consumer in this repository or the searched sibling checkout. They are
accidental-public candidates, not automatically safe to remove: each owning
slice must still check fixtures, generated artifacts, and any separately
versioned downstream repository.

## Repeated untyped vocabularies

The source and interface repeatedly encode closed vocabularies as strings:

- lifecycle/action-plan states: queued, running, awaiting proof, retry,
  ready-for-review, completed, blocked, plus next-action prose;
- command actions: prompt, steer, note, patch/revert, test/build/eval, commit,
  package, accept/reject, approve/reject tool, cancel;
- command and runtime statuses: accepted, acknowledged, claimed, completed,
  failed, skipped, missing, proof-missing, delivered, claimable, and blocked
  variants;
- event lanes: transcript, tool, diff, test, artifact, review, diagnostic and
  defaults/progress groupings;
- evidence/event kinds, tool names and aliases, approval/control modes,
  conversation roles, stop/failure reasons, watch cursor/result states, and
  endpoint/action identifiers.

The same concepts appear in getters, arrays, predicates, JSON contract builders,
and transition functions. This duplication is the primary typing target.

## Proposed small typed model

Implement the plan's public model without adding a parallel durable model:

`MoonCodeCapability`, opaque `MoonCodeSessionId`, `MoonCodeSessionSummary`,
`MoonCodeSessionStatus`, `MoonCodeConversation`, `MoonCodeTurn`,
`MoonCodeMessage`, `MoonCodeWork`, `MoonCodeEvidence`, `MoonCodeCommand`,
`MoonCodeCommandKind`, `MoonCodeCommandStatus`, `MoonCodeApproval`,
`MoonCodeLifecycleAction`, opaque `MoonCodeWatchCursor`, `MoonCodeWatchResult`,
and `MoonCodeFailure`.

Closed enums cover session status, command kind/status, evidence kind, approval
decision, lifecycle action, and stop reason. IDs are opaque/validated. Records
contain typed values, not raw `Json` or unconstrained status/action strings.

## Canonical ownership and serialization boundary

MoonClaw/runtime owns session identity, canonical conversation, command packet,
evidence, approval, watch semantics, and lifecycle errors. MoonBook owns durable
book artifacts. MoonDesk owns only presentation DTOs that intentionally omit
runtime-private details; it must not persist a second conversation.

There will be exactly one versioned runtime codec module: one JSON-to-typed
decode path and one typed-command-to-JSON encode path. Routes, projections, and
UI consume typed results only. The codec rejects unknown required fields,
deliberately preserves supported optional extensions, distinguishes absent,
malformed, unsupported, and stale data, never maps decode failure to empty
state, and negotiates contract version/capabilities.

## Quantitative target

Phase 3's generated-interface gate was:

- at most **17 public domain types** (the model above);
- at most **30 public functions/methods** total;
- **0** public raw endpoint builders, assertion helpers, vocabulary getters,
  aliases, constants/values, or untyped JSON helpers;
- at most **250 interface lines** and **10,000 bytes**.

From 492 symbols, 1,017 lines, and 28,305 bytes, this is at least a **90% symbol
reduction** (to at most 47 total public symbols), **75% line reduction**, and
**64% byte reduction**. The limits are gates, not completion claims.

## Nine ordered vertical migration slices

1. **Capabilities.** Add `MoonCodeCapability` and version negotiation; codec
   tests cover supported/unsupported/malformed payloads. Adapt capability route
   and UI. Remove helpers only after old/new parity. Roll back the route adapter,
   retaining codec/tests.
2. **Session listing.** Add typed ID, summary, and status; fixture and list-route
   tests cover absent/stale fields. Migrate list UI. Remove list JSON/status
   helpers after no-consumer proof. Roll back to the old adapter.
3. **Selected session.** Decode one selected session with typed failure states;
   test not-found versus malformed versus stale. Migrate detail UI. Remove show
   projection helpers after parity. Roll back selection adapter.
4. **Canonical conversation.** Use runtime-owned conversation/turn/message/work
   representation; test ordering, identity, roles, optional extensions, and
   round trips. Migrate transcript UI. Remove duplicate projection vocabulary
   only after fixture parity. Roll back renderer adapter, never durable data.
5. **Command submission.** Add typed command/kind/status and the sole encoder;
   test every supported command and rejection of invalid combinations. Adapt
   route/UI. Deprecate action getters/JSON builders after runtime acceptance
   proof. Roll back encoder selection.
6. **Watch/stream.** Add opaque cursor and typed result; test resume, duplicate,
   malformed, stale, and disconnect behavior. Adapt stream and UI. Remove event
   parsing helpers after replay parity. Roll back to polling/legacy adapter.
7. **Approvals.** Add typed approval/decision; test authorization snapshots,
   accept/reject, and unknown decisions. Adapt review UI. Remove approval/tool
   predicates after audit parity. Roll back approval adapter.
8. **Lifecycle mutation.** Add typed lifecycle action/failure/stop reason; test
   allowed transitions, conflicts, cancellation, and runtime failure. Adapt
   lifecycle route/UI. Remove state/action-plan strings after transition parity.
   Roll back mutation adapter without rewriting persisted state.
9. **Package/review evidence.** Add typed evidence and package/review projection;
   test command scoping, proof missing/failure, receipts, and artifacts. Adapt
   review UI. Remove journal/evidence/status helpers and expired aliases only
   after product smoke and downstream search. Roll back projection adapter while
   preserving evidence records.

Every slice requires focused codec tests, owning-package tests, route tests, UI
tests, a product smoke, and reviewed `.mbti` diff. Compatibility aliases require
an owner, warning, removal version/date, and zero direct consumers before
removal. A slice may roll back its adapter, but never discard runtime-owned data
or broaden raw JSON access.

The 29-function/one-type proven consumer list is the initial retain set. A
function may move from that set only in the same vertical slice that migrates
both `internal/mooncode` and the sibling adapter, with parity tests and a
reviewed interface diff. The 462 no-direct-consumer symbols are reviewed
private-by-default in their owning slices.

## Phase 3 gate

Closed. All nine slices are implemented, canonical ownership is agreed with the
runtime owner, the single codec boundary is enforced, focused and product tests
pass, downstream compatibility is checked, and the generated interface
satisfies the quantitative limits. The accepted evidence is recorded above.
