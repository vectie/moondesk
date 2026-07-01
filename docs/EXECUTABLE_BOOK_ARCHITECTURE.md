# Executable Book Architecture

Last validated against explicit local checkouts: 2026-06-20.

## Standalone Project Rule

Each Moon project must build and run from its own checkout. Moondesk may
discover or configure MoonBook, Moontown, MoonClaw, MoonLib, and MoonStat
locations, but it should not assume sibling source directories. Cross-project
work should go through explicit configuration, published package contracts,
local service APIs, or durable book files.

## Product Thesis

MoonBook is an executable book: a durable knowledge workspace that can be read,
edited, executed, reviewed, and published.

Moondesk should make one selected MoonBook feel like a single workspace with two
editing modes:

```text
MoonWiki = edit what the book says
MoonCode = edit what the book can do
```

Both modes edit the same MoonBook. They are not separate products and should not
fork the book's truth.

## User Concepts

Keep the operator-facing model small:

- `Book`: the selected executable MoonBook.
- `Wiki`: human-language knowledge editing.
- `Code`: executable/formal/code editing.
- `Run`: bounded execution progress and artifacts.
- `Review`: accept/reject knowledge, code, diffs, packages, or results.
- `Publish`: generated site/report/tool output.

Avoid making `job`, `agent`, `session`, or `runtime` top-level product
navigation. They are necessary platform concepts, but the user should mostly
encounter them through Book, Wiki, Code, Run, Review, and Publish.

## Component Ownership

| Concept | Owner | Meaning |
| --- | --- | --- |
| MoonBook | MoonBook | Durable executable book filesystem: wiki, code, sources, evidence, reviews, outputs. |
| MoonWiki | MoonBook/Moondesk | Human-language editing and projection of MoonBook knowledge. |
| MoonCode | MoonClaw/Moondesk | Interactive code-language editing of executable book logic, surfaced by Moondesk and executed by MoonClaw. |
| MoonClaw | MoonClaw | Agent/runtime engine for bounded execution, tools, model loops, events, tests, packages, and run artifacts. |
| Moontown | Moontown | Coordination layer for MoonBooks: scheduling, cross-book communication, town events, idea discovery, notifications, and routing. |
| MoonLib | MoonLib | Shared MoonSuite filesystem contract layer: suite root, product registry, product-home paths, temp paths, book paths, and typed path constructors. |
| MoonStat | MoonStat | Workspace health, metrics, snapshots, analytics, and drift reporting against MoonLib contracts. |
| Bookkeeper | MoonBook/Bookkeeper layer | Acceptance gate for knowledge/code/results before they become durable book truth. |
| Agent | MoonClaw | Model/tool actor. |
| Runtime | MoonClaw | Execution substrate: event stream, tool execution, cancellation, durable loop, process/service lifecycle. |
| Session | MoonClaw, archived into MoonBook | Durable interactive conversation or coding context. Accepted summaries can be stored in the book. |
| Job | MoonClaw | Bounded executable job. Moontown may request or schedule it, but MoonClaw executes it. |
| Standing goal | Moontown | Recurring or ongoing intent for a target MoonBook. |
| Town event | Moontown | Cross-book coordination signal, notification, or synthesis event. |
| Artifact | MoonBook | Durable book-owned output from an accepted run, review, tool, miniapp, report, or generated site. |
| Projection | Moondesk | UI view over book, town, and runtime state. |

## Core Boundaries

Moondesk owns selection, display, review controls, native packaging, and the
human workflow shell. It should not own the agent loop, duplicate MoonClaw job
state, or keep historical routes alive after the current contract replaces
them.

MoonBook owns durable truth. It stores accepted prose, accepted code, source
evidence, review receipts, generated outputs, and executable book artifacts.

MoonWiki owns the human-language book surface: markdown, sources, synthesis,
methods, reviews, history, and generated reader-facing pages.

MoonCode owns the executable/formal book surface: tools, miniapps, schemas,
tests, package manifests, diffs, command logs, and coding session projections.
The UI surface is in Moondesk; execution belongs in MoonClaw.

MoonClaw owns execution: agent loops, tool calls, file edits, tests, package
creation, streams, cancellation, and bounded background work.

Moontown owns town coordination: standing goals, schedules, cross-book messages,
idea discovery, town memory, notifications, and routing work to the appropriate
book/runtime.

MoonLib owns shared MoonSuite filesystem contracts. Product-specific helpers may
wrap MoonLib during migration, but they should not redefine suite roots,
product registries, product-home paths, temp paths, or book paths.

MoonStat owns observation, reporting, metrics, snapshots, analytics, and
contract-drift detection. It consumes MoonLib contracts and must not become the
source of truth for layout decisions.

Bookkeeper owns acceptance decisions. A run can produce proposals; accepted
knowledge/code/results must be reviewed before they become durable book truth.

## Call Chains

Single-book Wiki work:

```text
User
  -> Moondesk
  -> MoonWiki surface for selected MoonBook
  -> optional MoonClaw execution for summarize/extract/analyze/propose
  -> MoonBook review artifacts
  -> Bookkeeper acceptance
  -> accepted MoonBook wiki update
```

Single-book Code work:

