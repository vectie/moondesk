# Agent workspace evolution

Status: local feature implementation complete; external qualification gates are explicit

Last verified: 2026-09-04

This plan turns the OWB workflow study and the MoonBook portability study into
one product contract. MoonDesk stays a normal chat-and-document application;
the agent harness remains behind the surface and interrupts only for warnings,
decisions, or failures that need attention.

## Ownership

```text
MoonDesk   human-facing chat, document, context, review, and preference UX
MoonClaw   general-agent conversations, turn queue, tools, and context assembly
MoonBook   portable identity, accepted knowledge, preferences, procedures,
           schemas, evaluation evidence, and adopted capability versions
MoonFort   isolated trials and temporary/generated artifacts
MoonTown   recurring schedules, leases, and run delivery
MoonGate   model routing plus latency, token, cost, and comparison evidence
MoonFlow   live review collaboration and workflow coordination
Bookkeeper candidate -> evidence -> review -> adoption -> rollback governance
```

MoonWiki never shows a model picker, reasoning control, terminal, tool-detail
transcript, or developer browser. Those controls are deliberately confined to
MoonCode.

## Implemented workflows

| Workflow | User behavior | Durable/runtime contract |
| --- | --- | --- |
| Document conversations | Reopen, rename, archive, or start multiple conversations bound to a document | Server-owned `moondesk.document_conversation.v1`, atomically persisted by workspace; browser storage is only offline recovery |
| Editable follow-ups | Keep writing while the current answer runs; edit, delete, reorder, or send immediately | A bounded per-conversation draft tray preserves each turn; send-now delegates to MoonClaw’s existing independent message queue |
| Typed sources and artifacts | Open a cited page, slide, sheet/cell, section, anchor, or generated file | `source_ref` and `artifact_ref` stream fragments; exact Office location selection when the document is open; safe path opening otherwise |
| Add context | Add current selection, workspace material, prior conversation, run artifact, Inbox content, or explicit HTTP(S) URL | One **Add context** palette; existing paths are referenced and imports remain explicit |
| Natural-language background work | A recurring request produces a compact confirmation card describing reads, cadence, and notification rule | Explicit recurrence detection only proposes `automation_suggestion`; confirmation creates a MoonTown standing goal; dismissal has no effect |
| Preferences and glossary | Inspect, add, disable, enable, or forget terminology, names, tone, and conventions at workspace or global scope | `moondesk.agent_preference.v1`; only enabled user-approved records enter MoonClaw context |
| Anchored review | Comment on a document, selection, cell, or slide object; assign, reply, resolve, and detect stale anchors | `moondesk.document_review_thread.v1`; baseline mismatch marks an anchor stale for revalidation |
| Fork and compare | In MoonCode, define a goal and two approaches from one baseline | One explicit comparison request requires MoonFort isolation and output/diff/check/warning/latency/token/cost evidence; promotion remains explicit |

The comparison coordinator is server-owned under
`.moonsuite/products/moondesk/comparisons/`. Browser storage is only a recovery
copy. A selected branch creates a typed MoonGate evaluation candidate; it does
not claim a verified outcome until the branch evidence is complete.

## Completion and integration gates

All eight user workflows above are implemented in MoonDesk and the portable
agent lifecycle is implemented in MoonBook. The interface keeps unavailable
dependencies honest instead of simulating success.

| Boundary | Repository-complete behavior | External qualification still required |
| --- | --- | --- |
| MoonFort comparison | Shared digest, two durable MoonCode branches, explicit selection and no implicit promotion | A live MoonFort service must return the fork/snapshot and promotion receipts |
| MoonGate evaluation | Comparison record carries a typed evaluation candidate and requests latency, tokens and cost | A configured route must return measured values and a verified outcome |
| MoonFlow review | Anchored review records, stale-baseline detection and warning projection are durable | Cross-device presence, unread delivery and live collaboration require MoonFlow transport |
| Agent distribution | MoonBook verifies content digests, dependency locks, import/upgrade and rollback | Publisher identity requires a host trust store and detached-signature verifier |

These are deployment or cross-product gates, not hidden MoonDesk fallbacks.

## Typed fragment contract

The general task stream continues to use `moonclaw-task-stream.v2`. MoonDesk
consumes these additional final-user-facing fragment kinds:

```json
{
  "contract": "moonclaw-task-stream.v2",
  "kind": "source_ref",
  "workspace_path": "documents/revenue.xlsx",
  "label": "Revenue assumption",
  "sheet": "Forecast",
  "cell_range": "B12:D12",
  "content_digest": "sha256:..."
}
```

```json
{
  "contract": "moonclaw-task-stream.v2",
  "kind": "artifact_ref",
  "sandbox_id": "sandbox-...",
  "path": "outputs/revised-forecast.xlsx",
  "mime_type": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
}
```

Reasoning, tool arguments, and hidden progress are not converted into chat
messages. Replayed fragments are deduplicated by role and canonical event text.

## Portable evolving agent

MoonBook owns `moonbook.agent_bundle.v1`, a self-contained
`.moonbook-agent` artifact. It includes safe relative, content-addressed,
accepted identity/knowledge/preferences/skills/procedures/schemas/tool and app
declarations, standing-watch intent, compatibility requirements, evaluation
evidence, and adopted capabilities. It excludes credentials, absolute machine
paths, symlinks, working memory, queues, prompts, chain-of-thought, processes,
leases, and unaccepted behavior.

The lifecycle is:

```text
pack -> inspect -> verify -> diff -> merge preview -> import/upgrade -> rollback
```

The implementation and CLI are documented in
`../moonbook/docs/PORTABLE_EVOLVING_AGENT.md`. The bundle now carries verified
named memory policy/counters and digest-bound MoonClaw, MoonFort, MoonTown and
MoonGate dependency locks with capability and migration declarations. Content
digests prove integrity; publisher identity signatures remain explicitly
reserved for a host-verified later contract.

Self-evolution remains governed:

```text
observed outcome -> candidate -> shadow/canary evidence -> Bookkeeper review
-> adopted capability version -> next portable bundle
```

Provisional knowledge may accumulate, but only accepted knowledge and adopted
behavior enter an exported agent. Failed trials and counterexamples remain in
lineage evidence.

## Performance and limits

The workspace runtime no longer fingerprints or duplicates an entire
conversation in hidden JSON on every stream fragment. MoonBit emits a tiny
cursor/count/tail projection; JavaScript retains the canonical visible entries
and replaces only the changed tail during streaming. Server writes are
coalesced for 500 ms, identical writes are suppressed, and answer enhancement
is scoped to the active chat thread and content signatures.

Named service limits replace hidden UI magic numbers:

- 256 durable conversations per MoonDesk service store;
- 240 visible entries per conversation;
- 240,000 characters per visible entry;
- 256 preference/glossary records;
- 1,000 anchored review records;
- MoonBook agent payloads limited to 16 MiB per file.

These are contract policy values, not model-output caps. MoonClaw’s configurable
output budget remains independent.

## Verification matrix

Required automated and UI cases:

- restart and reopen a document conversation;
- multiple conversations for one document and workspace-wide conversation;
- edit/delete/reorder/send-now follow-ups while a response streams;
- reconnect with duplicate typed fragments;
- exact DOCX/PDF page, PPTX slide, and XLSX sheet/range navigation;
- recurring wording that proposes a schedule and one-shot wording that does not;
- global/workspace preferences, disabled records, and forget;
- anchored thread reply/resolve and stale baseline;
- MoonCode comparison with two distinct approaches and explicit promotion;
- 1 MiB response, 240-message conversation, hundreds of citations, rapid file
  switching, reconnect during generation, and background streaming with an
  active Office viewer.

The release gate remains the real UI plus native service tests. The full local
browser journey covers durable conversation/context flows, Office viewers,
MoonCode browser evidence, comparison restoration, responsive layouts, 200%
text scaling, keyboard navigation and console cleanliness. Fixtures still do
not prove cross-device collaboration, publisher identity, notarization, or
external provider availability.