```text
User
  -> Moondesk
  -> MoonCode surface for selected MoonBook
  -> MoonClaw /v1/code runtime session
  -> code edits, diffs, tests, packages, events
  -> MoonBook review/package artifacts
  -> Bookkeeper acceptance
  -> accepted MoonBook executable code/tool/miniapp
```

Multi-book town work:

```text
Moontown
  -> observes schedules, messages, source signals, and book state
  -> creates or advances standing goals
  -> requests bounded MoonClaw work for target MoonBooks
  -> routes proposals/results back to MoonBooks
  -> asks Bookkeeper/review to accept or reject
  -> notifies Moondesk/operator when something meaningful happened
```

## Filesystem Shape

A MoonBook should be able to carry both prose and executable behavior:

```text
books/<book-id>/
  book.json
  raw/
    inbox/
    bootstrap/
    extracted/
    analysis-runs/
  wiki/
    index.md
    sources/
    findings/
    methods/
    reviews/
    history/
  skills/
    <skill-pack>/SKILL.md
  schemas/
    <contract>.schema.md
  tools/
    <book-owned tools>
  apps/
    <book-owned miniapps>
  portable/
    app-tool/
  site/generated/
  .moonclaw/
    mooncode/sessions/
```

The exact subdirectories can vary by book type, but the ownership rule should
not: accepted durable book state belongs in MoonBook; execution sidecars belong
to MoonClaw or MoonCode runtime folders; Moondesk only projects them.

## API Shape

Moondesk-facing routes may retain `/api/mooncode` as the desktop API namespace,
because it is a Moondesk UI projection shell:

```text
/api/mooncode/sessions
/api/mooncode/sessions/<id>/commands
/api/mooncode/sessions/<id>/stream
/api/mooncode/sessions/<id>/review...
```

MoonClaw-owned native runtime routes should use the generic executable-code
namespace:

```text
/v1/code/capabilities
/v1/code/sessions
/v1/code/sessions/<id>/commands
/v1/code/sessions/<id>/runtime-turn
/v1/code/sessions/<id>/runtime-loop
/v1/code/sessions/<id>/runtime-service
/v1/code/sessions/<id>/stream
/v1/code/sessions/<id>/tool-exec
```

MoonClaw noninteractive runs remain separate from MoonCode. Their exact routes
belong to MoonClaw's service contract, not to Moondesk's desktop API. Rule:
MoonCode should be an interactive code session backed by MoonClaw runtime
primitives, not a wrapper around automation chat. Noninteractive MoonClaw runs
are still valid for standing-watch work, research execution, and automation.

## Current Codebase Validation

This validation is based on static inspection of explicitly configured local
checkouts on 2026-06-20. The validator requires `MOONCLAW_ROOT`,
`MOONBOOK_ROOT`, and `MOONTOWN_ROOT`; it does not infer sibling source
directories. It proves architectural alignment only where the current code/docs
actually expose matching concepts.

| Codebase | Evidence | Alignment | Gaps |
| --- | --- | --- | --- |
| Moondesk | `mooncode/core/protocol.mbt` advertises `/v1/code/*` and `mooncode-executable-book-lifecycle.v1`; `internal/mooncode/session_executable_lifecycle.mbt` verifies ordered lifecycle evidence from readiness checks; `internal/moonwiki/mooncode_command_handlers.mbt` probes `/v1/code/capabilities`; the desktop API remains `/api/mooncode/sessions`. | Aligned as shell/projection and MoonCode session surface. | Keep Moondesk thin while future desktop frameworks render the same backend contracts. |
| MoonClaw | `cmd/daemon` has automation endpoints plus MoonCode session binding, runtime turn/loop/service files, and MoonCode sidecar persistence behind `/v1/code/*`. | Correct owner for agent/session/runtime and Code execution. | Implement the full executable-book lifecycle contract end to end: select/start/propose/edit/verify/review/accept/package/resume, plus stronger coding eval coverage. |
| MoonBook | README/docs show `wiki init`, `wiki ingest`, `wiki review`, `wiki lint`, `raw/bootstrap`, `wiki/reviews`, seeded skills, standing-watch decisions, and an agent-agnostic workspace. | Aligned as durable book/wiki/source/review owner. | Make executable-code directories, package manifests, MoonCode review artifacts, and lifecycle evidence first-class MoonBook templates. |
| Moontown | README and `src/*` expose daemon ticks, standing goals, target book ids, town synthesis, runtime status, worker routing, and book repair loops. | Aligned as scheduler plus coordination network for MoonBooks. | The “communication and new ideas” role exists in pieces, but should be made explicit as town messages/events and cross-book proposal routing rather than only scheduling language. |

## Immediate Refactor Implications

1. Keep Moondesk thin. Do not let Moondesk own runtime conversations or job execution state.
2. Keep `/api/mooncode` as a desktop HTTP surface, but make its native target
   `/v1/code`.
3. Keep MoonClaw's Code runtime on `/v1/code`; automation run routes belong to
   MoonClaw and Moontown, not the Moondesk desktop API.
4. Implement `mooncode-executable-book-lifecycle.v1` in MoonClaw and MoonBook,
   with Moondesk or any future desktop shell only rendering the evidence.
5. Strengthen Moontown docs and APIs around book-to-book messages, town events,
   idea discovery, and proposal routing.
6. Keep engineering judgment in development practice and evidence gates, not in
   product-visible assessment mechanics.
